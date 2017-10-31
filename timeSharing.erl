-module(timeSharing).
-export([start/1, controler/3, program/5]).

read(FileName)->
	{ok, Binary} = file:read_file(FileName),
	[binary_to_list(Bin) || Bin <- binary:split(Binary,[<<"\r\n">>, <<"\n">>],[global]), Bin =/= << >>].


getParams([Head|Rest])->
	{getParamsAux(string:lexemes(Head," "),[]),Rest}.

getParamsAux([],Params)->
	list_to_tuple(Params);

getParamsAux([Head|Rest],Params)->
	{Int,_}=string:to_integer(Head),
	getParamsAux(Rest,Params++[Int]).

getProgram(["stop"|Rest],Instructions)->
	{Instructions++[stop],Rest};

getProgram([Head|Rest],Instructions)->
	getProgram(Rest,Instructions++[getInstruction(Head)]).

getPrograms([])->
	[];
getPrograms(ProgramList)->
	{CurrentProgram,NewProgramList}=getProgram(ProgramList,[]),
	[CurrentProgram | getPrograms(NewProgramList)].

getInstruction(String)->
	case string:split(String," = ") of
		[Var,Value|_]->
			{Int,_}=string:to_integer(Value),
			{list_to_atom(Var),Int};
		[Inst|_]->
			case string:split(Inst," ") of
				[_, Var |_]->
					{write,list_to_atom(Var)};
				[Instruction|_]->
					list_to_atom(Instruction)
			end
	end.

controler([],_,_)->
	controlerEnd;
controler({Pid, State},_,VarList)->
	Pid ! {State,VarList},
	receive
		done->
			done;
		write->
			write;
		{assign,NewVarList}->
			{assign,NewVarList};
		acquire->
			acquire;
		retry->
			retry;
		release->
			release;
		stop->
			stop
	end;

controler([CurrentProgram | Rest],Queue,VarList)->
	%io:format("~p~n", [[CurrentProgram | Rest]]),
	case controler(CurrentProgram,foo,VarList) of
		done->
			controler(rotateList([CurrentProgram|Rest]),Queue,VarList);
		write->
			controler([CurrentProgram|Rest],Queue, VarList);
		{assign,NewVarList}->
			controler([CurrentProgram|Rest],Queue, NewVarList);
		retry->
			controler(Rest,Queue++[CurrentProgram],VarList);
		acquire->
			controler(lists:map(fun updateStatus/1, [CurrentProgram | Rest]),Queue,VarList);
		release->
			{ProgramList,NewQueue}=removeFromQueue([CurrentProgram | Rest], Queue),
			controler(lists:map(fun updateStatus/1,ProgramList ),NewQueue,VarList);
		stop->
			controler(Rest, Queue,VarList)
	end.

rotateList(List)->
	{L1,L2}=lists:split(1,List),
	L2++L1.

removeFromQueue(Programs, [])->
	{Programs,[]};

removeFromQueue(Programs, [ProgramToRemove | Rest])->
	{ActualProgram, ReadyQueue}=lists:split(1,Programs),
	{ActualProgram++[ProgramToRemove]++ReadyQueue,Rest}.

updateStatus({Pid,State})->
	if
		State == true->
			{Pid, false};
		true->
			{Pid, true}
	end.

program([],_,_,_,_)->
	programEnd;

program([ActualInst | Rest],Id,TotalQuantum,RemainingQuantum,InstDuration)->
	%io:format("Id:~p RQ:~p TQ:~p~n",[Id, RemainingQuantum, TotalQuantum]),
	receive
		{true, VarList}->%puede ejecutar acquire
			case	availableTime(ActualInst,RemainingQuantum,InstDuration) of
			       	{true, RemainingTime}->
					controler ! execute(ActualInst,VarList,false,Id),
					program(Rest,Id,TotalQuantum,RemainingTime,InstDuration);
				false->
					controler ! done,
					program([ActualInst | Rest], Id, TotalQuantum, TotalQuantum, InstDuration)
			end;

		{false, VarList}->%no puede ejecutar acquire
			case availableTime(ActualInst,RemainingQuantum, InstDuration) of
			       	{true, RemainingTime}->
					case execute(ActualInst,VarList,true,Id) of
						retry->
							controler ! retry,
							program([ActualInst | Rest],Id,TotalQuantum, TotalQuantum, InstDuration);
						Resp->
							controler ! Resp,
							program(Rest,Id, TotalQuantum, RemainingTime, InstDuration)
					end;
				false->
					controler ! done,
					program([ActualInst | Rest], Id, TotalQuantum, TotalQuantum, InstDuration)
			end
	end.

availableTime(Instruction, RemainingQ, InstsDuration)->
	CurrentInstTime = case Instruction of
				  {write,_}->
					  element(2,InstsDuration);
				  {_,_}->
					  element(1,InstsDuration);
				  acquire->
					  element(3,InstsDuration);
				  release->
					  element(4,InstsDuration);
				  stop->
					  element(5,InstsDuration)
			  end,
	if
		RemainingQ > 0->
			{true, RemainingQ-CurrentInstTime};
		true->
			false
	end.

execute(Instruction, VarList, Lock,Id)->
	case Instruction of
		{write, Var}->
			%io:format("P~p: Writing ~p~n",[Id,Var]),
			writeVariable(Var,VarList,Id),				
			write;
		{Var, Value}->
			%io:format("P~p: assigning ~p to ~p~n",[Id,Value, Var]),
			{assign ,assignVariable(Var, Value, VarList)};
		acquire when Lock == false->
			%io:format("P~p: ~p~n",[Id,acquire]),
			acquire;
		acquire ->
			%io:format("P~p: ~p~n",[Id,"acquire failed, waiting"]),
			retry;
		release ->
			%io:format("P~p: ~p~n",[Id,release]),
			release;
		stop ->
			%io:format("P~p: ~p~n",[Id,stop]),
			stop
	end.

assignVariable(Var, Value,VarList)->
	
	case lists:keyfind(Var,1,VarList) of
		{_ , _}->
			lists:keyreplace(Var,1,VarList,{Var,Value});
		false->
			[{Var, Value}]++VarList
	end.

writeVariable(Var, VarList,Id)->
	case lists:keyfind(Var,1,VarList) of
		{_ , Value}->
			io:format("~p: ~p~n",[Id, Value]);
		false->
			io:format("~p: 0~n",[Id])
	end.

spawner(Max,Max,[CurrentProgramInstructions|_],Quantum,InstructionDuration)->
	[{spawn(timeSharing,program,[CurrentProgramInstructions,Max,Quantum,Quantum,InstructionDuration]),true}];

spawner(I,Max,[CurrentProgramInstructions | Rest],Quantum,InstructionDuration)->
	[{spawn(timeSharing,program,[CurrentProgramInstructions,I,Quantum, Quantum,InstructionDuration]),true}|spawner(I+1,Max, Rest, Quantum, InstructionDuration)].

start(FileName)->
	File = read(FileName),
	{{ProgramNumber, T1, T2, T3, T4, T5, Quantum},Programs}=getParams(File),
	register(controler, spawn(timeSharing, controler,[spawner(1,ProgramNumber,getPrograms(Programs),Quantum,{T1,T2,T3,T4,T5}),[],[]])).


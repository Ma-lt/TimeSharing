-module(p2).
-export([start/0, controler/3, program/5]).



controler([],_,_)->
	controlerEnd;
controler({Pid, State},_,VarList)->
	Pid ! {State,VarList},
	receive
		done->
			done;
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
							program([ActualInst | Rest],Id,TotalQuantum, RemainingQuantum, InstDuration);
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
		CurrentInstTime =< RemainingQ->
			{true, RemainingQ-CurrentInstTime};
		true->
			false
	end.

execute(Instruction, VarList, Lock,Id)->
	case Instruction of
		{write, Var}->
			writeVariable(Var,VarList,Id),				
			done;
		{Var, Value}->
			%io:format("P: assigning ~p to ~p~n",[Value, Var]),
			{assign ,assignVariable(Var, Value, VarList)};
		acquire when Lock == false->
			%io:format("P: ~p~n",[acquire]),
			acquire;
		acquire ->
			%io:format("P: ~p~n",["acquire failed, waiting"]),
			retry;
		release ->
			%io:format("P: ~p~n",[release]),
			release;
		stop ->
			%io:format("P: ~p~n",[stop]),
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
			io:format("~p = 0~n",[Id])
	end.
start()->
	Pid = spawn(p2, program, [[{a,4},{write,a},acquire,{b,9},{write,b},release,{write,b},stop],1,1,1,{1,1,1,1,1}]),
	Pid2 = spawn(p2, program, [[{a,3},{write,a},acquire,{b,8},{write,b},release,{write,b},stop],2,1,1,{1,1,1,1,1}]),
	Pid3 = spawn(p2, program, [[{b,5},{a,17},{write,a},{write,b},acquire,{b,21},{write,b},release,{write,b},stop],3,1,1,{1,1,1,1,1}]),
	register(controler, spawn(p2,controler,[[{Pid, true},{Pid2,true},{Pid3, true}],[],[]])).
	

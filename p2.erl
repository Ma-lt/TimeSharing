-module(p2).
-export([start/0, controler/1, program/1]).



controler([])->
	controlerEnd;
controler({Pid, State})->
	Pid ! State,
	receive
		done->
			done;
		acquire->
			acquire;
		release->
			release;
		stop->
			stop
	end;

controler([CurrentProgram | Rest])->
	{Pid,_} = CurrentProgram,
	io:format("Switching to process~p~n",[Pid]),
	case controler(CurrentProgram) of
		done->
			controler(rotateList([CurrentProgram|Rest]));
		acquire->
			controler(rotateList(lists:map(fun updateStatus/1, [CurrentProgram | Rest])));
		release->
			controler(rotateList(lists:map(fun updateStatus/1, [CurrentProgram | Rest])));
		stop->
			controler(Rest)
	end.

rotateList(List)->
	{L1,L2}=lists:split(1,List),
	L2++L1.

updateStatus({Pid,State})->
	if
		State == true->
			{Pid, false};
		true->
			{Pid, true}
	end.

program([])->
	programEnd;

program([ActualInst | Rest])->
        %io:format("~p~n", [ActualInst]),
	receive
		true->%puede ejecutar acquire
			Lock = false,
			Instructions = Rest,
			controler ! execute(ActualInst,Lock);
		false->%no puede ejecutar acquire
			Lock = true,
			Response = execute(ActualInst, Lock),
			if 
				Response == retry->
					Instructions = [ActualInst | Rest],
					controler ! done;
				true->
					Instructions = Rest,
					controler ! Response
			end

	end,
	program(Instructions).

execute(Instruction, Lock)->
	case Instruction of
		{write, Var}->
			io:format("P: ~p~n",[write]),
			done;
		{Var, Value}->
			io:format("P: ~p~n",[assign]),
			done;
		acquire when Lock == false->
			io:format("P: ~p~n",[acquire]),
			acquire;
		acquire ->
			io:format("P: ~p~n",["acquire failed, waiting"]),
			retry;
		release ->
			io:format("P: ~p~n",[release]),
			release;
		stop ->
			io:format("P: ~p~n",[stop]),
			stop
	end.

start()->
	Pid = spawn(p2, program, [[{write, a},acquire,{b,9},{write,b},release,{write,b},stop]]),
	Pid2 = spawn(p2, program, [[{write, 3}, {a,3},acquire, {b,9}, release, stop]]),
	Pid3 = spawn(p2, program, [[{write, 3}, acquire, release,{a,3},stop]]),
	register(controler, spawn(p2,controler,[[{Pid, true},{Pid2,true},{Pid3, true}]])).

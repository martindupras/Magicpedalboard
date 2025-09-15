/* Test_MagicDisplayGUI_Scenarios.scd v0.5
   Very explicit scenarios: log each step, update "Command:", then force GUI redraw.
*/

(
~log = { |msg| ("[SC] " ++ msg).postln };

~refreshGuiFromMpb = {
    var curr, nxt, bA, bB, eA, eB;
    if(~gui.isNil or: { ~mpb.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    curr = ~mpb.currentChain;  nxt = ~mpb.nextChain;
    bA = ~mpb.bypassKeysCurrent; bB = ~mpb.bypassKeysNext;
    eA = ~mpb.effectiveCurrent;  eB = ~mpb.effectiveNext;
    ~gui.showChainsDetailed(curr, nxt, bA, bB, eA, eB);
};

~scenario1v5 = {
    var routine, waitS, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    waitS = 0.8;
    steps = [
        { ~log.("init");               ~gui.showExpectation("Command: init", 0);               ~refreshGuiFromMpb.() },
        { ~log.("add flanger");        ~gui.showExpectation("Command: add flanger", 0);        ~mpb.add(\flanger);       ~refreshGuiFromMpb.() },
        { ~log.("bypass flanger true");~gui.showExpectation("Command: bypass flanger true", 0);~mpb.bypass(\flanger, true);~refreshGuiFromMpb.() },
        { ~log.("add delay");          ~gui.showExpectation("Command: add delay", 0);          ~mpb.add(\delay);         ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT");         ~gui.showExpectation("Command: clear NEXT", 0);         ~mpb.clearChain;          ~refreshGuiFromMpb.() }
    ];
    routine = Routine {
        var i = 0;
        while({ i < steps.size }, { steps[i].value; i = i + 1; waitS.wait; });
    };
    ~mdgTask.notNil.if { ~mdgTask.stop };
    ~mdgTask = Task(routine, SystemClock).play;
};

~scenario2v5 = {
    var routine, waitS, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    waitS = 0.25;
    steps = [
        { ~log.("init");        ~gui.showExpectation("Command: init", 0);        ~refreshGuiFromMpb.() },
        { ~log.("add chorus");  ~gui.showExpectation("Command: add chorus", 0);  ~mpb.add(\chorus);     ~refreshGuiFromMpb.() },
        { ~log.("add reverb");  ~gui.showExpectation("Command: add reverb", 0);  ~mpb.add(\reverb);     ~refreshGuiFromMpb.() },
        { ~log.("add tremolo"); ~gui.showExpectation("Command: add tremolo", 0); ~mpb.add(\tremolo);    ~refreshGuiFromMpb.() },
        { ~log.("removeAt 2");  ~gui.showExpectation("Command: removeAt 2", 0);  ~mpb.removeAt(2);      ~refreshGuiFromMpb.() },
        { ~log.("add phaser");  ~gui.showExpectation("Command: add phaser", 0);  ~mpb.add(\phaser);     ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT");  ~gui.showExpectation("Command: clear NEXT", 0);  ~mpb.clearChain;       ~refreshGuiFromMpb.() }
    ];
    routine = Routine {
        var i = 0;
        while({ i < steps.size }, { steps[i].value; i = i + 1; waitS.wait; });
    };
    ~mdgTask.notNil.if { ~mdgTask.stop };
    ~mdgTask = Task(routine, SystemClock).play;
};

~scenario3v5 = {
    var routine, waitS, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    waitS = 0.6;
    steps = [
        { ~log.("init");                 ~gui.showExpectation("Command: init", 0);                 ~refreshGuiFromMpb.() },
        { ~log.("add bitcrusher");       ~gui.showExpectation("Command: add bitcrusher", 0);       ~mpb.add(\bitcrusher);  ~refreshGuiFromMpb.() },
        { ~log.("bypass bitcrusher false");~gui.showExpectation("Command: bypass bitcrusher false", 0); ~mpb.bypass(\bitcrusher, false); ~refreshGuiFromMpb.() },
        { ~log.("removeAt 1");          ~gui.showExpectation("Command: removeAt 1", 0);           ~mpb.removeAt(1);       ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT");           ~gui.showExpectation("Command: clear NEXT", 0);           ~mpb.clearChain;        ~refreshGuiFromMpb.() }
    ];
    routine = Routine {
        var i = 0;
        while({ i < steps.size }, { steps[i].value; i = i + 1; waitS.wait; });
    };
    ~mdgTask.notNil.if { ~mdgTask.stop };
    ~mdgTask = Task(routine, SystemClock).play;
};
)

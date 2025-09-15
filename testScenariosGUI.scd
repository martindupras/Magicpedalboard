// testScenariosGUI.scd

(
// Make sure ~drawOnce and ~checkPlumbing are already evaluated from above.

~stopScenarios = {
    var running;
    running = ~mdgTask;
    if(running.notNil) { running.stop; ~mdgTask = nil; };
    "Stopped scenario task (if any).".postln;
};

// helper to label the command box (uses your GUI’s expectation area)
~showCmd = { |textString|
    if(~gui.notNil and: { ~gui.respondsTo(\showExpectation) }) {
        ~gui.showExpectation(textString, 0);  // no countdown
    };
};

// Scenario 1: clear & readable cadence
~scenario1 = {
    var routine, steps, waitSeconds;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGui.() first.".warn; ^nil };

    waitSeconds = 0.8;

    steps = [
        { ~showCmd.("Init"); ~drawOnce.() },

        { ~showCmd.("add flanger");
          ~mpb.add(\flanger);
          ~drawOnce.() },

        { ~showCmd.("bypass flanger → true");
          ~mpb.bypass(\flanger, true);
          ~drawOnce.() },

        { ~showCmd.("add delay");
          ~mpb.add(\delay);
          ~drawOnce.() },

        { ~showCmd.("clear NEXT");
          ~mpb.clearChain;
          ~drawOnce.() }
    ];

    routine = Routine {
        var indexCounter, totalCount;
        indexCounter = 0;
        totalCount = steps.size;
        while({ indexCounter < totalCount }, {
            steps[indexCounter].value;
            indexCounter = indexCounter + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// Scenario 2: faster stress
~scenario2 = {
    var routine, steps, waitSeconds;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGui.() first.".warn; ^nil };

    waitSeconds = 0.25;

    steps = [
        { ~showCmd.("Init"); ~drawOnce.() },
        { ~showCmd.("add chorus");  ~mpb.add(\chorus);  ~drawOnce.() },
        { ~showCmd.("add reverb");  ~mpb.add(\reverb);  ~drawOnce.() },
        { ~showCmd.("add tremolo"); ~mpb.add(\tremolo); ~drawOnce.() },
        { ~showCmd.("removeAt 2");  ~mpb.removeAt(2);   ~drawOnce.() },
        { ~showCmd.("add phaser");  ~mpb.add(\phaser);  ~drawOnce.() },
        { ~showCmd.("clear NEXT");  ~mpb.clearChain;    ~drawOnce.() }
    ];

    routine = Routine {
        var indexCounter, totalCount;
        indexCounter = 0;
        totalCount = steps.size;
        while({ indexCounter < totalCount }, {
            steps[indexCounter].value;
            indexCounter = indexCounter + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// Scenario 3: edge-ish (no server; structural only)
~scenario3 = {
    var routine, steps, waitSeconds;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGui.() first.".warn; ^nil };

    waitSeconds = 0.6;

    steps = [
        { ~showCmd.("Init"); ~drawOnce.() },

        // add a couple, bypass one, then clear
        { ~showCmd.("add bitcrusher"); ~mpb.add(\bitcrusher); ~drawOnce.() },
        { ~showCmd.("bypass bitcrusher → false"); ~mpb.bypass(\bitcrusher, false); ~drawOnce.() },
        { ~showCmd.("removeAt 1 (if exists)"); ~mpb.removeAt(1); ~drawOnce.() },

        // reset the NEXT chain to a minimal state via clear
        { ~showCmd.("clear NEXT"); ~mpb.clearChain; ~drawOnce.() }
    ];

    routine = Routine {
        var indexCounter, totalCount;
        indexCounter = 0;
        totalCount = steps.size;
        while({ indexCounter < totalCount }, {
            steps[indexCounter].value;
            indexCounter = indexCounter + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};
)

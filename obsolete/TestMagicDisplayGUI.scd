// testMagicDisplayGUI.scd newer

(
// GUI-only harness with meters OFF to avoid server/SynthDef errors.

~bootGui = {
    var guiObj, board;

    // Create GUI (window creation is scheduled on AppClock in initGui)
    guiObj = MagicDisplayGUI.new;

    // Disable meters *immediately* so the scheduled init won't try to attach to the server
    guiObj.enableMeters(false);

    // Create pedalboard and attach display
    board = MagicPedalboardNew(guiObj);

    ~gui = guiObj;
    ~mpb = board;

    // After the window has had time to build, draw the lists
    AppClock.sched(0.2, {
        ~mpb.printChains;   // drives showChainsDetailed → populates CURRENT/NEXT columns
        nil
    });

    "GUI booted (meters disabled). The window will appear and lists will render shortly.".postln;
};

~stopScenarios = {
    var t;
    t = ~mdgTask;
    if(t.notNil) { t.stop; ~mdgTask = nil; };
    "Stopped scenario task (if any).".postln;
};

// Scenario 1: slow, clear updates
~scenario1 = {
    var routine, steps, waitSeconds;

    if(~mpb.isNil) { "Run ~bootGui.() first.".warn; ^nil };

    waitSeconds = 0.8;

    steps = [
        { ~mpb.printChains },
        { ~mpb.add(\flanger); ~mpb.printChains },
        { ~mpb.bypass(\flanger, true); ~mpb.printChains },
        { ~mpb.add(\delay); ~mpb.printChains },
        { ~mpb.clearChain; ~mpb.printChains }
    ];

    routine = Routine {
        var i, n; i = 0; n = steps.size;
        while({ i < n }, { steps[i].value; i = i + 1; waitSeconds.wait; });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// Scenario 2: faster stress updates
~scenario2 = {
    var routine, steps, waitSeconds;

    if(~mpb.isNil) { "Run ~bootGui.() first.".warn; ^nil };

    waitSeconds = 0.25;

    steps = [
        { ~mpb.printChains },
        { ~mpb.add(\chorus); ~mpb.printChains },
        { ~mpb.add(\reverb); ~mpb.printChains },
        { ~mpb.add(\tremolo); ~mpb.printChains },
        { ~mpb.removeAt(2); ~mpb.printChains },
        { ~mpb.add(\phaser); ~mpb.printChains },
        { ~mpb.clearChain; ~mpb.printChains }
    ];

    routine = Routine {
        var i, n; i = 0; n = steps.size;
        while({ i < n }, { steps[i].value; i = i + 1; waitSeconds.wait; });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};
)

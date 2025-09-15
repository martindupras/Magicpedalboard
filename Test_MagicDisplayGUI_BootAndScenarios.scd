/* Test_MagicDisplayGUI_BootAndScenarios.scd  v0.3
   Purpose: Robustly boot MagicDisplayGUI (meters OFF), wait for its window,
            and drive visible updates with scenarios that call showChainsDetailed.

   Style: tilde vars, var-first, lowercase names, no server.sync, no single-letter locals.
*/

(
// --- helpers: direct draw + command label ------------------------------------

~drawOnce = {
    var curr, nxt, bypassA, bypassB, effA, effB;
    if(~gui.isNil or: { ~mpb.isNil }) { "Run ~bootGuiV3.() first.".warn; ^nil };

    curr    = ~mpb.currentChain;
    nxt     = ~mpb.nextChain;
    bypassA = ~mpb.bypassKeysCurrent;
    bypassB = ~mpb.bypassKeysNext;
    effA    = ~mpb.effectiveCurrent;
    effB    = ~mpb.effectiveNext;

    // This is the method in your GUI that actually updates the list widgets.
    ~gui.showChainsDetailed(curr, nxt, bypassA, bypassB, effA, effB);
};

~showCmd = { |textString|
    if(~gui.notNil and: { ~gui.respondsTo(\showExpectation) }) {
        ~gui.showExpectation(textString.asString, 0);  // update the "Command:" area, no countdown
    };
};

// --- robust boot: build GUI, link to MPB, wait for window, then first draw ----

~bootGuiV3 = {
    var guiObj, board, maxPollCount, pollDelaySeconds, routine;

    // Optional: stop any previous scenario/boot task
    ~mdgTask.notNil.if { ~mdgTask.stop; ~mdgTask = nil };
    ~bootTask.notNil.if { ~bootTask.stop; ~bootTask = nil };

    // Create GUI instance and disable meters immediately (to avoid server dependency)
    guiObj = MagicDisplayGUI.new;
    guiObj.enableMeters(false);

    // Create pedalboard and attach the display
    board = MagicPedalboardNew(guiObj);

    ~gui = guiObj;
    ~mpb = board;

    // Poll until the GUI window exists, then bring it front and draw
    maxPollCount = 200;          // up to ~10 seconds
    pollDelaySeconds = 0.05;

    routine = Routine {
        var pollCount;
        pollCount = 0;

        // wait for the GUI to actually construct its Window in initGui (AppClock.sched)
        while({ (~gui.window.isNil) and: { pollCount < maxPollCount } }, {
            pollCount = pollCount + 1;
            pollDelaySeconds.wait;
        });

        defer({
            if(~gui.window.notNil) {
                ~gui.window.front;
            };
            // First visible draw of CURRENT / NEXT
            ~drawOnce.();
        });
    };

    ~bootTask = Task(routine, AppClock).play;

    "Booting GUI (meters disabled). Waiting for window, then painting columns…".postln;
};

// bring GUI to front later if needed
~frontGui = {
    if(~gui.notNil and: { ~gui.window.notNil }) { ~gui.window.front };
};

// stop any running scenario
~stopScenarios = {
    var runningTask;
    runningTask = ~mdgTask;
    if(runningTask.notNil) { runningTask.stop; ~mdgTask = nil; };
    "Stopped scenario task (if any).".postln;
};

// --- Scenario 1: clear cadence, visible steps --------------------------------

~scenario1 = {
    var routine, steps, waitSeconds;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV3.() first.".warn; ^nil };

    waitSeconds = 0.8;

    steps = [
        { ~showCmd.("Init"); ~drawOnce.() },
        { ~showCmd.("add flanger"); ~mpb.add(\flanger); ~drawOnce.() },
        { ~showCmd.("bypass flanger → true"); ~mpb.bypass(\flanger, true); ~drawOnce.() },
        { ~showCmd.("add delay"); ~mpb.add(\delay); ~drawOnce.() },
        { ~showCmd.("clear NEXT"); ~mpb.clearChain; ~drawOnce.() }
    ];

    routine = Routine {
        var stepIndex, stepCount;
        stepIndex = 0; stepCount = steps.size;
        while({ stepIndex < stepCount }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// --- Scenario 2: faster stress ------------------------------------------------

~scenario2 = {
    var routine, steps, waitSeconds;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV3.() first.".warn; ^nil };

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
        var stepIndex, stepCount;
        stepIndex = 0; stepCount = steps.size;
        while({ stepIndex < stepCount }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// --- Scenario 3: light edge-ish sequence (still structural-only) --------------

~scenario3 = {
    var routine, steps, waitSeconds;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV3.() first.".warn; ^nil };

    waitSeconds = 0.6;

    steps = [
        { ~showCmd.("Init"); ~drawOnce.() },
        { ~showCmd.("add bitcrusher"); ~mpb.add(\bitcrusher); ~drawOnce.() },
        { ~showCmd.("bypass bitcrusher → false"); ~mpb.bypass(\bitcrusher, false); ~drawOnce.() },
        { ~showCmd.("removeAt 1 (if exists)"); ~mpb.removeAt(1); ~drawOnce.() },
        { ~showCmd.("clear NEXT"); ~mpb.clearChain; ~drawOnce.() }
    ];

    routine = Routine {
        var stepIndex, stepCount;
        stepIndex = 0; stepCount = steps.size;
        while({ stepIndex < stepCount }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, AppClock).play;
    ~mdgTask
};

// --- optional: check that everything is wired as expected ---------------------

~checkPlumbing = {
    var guiOk, showDetailedOk, mpbOk, displayOk, curr, nxt;
    guiOk = ~gui.notNil;
    showDetailedOk = guiOk and: { ~gui.respondsTo(\showChainsDetailed) };
    mpbOk = ~mpb.notNil;
    displayOk = mpbOk and: { ~mpb.respondsTo(\display) } and: { ~mpb.display === ~gui };

    curr = mpbOk.if { ~mpb.tryPerform(\currentChain) } { nil };
    nxt  = mpbOk.if { ~mpb.tryPerform(\nextChain) } { nil };

    "=== Plumbing ===".postln;
    ["~gui exists:", guiOk].postln;
    ["GUI showChainsDetailed:", showDetailedOk].postln;
    ["~mpb exists:", mpbOk].postln;
    ["mpb.display === ~gui:", displayOk].postln;
    ["currentChain:", curr].postln;
    ["nextChain:", nxt].postln;
};
)

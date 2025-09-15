/* Test_MagicDisplayGUI_BootAndScenarios.scd v0.4
   Purpose: Deterministic boot (meters OFF), wait for window, then scenarios that
            clearly post progress AND force GUI redraws every step.

   Style: tilde vars, var-first, lowercase names, no server.sync, no single-letter locals.
*/

(
// ---------- shared helpers ----------------------------------------------------

~postState = { |labelString|
    var curr, nxt;
    curr = ~mpb.tryPerform(\currentChain);
    nxt  = ~mpb.tryPerform(\nextChain);
    ("[STATE] " ++ labelString ++ " → current=" ++ curr.asString
        ++ " | next=" ++ nxt.asString).postln;
};

~drawOnce = {
    var curr, nxt, bypassA, bypassB, effA, effB;
    if(~gui.isNil or: { ~mpb.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };

    curr    = ~mpb.currentChain;
    nxt     = ~mpb.nextChain;
    bypassA = ~mpb.bypassKeysCurrent;
    bypassB = ~mpb.bypassKeysNext;
    effA    = ~mpb.effectiveCurrent;
    effB    = ~mpb.effectiveNext;

    // GUI method that actually updates the lists/labels
    ~gui.showChainsDetailed(curr, nxt, bypassA, bypassB, effA, effB);
};

~refreshView = { |labelString|
    ~postState.(labelString);
    // Console view via MPB (also calls showChainsDetailed under the hood)
    ~mpb.printChains;
    // Explicit GUI redraw (belt-and-braces)
    ~drawOnce.();
};

// ---------- robust boot: wait for window, then first draw --------------------

~bootGuiV4 = {
    var guiObj, board, maxPollCount, pollDelaySeconds, routine;

    // stop any previous tasks
    ~mdgTask.notNil.if { ~mdgTask.stop; ~mdgTask = nil };
    ~bootTask.notNil.if { ~bootTask.stop; ~bootTask = nil };

    // create GUI and disable meters (avoid server dependency)
    guiObj = MagicDisplayGUI.new;
    guiObj.enableMeters(false);

    // create pedalboard and attach display
    board = MagicPedalboardNew(guiObj);
    ~gui = guiObj;
    ~mpb = board;

    // poll for the window (it is built asynchronously on AppClock)
    maxPollCount = 200;          // up to ~10 seconds
    pollDelaySeconds = 0.05;

    routine = Routine {
        var pollCount;
        pollCount = 0;

        while({ (~gui.window.isNil) and: { pollCount < maxPollCount } }, {
            pollCount = pollCount + 1;
            pollDelaySeconds.wait;      // SystemClock here; avoids AppClock contention
        });

        defer({
            if(~gui.window.notNil) {
                "Window ready — fronting and drawing columns.".postln;
                ~gui.window.front;
            }{
                "Window did not appear in time (10 s).".warn;
            };
            ~refreshView.("boot");
        });
    };

    ~bootTask = Task(routine, SystemClock).play; // use SystemClock for the polling loop
    "Booting GUI (meters disabled). Waiting for window…".postln;
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

// ---------- Scenarios (run on SystemClock, post step labels) -----------------

~scenario1v4 = {
    var routine, waitSeconds, steps, totalSteps;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };

    waitSeconds = 0.8;

    steps = [
        { "[SC1] init".postln; ~refreshView.("SC1/init") },

        { "[SC1] add flanger".postln;
          ~mpb.add(\flanger);
          ~refreshView.("SC1/add flanger") },

        { "[SC1] bypass flanger → true".postln;
          ~mpb.bypass(\flanger, true);
          ~refreshView.("SC1/bypass flanger true") },

        { "[SC1] add delay".postln;
          ~mpb.add(\delay);
          ~refreshView.("SC1/add delay") },

        { "[SC1] clear NEXT".postln;
          ~mpb.clearChain;
          ~refreshView.("SC1/clear NEXT") }
    ];

    totalSteps = steps.size;

    routine = Routine {
        var stepIndex;
        stepIndex = 0;
        while({ stepIndex < totalSteps }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, SystemClock).play;   // SystemClock: robust in headless/server-off
    ~mdgTask
};

~scenario2v4 = {
    var routine, waitSeconds, steps, totalSteps;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };

    waitSeconds = 0.25;

    steps = [
        { "[SC2] init".postln; ~refreshView.("SC2/init") },
        { "[SC2] add chorus".postln;  ~mpb.add(\chorus);  ~refreshView.("SC2/add chorus") },
        { "[SC2] add reverb".postln;  ~mpb.add(\reverb);  ~refreshView.("SC2/add reverb") },
        { "[SC2] add tremolo".postln; ~mpb.add(\tremolo); ~refreshView.("SC2/add tremolo") },
        { "[SC2] removeAt 2".postln;  ~mpb.removeAt(2);   ~refreshView.("SC2/removeAt 2") },
        { "[SC2] add phaser".postln;  ~mpb.add(\phaser);  ~refreshView.("SC2/add phaser") },
        { "[SC2] clear NEXT".postln;  ~mpb.clearChain;    ~refreshView.("SC2/clear NEXT") }
    ];

    totalSteps = steps.size;

    routine = Routine {
        var stepIndex;
        stepIndex = 0;
        while({ stepIndex < totalSteps }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, SystemClock).play;
    ~mdgTask
};

~scenario3v4 = {
    var routine, waitSeconds, steps, totalSteps;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };

    waitSeconds = 0.6;

    steps = [
        { "[SC3] init".postln; ~refreshView.("SC3/init") },

        { "[SC3] add bitcrusher".postln;
          ~mpb.add(\bitcrusher);
          ~refreshView.("SC3/add bitcrusher") },

        { "[SC3] bypass bitcrusher → false".postln;
          ~mpb.bypass(\bitcrusher, false);
          ~refreshView.("SC3/bypass bitcrusher false") },

        { "[SC3] removeAt 1 (if exists)".postln;
          ~mpb.removeAt(1);
          ~refreshView.("SC3/removeAt 1") },

        { "[SC3] clear NEXT".postln;
          ~mpb.clearChain;
          ~refreshView.("SC3/clear NEXT") }
    ];

    totalSteps = steps.size;

    routine = Routine {
        var stepIndex;
        stepIndex = 0;
        while({ stepIndex < totalSteps }, {
            steps[stepIndex].value;
            stepIndex = stepIndex + 1;
            waitSeconds.wait;
        });
    };

    ~stopScenarios.();
    ~mdgTask = Task(routine, SystemClock).play;
    ~mdgTask
};
)

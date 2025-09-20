/*
 * Test_MagicDisplayGUI_AllInOne_Monolithic.scd v0.10
 * Single top-level block = no "unexpected '('" parse issue.
 *
 * Contents
 *  - Section A: Test_MagicDisplayGUI_BootAndScenarios.scd v0.4 (verbatim)
 *  - Section B: Test_MagicDisplayGUI_Scenarios.scd v0.5 (verbatim)
 *  - Section C: Test_MagicDisplayGUI_InlineInstrument.scd v0.2 (verbatim)
 *  - Section D: Resilient UI-queue patch + v6 aliases + one-button runner
 *
 * Style respected:
 *  - tilde vars, var-first in each block, lowercase names
 *  - no server.sync, explicit AppClock scheduling for UI work (.defer)
 */

(
// ======================================================================
// Section A — Test_MagicDisplayGUI_BootAndScenarios.scd v0.4 (verbatim)
// ======================================================================

// ---------- shared helpers ------------------------------------------------
~postState = { |labelString|
    var curr, nxt;
    curr = ~mpb.tryPerform(\currentChain);
    nxt = ~mpb.tryPerform(\nextChain);
    ("[STATE] " ++ labelString ++ " → current=" ++ curr.asString
        ++ "  next=" ++ nxt.asString).postln;
};

~drawOnce = {
    var curr, nxt, bypassA, bypassB, effA, effB;
    if(~gui.isNil or: { ~mpb.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    curr = ~mpb.currentChain;
    nxt = ~mpb.nextChain;
    bypassA = ~mpb.bypassKeysCurrent;
    bypassB = ~mpb.bypassKeysNext;
    effA = ~mpb.effectiveCurrent;
    effB = ~mpb.effectiveNext;
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

// ---------- robust boot: wait for window, then first draw ----------------
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
    maxPollCount = 200; // up to ~10 seconds
    pollDelaySeconds = 0.05;
    routine = Routine {
        var pollCount;
        pollCount = 0;
        while({ (~gui.window.isNil) and: { pollCount < maxPollCount } }, {
            pollCount = pollCount + 1;
            pollDelaySeconds.wait; // SystemClock here; avoids AppClock contention
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

// ---------- Scenarios (run on SystemClock, post step labels) -------------
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
    ~mdgTask = Task(routine, SystemClock).play; // SystemClock: robust in headless/server-off
    ~mdgTask
};

~scenario2v4 = {
    var routine, waitSeconds, steps, totalSteps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    waitSeconds = 0.25;
    steps = [
        { "[SC2] init".postln; ~refreshView.("SC2/init") },
        { "[SC2] add chorus".postln; ~mpb.add(\chorus); ~refreshView.("SC2/add chorus") },
        { "[SC2] add reverb".postln; ~mpb.add(\reverb); ~refreshView.("SC2/add reverb") },
        { "[SC2] add tremolo".postln; ~mpb.add(\tremolo); ~refreshView.("SC2/add tremolo") },
        { "[SC2] removeAt 2".postln; ~mpb.removeAt(2); ~refreshView.("SC2/removeAt 2") },
        { "[SC2] add phaser".postln; ~mpb.add(\phaser); ~refreshView.("SC2/add phaser") },
        { "[SC2] clear NEXT".postln; ~mpb.clearChain; ~refreshView.("SC2/clear NEXT") }
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


// ======================================================================
// Section B — Test_MagicDisplayGUI_Scenarios.scd v0.5 (verbatim)
// ======================================================================

~log = { |msg| ("[SC] " ++ msg).postln };

~refreshGuiFromMpb = {
    var curr, nxt, bA, bB, eA, eB;
    if(~gui.isNil or: { ~mpb.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    curr = ~mpb.currentChain; nxt = ~mpb.nextChain;
    bA = ~mpb.bypassKeysCurrent; bB = ~mpb.bypassKeysNext;
    eA = ~mpb.effectiveCurrent; eB = ~mpb.effectiveNext;
    ~gui.showChainsDetailed(curr, nxt, bA, bB, eA, eB);
};

~scenario1v5 = {
    var routine, waitS, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV4.() first.".warn; ^nil };
    waitS = 0.8;
    steps = [
        { ~log.("init"); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.("add flanger"); ~gui.showExpectation("Command: add flanger", 0); ~mpb.add(\flanger); ~refreshGuiFromMpb.() },
        { ~log.("bypass flanger true"); ~gui.showExpectation("Command: bypass flanger true", 0); ~mpb.bypass(\flanger, true); ~refreshGuiFromMpb.() },
        { ~log.("add delay"); ~gui.showExpectation("Command: add delay", 0); ~mpb.add(\delay); ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT"); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
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
        { ~log.("init"); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.("add chorus"); ~gui.showExpectation("Command: add chorus", 0); ~mpb.add(\chorus); ~refreshGuiFromMpb.() },
        { ~log.("add reverb"); ~gui.showExpectation("Command: add reverb", 0); ~mpb.add(\reverb); ~refreshGuiFromMpb.() },
        { ~log.("add tremolo"); ~gui.showExpectation("Command: add tremolo", 0); ~mpb.add(\tremolo); ~refreshGuiFromMpb.() },
        { ~log.("removeAt 2"); ~gui.showExpectation("Command: removeAt 2", 0); ~mpb.removeAt(2); ~refreshGuiFromMpb.() },
        { ~log.("add phaser"); ~gui.showExpectation("Command: add phaser", 0); ~mpb.add(\phaser); ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT"); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
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
        { ~log.("init"); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.("add bitcrusher"); ~gui.showExpectation("Command: add bitcrusher", 0); ~mpb.add(\bitcrusher); ~refreshGuiFromMpb.() },
        { ~log.("bypass bitcrusher false"); ~gui.showExpectation("Command: bypass bitcrusher false", 0); ~mpb.bypass(\bitcrusher, false); ~refreshGuiFromMpb.() },
        { ~log.("removeAt 1"); ~gui.showExpectation("Command: removeAt 1", 0); ~mpb.removeAt(1); ~refreshGuiFromMpb.() },
        { ~log.("clear NEXT"); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    routine = Routine {
        var i = 0;
        while({ i < steps.size }, { steps[i].value; i = i + 1; waitS.wait; });
    };
    ~mdgTask.notNil.if { ~mdgTask.stop };
    ~mdgTask = Task(routine, SystemClock).play;
};


// ======================================================================
// Section C — Test_MagicDisplayGUI_InlineInstrument.scd v0.2 (verbatim)
// ======================================================================

~probeGuiV2 = {
    var hasGui, hasWin, current, next, bypassA, bypassB, effA, effB;
    hasGui = ~gui.notNil;
    if(hasGui.not) { "No ~gui. Run ~bootGuiV4.() first.".warn; ^nil };
    hasWin = ~gui.tryPerform(\window).notNil;
    ["[PROBE] gui exists:", hasGui, "window exists:", hasWin].postln;

    // very distinctive frame so you can spot it instantly
    current = [\chainA, \AAA_debug_one, \BBB_debug_two, \ts0];
    next    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];
    bypassA = [\BBB_debug_two];
    bypassB = [];
    effA    = [\chainA, \AAA_debug_one, \ts0];
    effB    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];

    // make the "Command:" box change as well (immediate visible cue)
    ~gui.showExpectation("Command: PROBE FRAME", 0);

    // schedule list redraw on AppClock (same thread your GUI uses internally)
    AppClock.sched(0, {
        "[PROBE] Calling showChainsDetailed on AppClock…".postln;
        ~gui.showChainsDetailed(current, next, bypassA, bypassB, effA, effB);
        "[PROBE] showChainsDetailed returned.".postln;
        nil
    });

    "Probe queued. Expect 'PROBE FRAME' in the Command area and AAA/BBB/CCC/DDD items in the lists."
    .postln;
};


// ======================================================================
// Section D — Patch + v6 Aliases + One-button Runner
// ======================================================================

// Resilient UI-queue patch: make queued UI work run immediately on AppClock
~md_applyQueueUiPatch = {
    var displayCandidates, candidateIndex, candidate, patched, proofFun;

    patched = false;
    displayCandidates = [];

    // Prefer ~magicDisplay if present; fallback to ~gui
    if(~magicDisplay.notNil) { displayCandidates = displayCandidates.add(~magicDisplay) };
    if(~gui.notNil)          { displayCandidates = displayCandidates.add(~gui) };

    if(displayCandidates.isEmpty) {
        "[PATCH] No display object (~magicDisplay or ~gui) yet; run boot first.".postln;
        ^false
    };

    candidateIndex = 0;
    while({ candidateIndex < displayCandidates.size and: { patched.not } }, {
        candidate = displayCandidates[candidateIndex];

        // Try setter first (slot/property on an object)
        if(candidate.respondsTo(\queueUi_)) {
            candidate.queueUi = { |selfArg, fun| fun.defer };  // UI-safe immediate
            patched = true;
        }{
            // Try dictionary/event-like storage
            if(candidate.respondsTo(\atPut)) {
                candidate[\queueUi] = { |ignoredSelf, fun| fun.defer }; // UI-safe immediate
                patched = true;
            };
        };

        candidateIndex = candidateIndex + 1;
    });

    if(patched) {
        "[PATCH] queueUi patched to immediate (.defer)".postln;

        // Proof-of-life
        if(candidate.respondsTo(\queueUi)) {
            candidate.queueUi({ "[CHECK] queueUi immediate hit".postln });
        }{
            if(candidate.respondsTo(\at)) {
                proofFun = candidate[\queueUi];
                if(proofFun.isKindOf(Function)) {
                    proofFun.value(candidate, { "[CHECK] queueUi immediate hit".postln });
                };
            };
        };
        ^true
    }{
        "[PATCH] Display found but exposes neither queueUi_ nor atPut; not patched.".postln;
        ^false
    };
};

// Wait-and-patch helper: polls until a display is available, then applies patch
~md_waitAndPatchQueueUiImmediate = {
    var attempts, maxAttempts, stepSeconds, routineInstance;

    attempts = 0;
    maxAttempts = 200;     // ~10 seconds at 0.05s
    stepSeconds = 0.05;

    routineInstance = Routine({
        "[PATCH] Waiting for display (~magicDisplay or ~gui)…".postln;
        while({ attempts < maxAttempts }, {
            if(~magicDisplay.notNil or: { ~gui.notNil }) {
                if(~md_applyQueueUiPatch.()) {
                    thisThread.stop;
                };
            };
            attempts = attempts + 1;
            stepSeconds.wait;
        });
        "[PATCH] Timed out waiting for display; run ~md_waitAndPatchQueueUiImmediate.() again after boot."
        .postln;
    }).play(AppClock);

    routineInstance
};

// v6-style aliases wrapping your existing definitions
~bootGuiV6 = {
    var booted;
    booted = false;
    if(~bootGuiV4.notNil) {
        ~bootGuiV4.();
        booted = true;
    }{
        "Missing ~bootGuiV4; please check Section A definitions.".warn;
    };

    // Start the wait-and-patch watcher right after boot
    if(booted) {
        ~md_waitAndPatchQueueUiImmediate.();
    };
};

~scenario1v6 = { if(~scenario1v5.notNil) { ~scenario1v5.() }{ if(~scenario1v4.notNil) { ~scenario1v4.() }{ "No scenario1 function found.".warn }} };
~scenario2v6 = { if(~scenario2v5.notNil) { ~scenario2v5.() }{ if(~scenario2v4.notNil) { ~scenario2v4.() }{ "No scenario2 function found.".warn }} };
~scenario3v6 = { if(~scenario3v5.notNil) { ~scenario3v5.() }{ if(~scenario3v4.notNil) { ~scenario3v4.() }{ "No scenario3 function found.".warn }} };

~probeGuiV3 = { if(~probeGuiV2.notNil) { ~probeGuiV2.() }{ "No probe function (~probeGuiV2) found.".warn } };

// One-button runner: boot → patch → probe → scenario
~md_go = {
    var bootTask;
    bootTask = Task({
        "[ALL-IN-ONE] Booting GUI (v6 alias)…".postln;
        ~bootGuiV6.();

        // small wait for "Window ready…" to appear
        0.5.wait;

        if(~probeGuiV3.notNil) {
            "[ALL-IN-ONE] Running probe (~probeGuiV3)…".postln;
            ~probeGuiV3.();
        };

        0.2.wait;

        if(~scenario1v6.notNil) {
            "[ALL-IN-ONE] Running scenario (~scenario1v6)…".postln;
            ~scenario1v6.();
        };
    });
    bootTask.start;
    bootTask
};

// Session banner
"[ALL-IN-ONE] Ready. Typical flow:\n  1) ~bootGuiV6.();\n  2) ~md_waitAndPatchQueueUiImmediate.();\n  3) ~probeGuiV3.();\n  4) ~scenario1v6.();\nOr just run: ~md_go.();"
.postln;

) // <— single top-level block ends here

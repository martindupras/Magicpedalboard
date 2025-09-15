// TEST_overlayHotFix.scd

(
// v0.10.6: self-contained, deterministic flow
// - One window (token-gated boot on AppClock)
// - No programmatic window closing (avoid Qt races)
// - No watchers, no queueUi patching
// - Includes fallbacks for ~refreshGuiFromMpb and ~probeGuiV3
// - Fast AppClock scenario (works regardless of internal UI queue)

// ---------------------------
// 0) utilities + boot token
// ---------------------------
~md_bootToken = (~md_bootToken ? 0);

~md_log = { |messageString| ("[RUNNER] " ++ messageString).postln };

// ---------------------------
// 1) minimal reset (no closing)
// ---------------------------
~md_resetSession = {
    var hadTask, hadBootTask;
    hadTask = ~mdgTask.notNil;
    hadBootTask = ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    // Don't touch windows; just clear refs we own
    ~mpb = nil;
    ~magicDisplay = nil;

    ~md_log.("Reset: tasks stopped; references cleared.");
};

// -------------------------------------------
// 2) single, idempotent boot on AppClock only
// -------------------------------------------
~bootGuiV6 = {
    var myToken;
    ~md_resetSession.();

    ~md_bootToken = ~md_bootToken + 1;
    myToken = ~md_bootToken;

    "Booting GUI (meters disabled). Waiting for window…".postln;

    AppClock.sched(0, {
        var existingWin, guiObj, board;

        if(~md_bootToken != myToken) { ^nil }; // newer boot superseded us

        // Reuse existing window if available
        if(~gui.notNil) {
            existingWin = ~gui.tryPerform(\window);
            if(existingWin.notNil) {
                "Window found — reusing and fronting.".postln;
                existingWin.front;
                if(~refreshView.notNil) { ~refreshView.("boot (reuse)") };
                ^nil
            };
        };

        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        board = MagicPedalboardNew(guiObj);
        ~mpb = board;

        AppClock.sched(0.05, {
            var winReady;
            if(~md_bootToken != myToken) { ^nil };
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "Window ready — fronting and drawing columns.".postln;
                winReady.front;
            }{
                "Window not yet available; will front on next GUI call.".postln;
            };
            if(~refreshView.notNil) { ~refreshView.("boot") };
            nil
        });

        nil
    });
};

// ------------------------------------------------------
// 3) fallbacks if your monolithic helpers aren’t loaded
// ------------------------------------------------------
~refreshGuiFromMpb = ~refreshGuiFromMpb ? {
    var curr, nxt, bA, bB, eA, eB;
    if(~gui.isNil or: { ~mpb.isNil }) { "[FALLBACK] Run ~bootGuiV6.() first.".warn; ^nil };
    curr = ~mpb.currentChain; nxt = ~mpb.nextChain;
    bA = ~mpb.bypassKeysCurrent; bB = ~mpb.bypassKeysNext;
    eA = ~mpb.effectiveCurrent; eB = ~mpb.effectiveNext;
    ~gui.showChainsDetailed(curr, nxt, bA, bB, eA, eB);
};

~probeGuiV3 = ~probeGuiV3 ? {
    var hasGui, hasWin, current, next, bypassA, bypassB, effA, effB;
    hasGui = ~gui.notNil;
    if(hasGui.not) { "No ~gui. Run ~bootGuiV6.() first.".warn; ^nil };
    hasWin = ~gui.tryPerform(\window).notNil;
    ["[PROBE] gui exists:", hasGui, "window exists:", hasWin].postln;

    current = [\chainA, \AAA_debug_one, \BBB_debug_two, \ts0];
    next    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];
    bypassA = [\BBB_debug_two];
    bypassB = [];
    effA    = [\chainA, \AAA_debug_one, \ts0];
    effB    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];

    ~gui.showExpectation("Command: PROBE FRAME", 0);

    AppClock.sched(0, {
        "[PROBE] Calling showChainsDetailed on AppClock…".postln;
        ~gui.showChainsDetailed(current, next, bypassA, bypassB, effA, effB);
        "[PROBE] showChainsDetailed returned.".postln;
        nil
    });
    "Probe queued. Expect 'PROBE FRAME' + AAA/BBB/CCC/DDD in lists.".postln;
};

// ------------------------------------------------------
// 4) fast scenario: each step runs on AppClock directly
// ------------------------------------------------------
~scenario1v6_fast = {
    var paceSeconds, steps, controllerRoutine, totalSteps, stepIndex;

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };

    paceSeconds = 0.8;
    steps = [
        { "[SC] init".postln; ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { "[SC] add flanger".postln; ~gui.showExpectation("Command: add flanger", 0); ~mpb.add(\flanger); ~refreshGuiFromMpb.() },
        { "[SC] bypass flanger true".postln; ~gui.showExpectation("Command: bypass flanger true", 0); ~mpb.bypass(\flanger, true); ~refreshGuiFromMpb.() },
        { "[SC] add delay".postln; ~gui.showExpectation("Command: add delay", 0); ~mpb.add(\delay); ~refreshGuiFromMpb.() },
        { "[SC] clear NEXT".postln; ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    totalSteps = steps.size;

    ~mdgTask.notNil.if({ ~mdgTask.stop; ~mdgTask = nil });

    controllerRoutine = Routine({
        stepIndex = 0;
        while({ stepIndex < totalSteps }, {
            AppClock.sched(0, { steps[stepIndex].value; nil });
            paceSeconds.wait; // pacing on SystemClock
            stepIndex = stepIndex + 1;
        });
    });
    ~mdgTask = controllerRoutine.play(SystemClock);
    ~mdgTask
};

// ------------------------------------------------------
// 5) single-button: reset → boot → probe → fast scenario
// ------------------------------------------------------
~md_bootProbeScenario = {
    var runnerTask;
    runnerTask = Task({
        ~md_log.("Starting: reset → boot → probe → scenario");
        ~bootGuiV6.();

        // allow the window to build & front
        0.9.wait;

        ~md_log.("Probe…");
        ~probeGuiV3.();

        0.3.wait;

        ~md_log.("Scenario (fast)…");
        ~scenario1v6_fast.();
    });
    runnerTask.start;
    runnerTask
};

// optional: quick window inspector
~md_checkWindows = {
    AppClock.sched(0, {
        var wins;
        wins = Window.allWindows ? [];
        ("[CHECK] window count = " ++ wins.size).postln;
        wins.do({ |w, idx| ("[CHECK] w" ++ idx ++ " title=" ++ w.name.asString).postln });
        nil
    });
};

"Ready. Run: ~md_bootProbeScenario.();  (or step-by-step: ~bootGuiV6.(); ~probeGuiV3.(); ~scenario1v6_fast.(); )".postln;
)

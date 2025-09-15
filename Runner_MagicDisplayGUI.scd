/* Runner_MagicDisplayGUI.scd v0.6.1
   Purpose: Deterministic, single-window GUI boot → probe → scenario (fast) runner.
   Self-contained: no watchers, no queueUi patching, all GUI ops on AppClock.
   Style: tilde vars, var-first, lowercase names, no server.sync, no single-letter locals.
*/

(
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

    // Do not close windows here; avoid Qt races. Just clear references we own.
    ~mpb = nil;
    ~magicDisplay = nil;

    ~md_log.("Reset: tasks stopped; references cleared.");
};

// -------------------------------------------
// 2) ensure pedalboard exists immediately
// -------------------------------------------
~md_ensureMpbNow = {
    var created;
    created = false;

    if(~gui.isNil) {
        "[ENSURE] No ~gui yet; cannot build ~mpb.".warn;
        ^false
    };

    if(~mpb.isNil) {
        ~mpb = MagicPedalboardNew(~gui);
        created = true;
        "[ENSURE] Built new MagicPedalboardNew (~mpb).".postln;
    };

    created or: { ~mpb.notNil }
};

// -------------------------------------------
// 3) single, idempotent boot on AppClock only
// -------------------------------------------
~bootGuiV6 = {
    var myToken;
    ~md_resetSession.();

    ~md_bootToken = (~md_bootToken ? 0) + 1;
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

                if(~mpb.isNil) {
                    board = MagicPedalboardNew(~gui);
                    ~mpb = board;
                    "[ENSURE] Reuse path created ~mpb.".postln;
                };

                existingWin.front;
                if(~refreshView.notNil) { ~refreshView.("boot (reuse)") };
                ^nil
            };
        };

        // Fresh create
        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        board = MagicPedalboardNew(guiObj);
        ~mpb = board;
        "[ENSURE] Fresh path created ~mpb.".postln;

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
// 4) fallbacks if monolithic helpers aren’t loaded
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
// 5) fast scenario: each step runs on AppClock directly
//    (scenario1 fast included here for one-button run)
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
// 6) single-button: reset → boot → probe → fast scenario
// ------------------------------------------------------
~md_bootProbeScenario = {
    var runnerTask;
    runnerTask = Task({
        var waitCount, maxWait, done;
        ~md_log.("Starting: reset → boot → probe → scenario");
        ~md_resetSession.();
        ~bootGuiV6.();

        // Wait up to ~1.5s for ~gui and ~mpb (30 * 0.05)
        waitCount = 0; maxWait = 30; done = false;
        while({ done.not and: { waitCount < maxWait } }, {
            if(~gui.notNil and: { ~mpb.notNil }) { done = true }{ 0.05.wait; waitCount = waitCount + 1 };
        });

        if(~mpb.isNil) { ~md_ensureMpbNow.() };
        if(~gui.isNil or: { ~mpb.isNil }) { "[RUNNER] Cannot proceed: ~gui or ~mpb missing.".warn; ^nil };

        "[RUNNER] Probe…".postln;
        ~probeGuiV3.();

        0.3.wait;

        "[RUNNER] Scenario (fast)…".postln;
        ~mpb.isNil.if({ ~md_ensureMpbNow.() });
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

"Ready. After reboot, evaluate this file, then run: ~md_bootProbeScenario.();".postln;




// 1) Is the current window actually alive?
~md_isWindowAlive = {
    var winObj, wasRemoved, isClosed, viewObj, ok;
    if(~gui.isNil) { ^false };
    winObj = ~gui.tryPerform(\window);
    if(winObj.isNil) { ^false };

    // Try to detect a removed/closed Qt view in a defensive way
    viewObj = winObj.tryPerform(\view);
    wasRemoved = viewObj.tryPerform(\wasRemoved);
    if(wasRemoved.isNil) { wasRemoved = false };

    isClosed = winObj.tryPerform(\isClosed);  // may be nil on older builds
    if(isClosed.isNil) { isClosed = false };

    ok = (wasRemoved == false) and: (isClosed == false);
    ok
};

// 2) Make reset “smart”: if window is dead, clear ~gui so next boot is fresh
~md_resetSession = {
    var hadTask, hadBootTask, alive;
    hadTask = ~mdgTask.notNil;
    hadBootTask = ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    alive = ~md_isWindowAlive.();
    if(alive.not) { ~gui = nil };  // forces fresh create next time

    ~mpb = nil;
    ~magicDisplay = nil;

    "[RUNNER] Reset: tasks stopped; references cleared."
    ++ (alive.not.if({ " (~gui cleared: window not alive)" }, { "" })).postln;
};

// 3) Harden ~bootGuiV6: reuse only if the window is alive; else fresh create
~bootGuiV6 = {
    var myToken;
    ~md_resetSession.();

    ~md_bootToken = (~md_bootToken ? 0) + 1;
    myToken = ~md_bootToken;

    "Booting GUI (meters disabled). Waiting for window…".postln;

    AppClock.sched(0, {
        var winOk, existingWin, guiObj, board;

        if(~md_bootToken != myToken) { ^nil };

        winOk = ~md_isWindowAlive.();
        if(winOk) {
            existingWin = ~gui.tryPerform(\window);
            "Window found — reusing and fronting.".postln;

            if(~mpb.isNil) {
                board = MagicPedalboardNew(~gui);
                ~mpb = board;
                "[ENSURE] Reuse path created ~mpb.".postln;
            };

            existingWin.front;
            if(~refreshView.notNil) { ~refreshView.("boot (reuse)") };
            ^nil
        };

        // Fresh create
        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        board = MagicPedalboardNew(guiObj);
        ~mpb = board;
        "[ENSURE] Fresh path created ~mpb.".postln;

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
)


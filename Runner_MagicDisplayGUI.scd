/* Runner_MagicDisplayGUI.scd
   Purpose: Deterministic, single-window GUI boot → probe → scenario (fast).
   Self-contained: no watchers, no queueUi patching, all GUI ops on AppClock.
   Style: tilde vars, var-first, lowercase names, no server.sync, no single-letter locals.
*/

(
// ---------------------------
// 0) utilities + run/boot state
// ---------------------------
~md_bootToken = (~md_bootToken ? 0);
~md_runnerActive = (~md_runnerActive ? false);
~md_runnerTask = (~md_runnerTask ? nil);

~md_log = { |messageString| ("[RUNNER] " ++ messageString).postln };

// ---------------------------
// 1) window liveness + quick checks
// ---------------------------
~md_isWindowAlive = {
    var winObj, viewObj, wasRemoved, isClosed, ok;
    if(~gui.isNil) { ^false };
    winObj = ~gui.tryPerform(\window);
    if(winObj.isNil) { ^false };
    viewObj = winObj.tryPerform(\view);
    wasRemoved = viewObj.tryPerform(\wasRemoved);
    if(wasRemoved.isNil) { wasRemoved = false };
    isClosed = winObj.tryPerform(\isClosed);
    if(isClosed.isNil) { isClosed = false };
    ok = (wasRemoved == false) and: (isClosed == false);
    ok
};

~md_checkWindows = {
    AppClock.sched(0, {
        var wins;
        wins = Window.allWindows ? [];
        ("[CHECK] window count = " ++ wins.size).postln;
        wins.do({ |w, idx| ("[CHECK] w" ++ idx ++ " title=" ++ w.name.asString).postln });
        nil
    });
};

~md_checkEnv = {
    var hasGui, hasMpb;
    hasGui = ~gui.notNil; hasMpb = ~mpb.notNil;
    ("[CHECK] has ~gui = " ++ hasGui.asString ++ ", has ~mpb = " ++ hasMpb.asString).postln;
    if(hasGui and: { ~gui.respondsTo(\window) }) {
        ("[CHECK] window exists = " ++ (~gui.window.notNil).asString).postln;
    };
};

// ---------------------------
// 2) minimal reset (no programmatic window close)
// ---------------------------
~md_resetSession = {
    var hadTask, hadBootTask, alive;
    hadTask = ~mdgTask.notNil;
    hadBootTask = ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    // If the window is dead, force fresh next time.
    alive = ~md_isWindowAlive.();
    if(alive.not) { ~gui = nil };

    // Always clear pedalboard refs; runner guarantees rebuild.
    ~mpb = nil;
    ~magicDisplay = nil;

    "[RUNNER] Reset: tasks stopped; references cleared."
        ++ (alive.not.if({ " (~gui cleared: window not alive)" }, { "" }))
        .postln;
};

// -------------------------------------------
// 3) ensure pedalboard exists immediately
// -------------------------------------------
~md_ensureMpbNow = {
    var created;
    created = false;

    if(~gui.isNil) { "[ENSURE] No ~gui yet; cannot build ~mpb.".warn; ^false };

    if(~mpb.isNil) {
        ~mpb = MagicPedalboardNew(~gui);
        created = true;
        "[ENSURE] Built new MagicPedalboardNew (~mpb).".postln;
    };

    created or: { ~mpb.notNil }
};

// -------------------------------------------
// 4) single, idempotent boot on AppClock only
// -------------------------------------------
~bootGuiV6 = {
    var myToken;
    ~md_resetSession.();

    ~md_bootToken = (~md_bootToken ? 0) + 1;
    myToken = ~md_bootToken;

    "Booting GUI (meters disabled). Waiting for window…".postln;

    AppClock.sched(0, {
        var winOk, existingWin, guiObj, board;

        if(~md_bootToken != myToken) { ^nil }; // stale invocation

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
            };
            if(~refreshView.notNil) { ~refreshView.("boot") };
            nil
        });

        nil
    });
};

// ------------------------------------------------------
// 5) fallbacks if monolithic helpers aren’t loaded
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
// 6) fast scenario: each step runs on AppClock directly
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
// 7) single-button: reset → boot → probe → fast scenario
//    with RE-ENTRANCY GUARD
// ------------------------------------------------------
~md_bootProbeScenario = {
    var runnerTask, waitCount, maxWait, done;

    if(~md_runnerActive == true) {
        "[RUNNER] Already running — ignoring new request.".postln;
        ^~md_runnerTask
    };

    ~md_runnerActive = true;

    runnerTask = Task({
        ~md_log.("Starting: reset → boot → probe → scenario");
        ~md_resetSession.();
        ~bootGuiV6.();

        // Wait up to ~1.5s for ~gui and ~mpb (30 * 0.05)
        waitCount = 0; maxWait = 30; done = false;
        while({ done.not and: { waitCount < maxWait } }, {
            if(~gui.notNil and: { ~mpb.notNil }) { done = true }{ 0.05.wait; waitCount = waitCount + 1 };
        });

        if(~mpb.isNil) { ~md_ensureMpbNow.() };
        if(~gui.isNil or: { ~mpb.isNil }) {
            "[RUNNER] Cannot proceed: ~gui or ~mpb missing.".warn;
            // fall through to clear the active flag
        }{
            "[RUNNER] Probe…".postln;
            ~probeGuiV3.();

            0.3.wait;

            "[RUNNER] Scenario (fast)…".postln;
            ~scenario1v6_fast.();
        };

        // Always clear active flag at end
        AppClock.sched(0, { ~md_runnerActive = false; nil });
    });

    ~md_runnerTask = runnerTask.start;  // start on SystemClock
    ~md_runnerTask
};

// --- 1) Manual unlock if the guard got stuck ---
~md_runnerUnlock = {
    var wasActive;
    wasActive = ~md_runnerActive ? false;
    ~md_runnerActive = false;
    ~md_runnerTask.notNil.if({ ~md_runnerTask.stop; ~md_runnerTask = nil; });
    ("[RUNNER] unlocked (wasActive=" ++ wasActive.asString ++ ")").postln;
    true
};

// --- 2) Force-create a fresh GUI + MPB on AppClock (no reuse logic) ---
~md_forceCreateWindow = {
    AppClock.sched(0, {
        var guiObj, board, winReady;
        "[FORCE] Creating MagicDisplayGUI…".postln;
        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        "[FORCE] Creating MagicPedalboardNew…".postln;
        board = MagicPedalboardNew(guiObj);
        ~mpb = board;

        AppClock.sched(0.1, {  // 0.1s to be extra safe
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "[FORCE] Window ready — fronting.".postln;
                winReady.alwaysOnTop_(true);
                winReady.front;
                AppClock.sched(0.2, { winReady.alwaysOnTop_(false); nil });
            }{
                "[FORCE] Window not yet ready.".postln;
            };
            if(~refreshView.notNil) { ~refreshView.("force-create") };
            nil
        });
        nil
    });
};

// --- 3) Front the window robustly (on AppClock) ---
~md_frontWindow = {
    AppClock.sched(0, {
        var win;
        win = ~gui.tryPerform(\window);
        if(win.notNil) {
            win.alwaysOnTop_(true);
            win.front;
            AppClock.sched(0.2, { win.alwaysOnTop_(false); nil });
        }{
            "[FRONT] No window to front.".postln;
        };
        nil
    });
};

// --- 4) Add a safety auto-unlock in the runner (does not disturb active runs) ---
~md_addSafetyUnlock = {
    // If the runner is marked active but the task isn't playing after 3s, unlock.
    SystemClock.sched(3.0, {
        var playing;
        playing = ~md_runnerTask.notNil and: { ~md_runnerTask.isPlaying ? false };
        if(~md_runnerActive == true and: { playing == false }) {
            "[RUNNER] safety unlock".postln;
            ~md_runnerActive = false;
            ~md_runnerTask = nil;
        };
        nil
    });
    true
};

// Re-wrap ~md_bootProbeScenario to include the safety unlock call
~md_bootProbeScenario = {
    var runnerTask, waitCount, maxWait, done;

    if(~md_runnerActive == true) {
        "[RUNNER] Already running — ignoring new request.".postln;
        ^~md_runnerTask
    };

    ~md_runnerActive = true;
    ~md_addSafetyUnlock.();  // arm the safety valve each run

    runnerTask = Task({
        ~md_log.("Starting: reset → boot → probe → scenario");
        ~md_resetSession.();
        ~bootGuiV6.();

        // Wait up to ~1.5s for ~gui and ~mpb (30 * 0.05)
        waitCount = 0; maxWait = 30; done = false;
        while({ done.not and: { waitCount < maxWait } }, {
            if(~gui.notNil and: { ~mpb.notNil }) { done = true }{ 0.05.wait; waitCount = waitCount + 1 };
        });

        if(~mpb.isNil) { ~md_ensureMpbNow.() };

        if(~gui.isNil or: { ~mpb.isNil }) {
            "[RUNNER] Cannot proceed: ~gui or ~mpb missing. Try ~md_forceCreateWindow.();".warn;
        }{
            "[RUNNER] Probe…".postln;
            ~probeGuiV3.();

            0.3.wait;

            "[RUNNER] Scenario (fast)…".postln;
            ~scenario1v6_fast.();
        };

        // Always clear active flag at end
        AppClock.sched(0, { ~md_runnerActive = false; ~md_runnerTask = nil; nil });
    });

    ~md_runnerTask = runnerTask.start;  // SystemClock
    ~md_runnerTask
};


"Ready. After reboot, evaluate this file, then run: ~md_bootProbeScenario.();".postln;
)

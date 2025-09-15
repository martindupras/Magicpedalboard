/* Runner_MagicDisplayGUI.scd
   Deterministic, single-window GUI boot → probe → scenario (fast).
   - AppClock-only Qt ops, no watchers/patchers.
   - Smart reuse (detects dead windows), pedalboard guarantee, singleton window.
   - Re-entrancy guard + safety unlock.
   Style: tilde vars, var-first, lowercase, no server.sync, no single-letter locals.
*/

(
// ---------------------------
// 0) state + logging
// ---------------------------
~md_bootToken     = (~md_bootToken ? 0);
~md_runnerActive  = (~md_runnerActive ? false);
~md_runnerTask    = (~md_runnerTask ? nil);
~md_log = { |messageString| ("[RUNNER] " ++ messageString).postln };

// ---------------------------
// 1) window helpers
// ---------------------------
~md_isWindowAlive = {
    var winObj, viewObj, wasRemoved, isClosed, ok;
    if(~gui.isNil) { ^false };
    winObj = ~gui.tryPerform(\window);
    if(winObj.isNil) { ^false };
    viewObj    = winObj.tryPerform(\view);
    wasRemoved = viewObj.tryPerform(\wasRemoved);
    if(wasRemoved.isNil) { wasRemoved = false };
    isClosed   = winObj.tryPerform(\isClosed);
    if(isClosed.isNil) { isClosed = false };
    ok = (wasRemoved == false) and: (isClosed == false);
    ok
};

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

~md_coalesceWindows = {
    AppClock.sched(0, {
        var myWin, title, wins, closed;
        myWin  = ~gui.tryPerform(\window);
        wins   = Window.allWindows ? [];
        title  = myWin.notNil.if({ myWin.name.asString }, { "MagicDisplayGUI" });
        closed = 0;
        wins.do({ |w|
            if((myWin.isNil or: { w !== myWin }) and: { w.name.asString == title }) {
                w.close;
                closed = closed + 1;
            }
        });
        ("[COALESCE] closed " ++ closed.asString ++ " extra window(s).").postln;
        if(myWin.notNil) {
            myWin.alwaysOnTop_(true);
            myWin.front;
            AppClock.sched(0.2, { myWin.alwaysOnTop_(false); nil });
        };
        nil
    });
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
// 2) reset + ensure
// ---------------------------
~md_resetSession = {
    var hadTask, hadBootTask, alive;
    hadTask    = ~mdgTask.notNil;
    hadBootTask= ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    alive = ~md_isWindowAlive.();
    if(alive.not) { ~gui = nil };  // force fresh next time

    ~mpb = nil;
    ~magicDisplay = nil;

    "[RUNNER] Reset: tasks stopped; references cleared."
        ++ (alive.not.if({ " (~gui cleared: window not alive)" }, { "" })).postln;
};

~md_ensureMpbNow = {
    var created;
    created = false;
    if(~gui.isNil) { "[ENSURE] No ~gui yet; cannot build ~mpb.".warn; ^false };
    if(~mpb.isNil) { ~mpb = MagicPedalboardNew(~gui); created = true; "[ENSURE] Built new MagicPedalboardNew (~mpb).".postln; };
    created or: { ~mpb.notNil }
};

// ---------------------------
// 3) fresh creator (used by boot and as emergency fixer)
// ---------------------------
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

        AppClock.sched(0.1, {
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
            // Always coalesce after a force create
            ~md_coalesceWindows.();
            nil
        });
        nil
    });
};

// ---------------------------
// 4) boot (idempotent), singletonize, guarantee mpb
// ---------------------------
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
            // Coalesce duplicate windows even on reuse
            ~md_coalesceWindows.();
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

        AppClock.sched(0.1, {
            var winReady;
            if(~md_bootToken != myToken) { ^nil };
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "Window ready — fronting and drawing columns.".postln;
                winReady.front;
            };
            // Coalesce duplicates after fresh create
            ~md_coalesceWindows.();
            if(~refreshView.notNil) { ~refreshView.("boot") };
            nil
        });

        nil
    });
};

// ---------------------------
// 5) fallbacks if monolithic helpers aren’t loaded
// ---------------------------
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

// ---------------------------
// 6) fast scenario (AppClock per step)
// ---------------------------
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

// ---------------------------
// 7) runner with re-entrancy guard + safety unlock
// ---------------------------
~md_runnerUnlock = {
    var wasActive;
    wasActive = ~md_runnerActive ? false;
    ~md_runnerActive = false;
    ~md_runnerTask.notNil.if({ ~md_runnerTask.stop; ~md_runnerTask = nil; });
    ("[RUNNER] unlocked (wasActive=" ++ wasActive.asString ++ ")").postln;
    true
};

~md_addSafetyUnlock = {
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

~md_bootProbeScenario = {
    var runnerTask, waitCount, maxWait, done;

    if(~md_runnerActive == true) {
        "[RUNNER] Already running — ignoring new request.".postln;
        ^~md_runnerTask
    };

    ~md_runnerActive = true;
    ~md_addSafetyUnlock.();

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

        AppClock.sched(0, { ~md_runnerActive = false; ~md_runnerTask = nil; nil });
    });

    ~md_runnerTask = runnerTask.start;  // SystemClock task
    ~md_runnerTask
};

"Ready. After reboot, evaluate this file, then run: ~md_bootProbeScenario.();".postln;
)

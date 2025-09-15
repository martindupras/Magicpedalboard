/* Runner_MagicDisplayGUI_DebugPatch.scd
   Adds diagnostics + a force-create fallback for windowless runs.
   Style: tilde vars, var-first, lowercase names, no server.sync, no single-letter locals.
*/

(
// 0) quick AppClock sanity
~md_appClockCheck = {
    AppClock.sched(0, { "[CHECK] AppClock tick ok".postln; nil });
    { "[CHECK] defer ok".postln }.defer;
    "[CHECK] scheduled checks (AppClock + defer)".postln;
};

// 1) force-create: make a brand-new GUI + MPB on AppClock, no reuse
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

        AppClock.sched(0.05, {
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "[FORCE] Window ready — fronting.".postln;
                winReady.front;
            }{
                "[FORCE] Window not yet ready.".postln;
            };
            if(~refreshView.notNil) { ~refreshView.("force-create") };
            nil
        });

        nil
    });
};

// 2) robust “is window alive?”
~md_isWindowAlive = {
    var winObj, wasRemoved, isClosed, viewObj, ok;
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

// 3) redefine reset: clear ~gui only if window is not alive, with explicit note
~md_resetSession = {
    var hadTask, hadBootTask, alive;
    hadTask = ~mdgTask.notNil;
    hadBootTask = ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    alive = ~md_isWindowAlive.();
    if(alive.not) { ~gui = nil };

    ~mpb = nil;
    ~magicDisplay = nil;

    ("[RUNNER] Reset: tasks stopped; references cleared."
        ++ (alive.not.if({ " (~gui cleared: window not alive)" }, { "" }))).postln;
};

// 4) instrumented ~bootGuiV6: logs every step inside AppClock so we can see where it stops
~bootGuiV6 = {
    var myToken;
    ~md_resetSession.();

    ~md_bootToken = (~md_bootToken ? 0) + 1;
    myToken = ~md_bootToken;

    "[BOOT] Enter".postln;
    "Booting GUI (meters disabled). Waiting for window…".postln;

    AppClock.sched(0, {
        var winOk, existingWin, guiObj, board;

        ("[BOOT/AC] token=" ++ myToken.asString ++ " current=" ++ ~md_bootToken.asString).postln;
        if(~md_bootToken != myToken) { "[BOOT/AC] stale token; abort".postln; ^nil };

        winOk = ~md_isWindowAlive.();
        ("[BOOT/AC] windowAlive=" ++ winOk.asString).postln;

        if(winOk) {
            existingWin = ~gui.tryPerform(\window);
            "[BOOT/AC] reusing window → front".postln;

            if(~mpb.isNil) {
                "[BOOT/AC] ~mpb missing → creating…".postln;
                board = MagicPedalboardNew(~gui);
                ~mpb = board;
                "[BOOT/AC] ~mpb created".postln;
            };

            existingWin.front;
            if(~refreshView.notNil) { ~refreshView.("boot (reuse)") };
            ^nil
        };

        "[BOOT/AC] creating GUI…".postln;
        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        "[BOOT/AC] creating MPB…".postln;
        board = MagicPedalboardNew(guiObj);
        ~mpb = board;

        AppClock.sched(0.05, {
            var winReady;
            "[BOOT/AC] post-create tick".postln;
            if(~md_bootToken != myToken) { "[BOOT/AC] stale token in post-create; abort".postln; ^nil };
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "[BOOT/AC] window ready → front".postln;
                winReady.front;
            }{
                "[BOOT/AC] window not yet available".postln;
            };
            if(~refreshView.notNil) { ~refreshView.("boot") };
            nil
        });

        nil
    });
};
)

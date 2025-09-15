// TEST_overlayHotFix.scd

(
// v0.10.5 overlay: deterministic, single-boot flow without programmatic window closing

// 0) Global boot token (guards against overlapping boots)
~md_bootToken = (~md_bootToken ? 0);

// 1) Minimal reset: stop our tasks; DO NOT touch windows (avoid Qt races)
~md_resetSession = {
    var hadTask, hadBootTask;
    hadTask = ~mdgTask.notNil;
    hadBootTask = ~bootTask.notNil;

    hadTask.if({ ~mdgTask.stop; ~mdgTask = nil; });
    hadBootTask.if({ ~bootTask.stop; ~bootTask = nil; });

    // Do not close windows here; just clear our references
    ~mpb = nil;
    ~magicDisplay = nil;

    "[RESET] Minimal reset: tasks stopped; references cleared (windows untouched).".postln;
};

// 2) Single, idempotent boot: reuse window if present; otherwise create exactly once
~bootGuiV6 = {
    var myToken;

    ~md_resetSession.();

    // Bump token so any older scheduled boot code bails out
    ~md_bootToken = ~md_bootToken + 1;
    myToken = ~md_bootToken;

    "Booting GUI (meters disabled). Waiting for window…".postln;

    AppClock.sched(0, {
        var existingWin, guiObj, board;

        // If a newer boot started meanwhile, abort
        if(~md_bootToken != myToken) { ^nil };

        // Reuse if we already have a live GUI with a window
        if(~gui.notNil) {
            existingWin = ~gui.tryPerform(\window);
            if(existingWin.notNil) {
                "Window found — reusing and fronting.".postln;
                existingWin.front;
                ~refreshView.notNil.if({ ~refreshView.("boot (reuse)") });
                ^nil
            };
        };

        // Otherwise create cleanly (exactly once for this token)
        guiObj = MagicDisplayGUI.new;
        guiObj.enableMeters(false);
        ~gui = guiObj;

        board = MagicPedalboardNew(guiObj);
        ~mpb = board;

        // Give the GUI a tick to build its window internally, then front and draw
        AppClock.sched(0.05, {
            var winReady;
            if(~md_bootToken != myToken) { ^nil }; // a newer boot superseded this one
            winReady = ~gui.tryPerform(\window);
            if(winReady.notNil) {
                "Window ready — fronting and drawing columns.".postln;
                winReady.front;
            }{
                "Window not yet available; will front when the next GUI call happens.".postln;
            };
            ~refreshView.notNil.if({ ~refreshView.("boot") });
            nil
        });

        nil
    });
};

// 3) Keep the fast AppClock scenarios as the only path (no queueUi patching)
~scenario1v6_fast = ~scenario1v6_fast ?? {
    var paceSeconds, steps, mkFastScenario;

    mkFastScenario = { |labelString, waitSeconds, stepFuncs|
        var controllerRoutine, totalSteps, stepIndex;
        totalSteps = stepFuncs.size;
        ~mdgTask.notNil.if({ ~mdgTask.stop; ~mdgTask = nil });

        controllerRoutine = Routine({
            stepIndex = 0;
            while({ stepIndex < totalSteps }, {
                AppClock.sched(0, { stepFuncs[stepIndex].value; nil });
                waitSeconds.wait; // pacing on SystemClock; UI ops happen on AppClock
                stepIndex = stepIndex + 1;
            });
        });

        ~mdgTask = controllerRoutine.play(SystemClock);
        ~mdgTask
    };

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };
    paceSeconds = 0.8;
    steps = [
        { ~log.notNil.if({ ~log.("init") }); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add flanger") }); ~gui.showExpectation("Command: add flanger", 0); ~mpb.add(\flanger); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("bypass flanger true") }); ~gui.showExpectation("Command: bypass flanger true", 0); ~mpb.bypass(\flanger, true); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add delay") }); ~gui.showExpectation("Command: add delay", 0); ~mpb.add(\delay); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("clear NEXT") }); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    mkFastScenario.("scenario1-fast", paceSeconds, steps);
};

~scenario2v6_fast = ~scenario2v6_fast ?? {
    var paceSeconds, steps, mkFastScenario;

    mkFastScenario = { |labelString, waitSeconds, stepFuncs|
        var controllerRoutine, totalSteps, stepIndex;
        totalSteps = stepFuncs.size;
        ~mdgTask.notNil.if({ ~mdgTask.stop; ~mdgTask = nil });

        controllerRoutine = Routine({
            stepIndex = 0;
            while({ stepIndex < totalSteps }, {
                AppClock.sched(0, { stepFuncs[stepIndex].value; nil });
                waitSeconds.wait;
                stepIndex = stepIndex + 1;
            });
        });

        ~mdgTask = controllerRoutine.play(SystemClock);
        ~mdgTask
    };

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };
    paceSeconds = 0.25;
    steps = [
        { ~log.notNil.if({ ~log.("init") }); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add chorus") }); ~gui.showExpectation("Command: add chorus", 0); ~mpb.add(\chorus); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add reverb") }); ~gui.showExpectation("Command: add reverb", 0); ~mpb.add(\reverb); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add tremolo") }); ~gui.showExpectation("Command: add tremolo", 0); ~mpb.add(\tremolo); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("removeAt 2") }); ~gui.showExpectation("Command: removeAt 2", 0); ~mpb.removeAt(2); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add phaser") }); ~gui.showExpectation("Command: add phaser", 0); ~mpb.add(\phaser); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("clear NEXT") }); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    mkFastScenario.("scenario2-fast", paceSeconds, steps);
};

~scenario3v6_fast = ~scenario3v6_fast ?? {
    var paceSeconds, steps, mkFastScenario;

    mkFastScenario = { |labelString, waitSeconds, stepFuncs|
        var controllerRoutine, totalSteps, stepIndex;
        totalSteps = stepFuncs.size;
        ~mdgTask.notNil.if({ ~mdgTask.stop; ~mdgTask = nil });

        controllerRoutine = Routine({
            stepIndex = 0;
            while({ stepIndex < totalSteps }, {
                AppClock.sched(0, { stepFuncs[stepIndex].value; nil });
                waitSeconds.wait;
                stepIndex = stepIndex + 1;
            });
        });

        ~mdgTask = controllerRoutine.play(SystemClock);
        ~mdgTask
    };

    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };
    paceSeconds = 0.6;
    steps = [
        { ~log.notNil.if({ ~log.("init") }); ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("add bitcrusher") }); ~gui.showExpectation("Command: add bitcrusher", 0); ~mpb.add(\bitcrusher); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("bypass bitcrusher false") }); ~gui.showExpectation("Command: bypass bitcrusher false", 0); ~mpb.bypass(\bitcrusher, false); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("removeAt 1") }); ~gui.showExpectation("Command: removeAt 1", 0); ~mpb.removeAt(1); ~refreshGuiFromMpb.() },
        { ~log.notNil.if({ ~log.("clear NEXT") }); ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    mkFastScenario.("scenario3-fast", paceSeconds, steps);
};

// 4) One-button runner: boot → probe → fast scenario (no patches, no watchers, no closing)
~md_go = {
    var bootTask;
    bootTask = Task({
        "[ALL-IN-ONE] Booting GUI (v6 alias)…".postln;
        ~bootGuiV6.();

        // allow the window to be created and fronted
        0.8.wait;

        if(~probeGuiV3.notNil) {
            "[ALL-IN-ONE] Running probe (~probeGuiV3)…".postln;
            ~probeGuiV3.();
        };

        0.3.wait;

        "[ALL-IN-ONE] Running scenario (~scenario1v6_fast)…".postln;
        ~scenario1v6_fast.();
    });
    bootTask.start;
    bootTask
};

// Optional: quick window inspector to verify number/titles (runs on AppClock)
~md_checkWindows = {
    AppClock.sched(0, {
        var wins;
        wins = Window.allWindows ? [];
        ("[CHECK] window count = " ++ wins.size).postln;
        wins.do({ |w, idx| ("[CHECK] w" ++ idx ++ " title=" ++ w.name.asString).postln });
        nil
    });
};
)

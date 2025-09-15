// Test_MagicPedalboardNew_v0_13_QA_PauseResume_GUI.scd // WORKING right at 13:41
// MD 20250912-1325

(
// Run only after the server is booted.
s.waitForBoot({

    // ─────────────────────────────────────────────────────────────
    // var-first: declare everything used in this block up front
    // ─────────────────────────────────────────────────────────────
    var preflightCleanup;
    var m, setCurrent, setNext, forceSilentBaseline;
    var qa;
    var win, infoText, noteField, btnReport, btnSubmit, btnResume;
    var say, countdown, show, snapshot, setActiveStep, pushStep, absorbPending, waitIfPaused;
    var runRoutine;
    var before, after;

    // ─────────────────────────────────────────────────────────────
    // 0) Preflight: clear old JITLib state; keep the default group
    // ─────────────────────────────────────────────────────────────
    preflightCleanup = {
        "[QA] Preflight: clearing Ndefs & ProxySpaces…".postln;

        // Stop & clear any lingering Ndefs from older sessions
        Ndef.all.keysValuesDo { |key, proxy|
            if(proxy.isPlaying) { ("[CLEAN] stop " ++ key).postln; proxy.stop };
            proxy.clear;
        };

        // Clear any ProxySpaces we can see (class may not expose .all on some builds)
        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo { |srv, ps|
                if(ps.notNil) { ("[CLEAN] ProxySpace on " ++ srv).postln; ps.clear };
            };
        };

        // If the *current* environment is a ProxySpace, pop it
        if(currentEnvironment.notNil and: { currentEnvironment.class.name == "ProxySpace" }) {
            "[CLEAN] Pop current ProxySpace env".postln;
            currentEnvironment.pop;
        };

        // Safe server-tree reset (no s.freeAll): keep Group 1 so Ndef/JITLib can attach
        s.initTree;
        s.defaultGroup.freeAll;

        "== Preflight done ==".postln;
    };
    preflightCleanup.();

    // ─────────────────────────────────────────────────────────────
    // 1) Minimal test sources / processors
    // ─────────────────────────────────────────────────────────────
    Ndef(\ts0,   { Silent.ar(2) });
    Ndef(\tsDust,{ Dust.ar(2000) ! 2 });
    Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });
    Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });

    Ndef(\tremolo, { |rate = 4, depth = 0.9|
        var x;
        x = \in.ar(2);
        x * SinOsc.kr(rate).range(1 - depth, 1)
    });

    Ndef(\lofi, { |bits = 4, rate = 4000|
        var x;
        x = \in.ar(2);
        Decimator.ar(x, rate, bits)
    });

    Ndef(\atten, { |gain = 0.25|
        var x;
        x = \in.ar(2);
        x * gain
    });

    // ─────────────────────────────────────────────────────────────
    // 2) Pedalboard + hard silent baseline
    // ─────────────────────────────────────────────────────────────
    m = MagicPedalboardNew.new;
    m.reset;

    setCurrent = { |key|
        if(m.respondsTo(\setSourceCurrent)) { m.setSourceCurrent(key) }
        { "ERROR: setSourceCurrent missing".warn };
    };
    setNext = { |key|
        if(m.respondsTo(\setSource)) { m.setSource(key) }
        { "ERROR: setSource missing".warn };
    };

    forceSilentBaseline = {
        "[QA] Force silent baseline…".postln;
        m.reset;
        setCurrent.(\ts0);
        setNext.(\ts0);

        m.clearChain;            // clear NEXT
        m.switchChain;
        m.clearChain;            // clear previous CURRENT (now NEXT)
        m.switchChain;

        Ndef(\chainA).play(numChannels: 2);
        Ndef(\chainB).stop;

        "[QA] Baseline set. Expect: silence now.".postln;
    };
    forceSilentBaseline.();

    // ─────────────────────────────────────────────────────────────
    // 3) QA state (pause controller, steps, issues)
    // ─────────────────────────────────────────────────────────────
    qa = (
        steps: Array.new,
        issues: Array.new,
        currentStep: nil,
        pendingIssues: IdentityDictionary.new,   // stepId -> (reason:, note:)
        pauseRequested: false,
        pauseCondition: Condition.new
    );

    // ─────────────────────────────────────────────────────────────
    // 4) GUI (AppClock). Window shows PAUSED state & toggles buttons.
    // ─────────────────────────────────────────────────────────────
    win = Window("MPBNew QA – press X to pause; Enter to submit; Esc to resume",
                 Rect(100, 100, 740, 230)).front.alwaysOnTop_(true);
    infoText = StaticText(win, Rect(10, 10, 720, 44)).string_("Step: (pending)");
    noteField = TextField(win, Rect(10, 60, 720, 24)).string_("Type your note here…");

    btnReport = Button(win, Rect(10, 100, 230, 30))
        .states_([["Report Issue (Pause)", Color.white, Color.red]])
        .action_({
            qa[\pauseRequested] = true; "[QA] pause requested".postln;
            AppClock.sched(0, {
                infoText.string = "PAUSED: type a note, then Submit or Resume.";
                win.name = "MPBNew QA – PAUSED";
                btnReport.enabled = false; btnSubmit.enabled = true; btnResume.enabled = true; nil
            });
        });

    btnSubmit = Button(win, Rect(250, 100, 230, 30))
        .states_([["Submit Issue & Resume", Color.white, Color(0, 0.5, 0)]])
        .action_({
            var noteTxt, stepIdLocal, reasonTxt;
            noteTxt = noteField.string;
            reasonTxt = "user report (paused)";
            stepIdLocal = qa[\currentStep].notNil.if({ qa[\currentStep][\id] }, { "unknown-" ++ Main.elapsedTime.round(0.01) });
            qa[\pendingIssues][stepIdLocal] = (reason: reasonTxt, note: noteTxt);
            ("[QA] issue submitted for " ++ stepIdLocal).postln;
            if(noteTxt.notNil and: { noteTxt != "" }) { ("[QA] note: " ++ noteTxt).postln };
            qa[\pauseRequested] = false; qa[\pauseCondition].signal;
            AppClock.sched(0, {
                infoText.string = "Captured issue for " ++ stepIdLocal ++ ". Resuming…";
                win.name = "MPBNew QA";
                btnReport.enabled = true; btnSubmit.enabled = false; btnResume.enabled = false; nil
            });
        })
        .enabled_(false);

    btnResume = Button(win, Rect(490, 100, 230, 30))
        .states_([["Resume (No Issue)", Color.white, Color.gray]])
        .action_({
            "[QA] resume (no issue)".postln;
            qa[\pauseRequested] = false; qa[\pauseCondition].signal;
            AppClock.sched(0, {
                infoText.string = "Resuming without logging an issue…";
                win.name = "MPBNew QA";
                btnReport.enabled = true; btnSubmit.enabled = false; btnResume.enabled = false; nil
            });
        })
        .enabled_(false);

    // keyboard shortcuts
    win.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
        if(char == $x or: { char == $X }) { btnReport.action.value };
        if(keycode == 36 or: { keycode == 52 }) { btnSubmit.action.value }; // Enter / keypad Enter
        if(keycode == 53) { btnResume.action.value };                       // Esc
    };

    // ─────────────────────────────────────────────────────────────
    // 5) Helpers (SystemClock-safe)
    // ─────────────────────────────────────────────────────────────
    say = { |txt| txt.asString.postln };

    countdown = { |n = 3|
        var i;
        i = n;
        while { i > 0 } {
            waitIfPaused.();
            (i.asString ++ "...").postln;
            1.wait;  // SystemClock wait
            i = i - 1;
        };
        waitIfPaused.();
        "Now.".postln;
    };

    waitIfPaused = {
        var t0;
        if(qa[\pauseRequested]) { "[QA] waiting (paused)".postln };
        t0 = Main.elapsedTime;
        while { qa[\pauseRequested] } {
            qa[\pauseCondition].wait;   // signalled by AppClock (GUI buttons)
            if(qa[\pauseRequested] and: { Main.elapsedTime - t0 > 30 }) {
                "[QA] timeout → auto-resume".warn;
                qa[\pauseRequested] = false;
                qa[\pauseCondition].signal;
            };
        };
        if(qa[\pauseRequested].not) { "[QA] resumed".postln };
    };

    show = {
        "— Chains —".postln;
        m.printChains;
        "".postln;
    };

    snapshot = {
        (
            time: Main.elapsedTime,
            current: m.currentChain.copy,
            next: m.nextChain.copy,
            effCurrent: m.effectiveCurrent,
            effNext: m.effectiveNext,
            bypassCurrent: m.bypassKeysCurrent,
            bypassNext: m.bypassKeysNext
        )
    };

    setActiveStep = { |id, title, expected|
        qa[\currentStep] = nil;  // will set when pushing the step
        AppClock.sched(0, {
            infoText.string = "Step: " ++ id ++ " — " ++ title ++ "\nExpect: " ++ expected;
            win.name = "MPBNew QA";
            nil
        });
    };

    absorbPending = { |id, entry|
        var p;
        p = qa[\pendingIssues][id];
        if(p.notNil) {
            entry[\userFlagged] = true;
            entry[\userReason] = p[\reason];
            entry[\userNote] = p[\note];
            if(qa[\issues].includes(id).not) { qa[\issues] = qa[\issues].add(id) };
            qa[\pendingIssues].removeAt(id);
        };
    };

    pushStep = { |id, title, expected, beforeSnap, afterSnap|
        var e;
        e = (id: id, title: title, expected: expected, before: beforeSnap,
             after: afterSnap, userFlagged: false, userReason: nil, userNote: nil);
        qa[\steps] = qa[\steps].add(e);
        qa[\currentStep] = e;
        absorbPending.(id, e);
    };

    // ─────────────────────────────────────────────────────────────
    // 6) Narrative Routine (RUN ON SystemClock)
    // ─────────────────────────────────────────────────────────────
    runRoutine = Routine({

        // A) Start silent
        setActiveStep.("A1", "Start silent \\ts0 on CURRENT", "Silence");
        say.("Starting with a silent CURRENT chain. Starting in");
        countdown.(3);
        before = snapshot.();
        setCurrent.(\ts0);
        m.playCurrent;
        show.();
        say.("You should hear nothing.");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("A1", "silent on CURRENT", "You should hear nothing.", before, after);

        // B) CURRENT → Dust
        setActiveStep.("B1", "Change CURRENT source to Dust", "Irregular noise bursts (stereo)");
        say.("Change CURRENT source to Dust(2000). Starting in");
        countdown.(3);
        before = snapshot.();
        setCurrent.(\tsDust);
        show.();
        say.("You should hear irregular noise bursts in stereo.");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("B1", "dust on CURRENT", "Irregular noise bursts", before, after);

        // C) NEXT: Saw + Tremolo → switch
        setActiveStep.("C1", "Prepare NEXT: Saw + Tremolo, then switch", "Saw with deep tremolo");
        say.("Prepare NEXT: set source to Saw; add Tremolo just before the source.");
        say.("Setting NEXT source to Saw in");
        countdown.(2);
        before = snapshot.();
        setNext.(\tsSaw);
        m.add(\tremolo);
        show.();
        say.("Switch to NEXT (so Tremolo+Saw becomes CURRENT). Starting in");
        countdown.(3);
        m.switchChain; show.();
        say.("You should hear a saw tone with strong amplitude modulation (tremolo).");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("C1", "switch to Saw + Tremolo", "Saw with strong tremolo", before, after);

        // D1) Bypass tremolo
        setActiveStep.("D1", "Bypass CURRENT tremolo", "Plain Saw (no tremolo)");
        say.("Bypass CURRENT tremolo. Starting in");
        countdown.(2);
        before = snapshot.();
        m.bypassCurrent(\tremolo, true); show.();
        say.("You should hear plain Saw (no tremolo).");
        waitIfPaused.(); 1.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("D1", "bypass tremolo", "Plain Saw", before, after);

        // D2) Un-bypass tremolo
        setActiveStep.("D2", "Un-bypass CURRENT tremolo", "Saw with tremolo returns");
        say.("Un-bypass CURRENT tremolo. Starting in");
        countdown.(2);
        before = snapshot.();
        m.bypassCurrent(\tremolo, false); show.();
        say.("Tremolo should be back.");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("D2", "un-bypass tremolo", "Saw with tremolo", before, after);

        // E) Prepare NEXT: atten + lofi + swap → switch
        setActiveStep.("E1", "Prepare NEXT: add Atten then Lofi; swap; then switch", "Saw with heavy attenuation + crushing");
        say.("Prepare NEXT: add \\atten near sink (index 1) and \\lofi after it, then swap them.");
        say.("Adding \\atten at index 1 in");
        countdown.(2);
        before = snapshot.();
        m.addAt(\atten, 1); show.();

        say.("Adding \\lofi at index 2 in");
        countdown.(2);
        m.addAt(\lofi, 2); show.();

        say.("Swap NEXT indices 1 and 2 in");
        countdown.(2);
        m.swap(1, 2); show.();

        say.("Switch to NEXT in");
        countdown.(3);
        m.switchChain; show.();
        say.("You should hear Saw with lower level and obvious bitcrush/decimation.");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("E1", "switch to Atten+Lofi+Saw", "Quiet + crushed Saw", before, after);

        // F) On NEXT: remove @1, then clear
        setActiveStep.("F1", "On NEXT: remove index 1, then clear", "NEXT ends as [sink, source]");
        say.("On NEXT, remove the processor at index 1 (nearest the sink), then clear.");
        say.("Removing at index 1 on NEXT in");
        countdown.(2);
        before = snapshot.();
        m.removeAt(1); show.();
        say.("Clear NEXT back to [sink, source] in");
        countdown.(2);
        m.clearChain; show.();
        waitIfPaused.(); 1.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("F1", "remove + clear NEXT", "[sink, source]", before, after);

        // G) NEXT → ts0, then switch (silent again)
        setActiveStep.("G1", "Set NEXT source to ts0, then switch", "Silence");
        say.("Set NEXT source to \\ts0 and then switch.");
        say.("Starting in");
        countdown.(3);
        before = snapshot.();
        setNext.(\ts0);
        m.switchChain; show.();
        say.("You should now hear silence.");
        waitIfPaused.(); 2.wait; waitIfPaused.();
        after = snapshot.();
        pushStep.("G1", "switch to ts0", "Silence", before, after);

        // Done
        say.("Done. Stopping."); m.stopCurrent;
    }).play(SystemClock);   // Routine on SystemClock; GUI on AppClock
});
)

// Test_MagicPedalboardNew_v0_12_QA_PauseResume_FixedPreflight.scd
// MD 20250911-1315

(
// ─────────────────────────────────────────────────────────────────
// All code is executed only after the server is booted and ready.
// ─────────────────────────────────────────────────────────────────
s.waitForBoot({

    var qaWindow, infoText, noteTextField, reportButton, submitButton, resumeButton, updateInfoFn;
    var waitShortDur, waitMedDur;
    var sayFn, countdownFn, showFn;
    var snapshotFn, setActiveStepFn, pushStepFn, absorbPendingIssueForFn;
    var requestPauseFn, waitIfPausedFn, submitIssueFn, resumeNoIssueFn;
    var setCurrentSourceRobustFn, setNextSourceRobustFn, forceSilentBaselineFn, preflightCleanupFn;
    var runRoutine;

    var beforeDict, afterDict;
    var activeStepId, activeStepTitle, activeStepExpected;
    var pedalboard;

    // ─────────────────────────────────────────────────────────────
    // 0) Preflight cleanup: stop Ndefs, clear any ProxySpaces, and
    //    re-initialize the default group safely (no s.freeAll).
    // ─────────────────────────────────────────────────────────────
    preflightCleanupFn = {
        "[QA] Preflight: checking for stray Ndefs and active ProxySpace…".postln;

        // Stop any Ndefs that might be playing, then clear them
        Ndef.all.keysValuesDo { |key, proxy|
            if(proxy.isPlaying) {
                ("[QA] Stopping stray Ndef: " ++ key).postln;
                proxy.stop;
            };
            proxy.clear;
        };

        // Clear all ProxySpaces known to SC (if exposed):
        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo { |srv, ps|
                if(ps.notNil) {
                    ("[QA] Clearing ProxySpace on " ++ srv).postln;
                    ps.clear; // frees ~proxies (e.g., ~tsDust, ~tremolo)
                };
            };
        };

        // If the current environment *is* a ProxySpace, pop it
        if(currentEnvironment.notNil and: { currentEnvironment.class.name == "ProxySpace" }) {
            "[QA] Active ProxySpace is current env → pop it.".postln;
            currentEnvironment.pop;
        } {
            "[QA] No active ProxySpace as current env.".postln;
        };

        // SAFELY reset the server tree: recreate Group 1 then free its children
        s.initTree;                // (re)create default group 1 under root
        s.defaultGroup.freeAll;    // keep group 1, remove its children
    };
    preflightCleanupFn.();

    // ─────────────────────────────────────────────────────────────
    // 1) Sources and processors (stereo; processors use \in)
    // ─────────────────────────────────────────────────────────────
    Ndef(\ts0,   { Silent.ar(2) });
    Ndef(\tsDust,{ Dust.ar(2000) ! 2 });
    Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });
    Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });

    Ndef(\tremolo, { |rate = 4, depth = 0.9|
        var inputSignal, mod;
        inputSignal = \in.ar(2);
        mod = SinOsc.kr(rate).range(1 - depth, 1);
        inputSignal * mod
    });

    Ndef(\lofi, { |bits = 4, rate = 4000|
        var inputSignal;
        inputSignal = \in.ar(2);
        Decimator.ar(inputSignal, rate, bits)
    });

    Ndef(\atten, { |gain = 0.25|
        var inputSignal;
        inputSignal = \in.ar(2) * gain;
        inputSignal
    });

    // ─────────────────────────────────────────────────────────────
    // 2) Instantiate + reset + HARD SILENT BASELINE
    // ─────────────────────────────────────────────────────────────
    pedalboard = MagicPedalboardNew.new;
    pedalboard.reset; // canonical baseline from the class

    // robust helpers for source setting
    setCurrentSourceRobustFn = { |key|
        if(pedalboard.respondsTo(\setSourceCurrent)) {
            pedalboard.setSourceCurrent(key);
        }{
            pedalboard.switchChain;
            if(pedalboard.respondsTo(\setSourceCurrent)) {
                pedalboard.setSourceCurrent(key);
            }{
                "[QA] ERROR: setSourceCurrent missing; cannot set current source.".warn;
            };
            pedalboard.switchChain;
        }
    };

    setNextSourceRobustFn = { |key|
        if(pedalboard.respondsTo(\setSource)) {
            pedalboard.setSource(key);
        }{
            pedalboard.switchChain;
            if(pedalboard.respondsTo(\setSourceCurrent)) {
                pedalboard.setSourceCurrent(key);
            }{
                "[QA] ERROR: missing setSource and setSourceCurrent; cannot set next source.".warn;
            };
            pedalboard.switchChain;
        }
    };

    // Guarantee silence and a canonical shape on both chains
    forceSilentBaselineFn = {
        "[QA] Force silent baseline…".postln;
        pedalboard.reset;                 // [\chainA,\ts0] + [\chainB,\ts0], plays A
        setCurrentSourceRobustFn.(\ts0);
        setNextSourceRobustFn.(\ts0);

        pedalboard.clearChain;            // clear NEXT
        pedalboard.switchChain;
        pedalboard.clearChain;            // clear previous CURRENT (now NEXT)
        pedalboard.switchChain;

        // ensure only current sink plays
        Ndef(\chainA).play(numChannels: 2);
        Ndef(\chainB).stop;

        "[QA] Baseline set. Expect: silence now.".postln;
    };
    forceSilentBaselineFn.();

    // ─────────────────────────────────────────────────────────────
    // 3) QA state (no GUI calls here)
    // ─────────────────────────────────────────────────────────────
    ~qa = (
        steps: Array.new,
        issues: Array.new,
        currentStep: nil,
        pendingIssues: IdentityDictionary.new,   // stepId -> (reason:, note:)
        pauseRequested: false,
        pauseCondition: Condition.new
    );

    snapshotFn = {
        (
            time: Main.elapsedTime,
            current: pedalboard.currentChain.copy,
            next: pedalboard.nextChain.copy,
            effCurrent: pedalboard.effectiveCurrent,
            effNext: pedalboard.effectiveNext,
            bypassCurrent: pedalboard.bypassKeysCurrent,
            bypassNext: pedalboard.bypassKeysNext
        )
    };

    setActiveStepFn = { |stepId, stepTitle, expectedText|
        activeStepId = stepId;
        activeStepTitle = stepTitle;
        activeStepExpected = expectedText;
        AppClock.sched(0, {
            infoText.string = "Step: % — %\nExpect: %".format(stepId, stepTitle, expectedText);
            qaWindow.name = "MPBNew QA – two-step issue capture";
            nil
        });
    };

    pushStepFn = { |stepId, stepTitle, expectedText, beforeSnap, afterSnap|
        var entry;
        entry = (
            id: stepId,
            title: stepTitle,
            expected: expectedText,
            before: beforeSnap,
            after: afterSnap,
            userFlagged: false,
            userReason: nil,
            userNote: nil
        );
        ~qa.steps = ~qa.steps.add(entry);
        ~qa.currentStep = entry;
        absorbPendingIssueForFn.(stepId, entry);
    };

    absorbPendingIssueForFn = { |stepId, entry|
        var pending;
        pending = ~qa.pendingIssues[stepId];
        if(pending.notNil) {
            entry[\userFlagged] = true;
            entry[\userReason] = pending[\reason];
            entry[\userNote] = pending[\note];
            if(~qa.issues.includes(stepId).not) { ~qa.issues = ~qa.issues.add(stepId) };
            ~qa.pendingIssues.removeAt(stepId);
        };
    };

    // ─────────────────────────────────────────────────────────────
    // 4) Pause / resume workflow (Routine on SystemClock; GUI on AppClock)
    // ─────────────────────────────────────────────────────────────
    requestPauseFn = {
        "[QA] pause requested".postln;
        ~qa.pauseRequested = true;
        AppClock.sched(0, {
            infoText.string = "PAUSED at % — %\nType your note, then Submit or Resume."
                .format(activeStepId ? "(unknown)", activeStepTitle ? "(unknown)");
            qaWindow.name = "MPBNew QA – PAUSED";
            reportButton.enabled = false;
            submitButton.enabled = true;
            resumeButton.enabled = true;
            nil
        });
    };

    waitIfPausedFn = {
        while { ~qa.pauseRequested } { ~qa.pauseCondition.wait };
    };

    submitIssueFn = {
        var noteText, reasonText, stepIdLocal;
        noteText = noteTextField.string;
        reasonText = "user report (paused)";
        stepIdLocal = activeStepId ? ("unknown-" ++ Main.elapsedTime.round(0.01));
        ~qa.pendingIssues[stepIdLocal] = (reason: reasonText, note: noteText);
        ("[QA] issue submitted for step %".format(stepIdLocal)).postln;
        if(noteText.notNil and: { noteText != "" }) { ("[QA] note: " ++ noteText).postln };

        ~qa.pauseRequested = false;
        ~qa.pauseCondition.signal;
        AppClock.sched(0, {
            infoText.string = "Captured issue for step %.\nResuming…".format(stepIdLocal);
            qaWindow.name = "MPBNew QA – two-step issue capture";
            reportButton.enabled = true;
            submitButton.enabled = false;
            resumeButton.enabled = false;
            nil
        });
    };

    resumeNoIssueFn = {
        "[QA] resume (no issue)".postln;
        ~qa.pauseRequested = false;
        ~qa.pauseCondition.signal;
        AppClock.sched(0, {
            infoText.string = "Resuming without logging an issue…";
            qaWindow.name = "MPBNew QA – two-step issue capture";
            reportButton.enabled = true;
            submitButton.enabled = false;
            resumeButton.enabled = false;
            nil
        });
    };

    // ─────────────────────────────────────────────────────────────
    // 5) Console helpers
    // ─────────────────────────────────────────────────────────────
    sayFn = { |text| text.asString.postln };

    countdownFn = { |seconds = 3|
        var remaining;
        remaining = seconds;
        while { remaining > 0 } {
            waitIfPausedFn.();
            (remaining.asString ++ "...").postln;
            1.wait; // SystemClock wait
            remaining = remaining - 1;
        };
        waitIfPausedFn.();
        "Now.".postln;
    };

    showFn = {
        "— Chains —".postln;
        pedalboard.printChains;
        "".postln;
    };

    // ─────────────────────────────────────────────────────────────
    // 6) QA UI (AppClock-safe GUI)
    // ─────────────────────────────────────────────────────────────
    qaWindow = Window("MPBNew QA – two-step issue capture", Rect(100, 100, 700, 220)).front.alwaysOnTop_(true);
    infoText = StaticText(qaWindow, Rect(10, 10, 680, 40)).string_("Step: (pending)");
    noteTextField = TextField(qaWindow, Rect(10, 60, 680, 24)).string_("Type your note here…");

    reportButton = Button(qaWindow, Rect(10, 100, 220, 30))
        .states_([["Report Issue (Pause)", Color.white, Color.red]])
        .action_({ requestPauseFn.() });

    submitButton = Button(qaWindow, Rect(240, 100, 220, 30))
        .states_([["Submit Issue & Resume", Color.white, Color(0, 0.5, 0)]])
        .action_({ submitIssueFn.() })
        .enabled_(false);

    resumeButton = Button(qaWindow, Rect(470, 100, 220, 30))
        .states_([["Resume (No Issue)", Color.white, Color.gray]])
        .action_({ resumeNoIssueFn.() })
        .enabled_(false);

    // keyboard shortcuts
    qaWindow.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
        if(char == $x or: { char == $X }) { requestPauseFn.() };
        if(keycode == 36 or: { keycode == 52 }) { submitIssueFn.() }; // Enter / keypad Enter
        if(keycode == 53) { resumeNoIssueFn.() };                      // Esc
    };

    // ─────────────────────────────────────────────────────────────
    // 7) Narrated sequence (RUN ON SystemClock)
    // ─────────────────────────────────────────────────────────────
    waitShortDur = 1.8;
    waitMedDur   = 3.0;

    runRoutine = Routine({

        // A) Start silent on CURRENT
        setActiveStepFn.("A1", "Start silent \\ts0 on CURRENT", "Silence");
        sayFn.("Starting with a silent CURRENT chain. Starting in");
        countdownFn.(3);
        beforeDict = snapshotFn.();
        setCurrentSourceRobustFn.(\ts0);
        pedalboard.playCurrent;
        showFn.();
        sayFn.("You should hear nothing.");
        waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
        afterDict = snapshotFn.();
        pushStepFn.("A1", "silent on CURRENT", "You should hear nothing.", beforeDict, afterDict);

        // … (keep your B/C/D/E/F/G steps unchanged) …

    }).play(SystemClock);
});
)

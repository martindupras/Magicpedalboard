// Test_MagicPedalboardNew_v0_11_QA_PauseResume_Fixed.scd
// MD 20250911-1225

(
var qaWindow, infoText, noteTextField, reportButton, submitButton, resumeButton, updateInfoFn;
var waitShortDur, waitMedDur;
var sayFn, countdownFn, showFn;
var snapshotFn, setActiveStepFn, pushStepFn, absorbPendingIssueForFn;
var requestPauseFn, waitIfPausedFn, submitIssueFn, resumeNoIssueFn;
var setCurrentSourceRobustFn, setNextSourceRobustFn, forceSilentBaselineFn;
var runRoutine;

var beforeDict, afterDict;
var activeStepId, activeStepTitle, activeStepExpected;
var pedalboard;

// ─────────────────────────────────────────────────────────────────
// 0) Sources and processors (stereo; processors use \in)
// ─────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────
// 1) Instantiate + reset + HARD SILENT BASELINE
// ─────────────────────────────────────────────────────────────────
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

// hard silent baseline: both chains => [sink, \ts0], both cleared, only current plays
forceSilentBaselineFn = {
    "[QA] Force silent baseline…".postln;
    pedalboard.reset;                 // resets to [\chainA,\ts0] / [\chainB,\ts0], plays A
    setCurrentSourceRobustFn.(\ts0);  // explicit, even if reset did it
    setNextSourceRobustFn.(\ts0);

    // clear NEXT, then switch/clear to clear CURRENT as well
    pedalboard.clearChain;            // clears NEXT to [sink, source]
    pedalboard.switchChain;
    pedalboard.clearChain;            // clears NEXT (which is previous CURRENT)
    pedalboard.switchChain;

    // make absolutely sure no test Ndefs are playing directly
    [\tsDust, \tsSaw, \tsSine, \tremolo, \lofi, \atten].do { |k|
        if(Ndef(k).isPlaying) { Ndef(k).stop }
    };

    // play current sink, stop next
    Ndef(\chainA).play(numChannels: 2);
    Ndef(\chainB).stop;

    "[QA] Baseline set. Expect: silence.".postln;
};
forceSilentBaselineFn.();

// ─────────────────────────────────────────────────────────────────
// 2) QA state (no GUI calls here)
// ─────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────
// 3) Pause / resume workflow (Routine on SystemClock; GUI on AppClock)
// ─────────────────────────────────────────────────────────────────
requestPauseFn = {
    "[QA] pause requested".postln;
    ~qa.pauseRequested = true;
    AppClock.sched(0, {
        infoText.string = "PAUSED at % — %\nType your note, then Submit or Resume."
            .format(activeStepId ? "(unknown)", activeStepTitle ? "(unknown)");
        qaWindow.name = "MPBNew QA – PAUSED";
        // enable submit/resume, disable report
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
        // after resume, re-enable report and disable submit/resume
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

// ─────────────────────────────────────────────────────────────────
// 4) Console helpers
// ─────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────
// 5) QA UI (AppClock-safe GUI)
// ─────────────────────────────────────────────────────────────────
qaWindow = Window("MPBNew QA – two-step issue capture", Rect(100, 100, 700, 220)).front.alwaysOnTop_(true);
infoText = StaticText(qaWindow, Rect(10, 10, 680, 40)).string_("Step: (pending)");
noteTextField = TextField(qaWindow, Rect(10, 60, 680, 24)).string_("Type your note here…");

// left: report (pause). middle: submit & resume. right: resume without logging.
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

// keyboard: X pauses, Enter submits, Esc resumes without logging
qaWindow.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    if(char == $x or: { char == $X }) { requestPauseFn.() };
    if(keycode == 36 or: { keycode == 52 }) { submitIssueFn.() }; // Enter / keypad Enter
    if(keycode == 53) { resumeNoIssueFn.() };                      // Esc
};

// ─────────────────────────────────────────────────────────────────
// 6) Narrated sequence (RUN ON SystemClock)
// ─────────────────────────────────────────────────────────────────
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

    // B) Change CURRENT source to Dust
    setActiveStepFn.("B1", "Change CURRENT source to Dust", "Irregular noise bursts (stereo)");
    sayFn.("Change CURRENT source to Dust(2000). Starting in");
    countdownFn.(3);
    beforeDict = snapshotFn.();
    setCurrentSourceRobustFn.(\tsDust);
    showFn.();
    sayFn.("You should hear irregular noise bursts in stereo.");
    waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("B1", "dust on CURRENT", "Irregular noise bursts", beforeDict, afterDict);

    // C) Prepare NEXT: Saw + Tremolo, then switch
    setActiveStepFn.("C1", "Prepare NEXT: Saw + Tremolo, then switch", "Saw with deep tremolo");
    sayFn.("Prepare NEXT: set source to Saw; add Tremolo just before the source.");
    sayFn.("Setting NEXT source to Saw in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    setNextSourceRobustFn.(\tsSaw);
    pedalboard.add(\tremolo);
    showFn.();
    sayFn.("Switch to NEXT (so Tremolo+Saw becomes CURRENT). Starting in");
    countdownFn.(3);
    pedalboard.switchChain;
    showFn.();
    sayFn.("You should hear a saw tone with strong amplitude modulation (tremolo).");
    waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("C1", "switch to Saw + Tremolo", "Saw with strong tremolo", beforeDict, afterDict);

    // D) Bypass tremolo on CURRENT, then un-bypass
    setActiveStepFn.("D1", "Bypass CURRENT tremolo", "Plain Saw (no tremolo)");
    sayFn.("Bypass CURRENT tremolo. Starting in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.bypassCurrent(\tremolo, true);
    showFn.();
    sayFn.("You should hear plain Saw (no tremolo).");
    waitIfPausedFn.(); waitShortDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("D1", "bypass tremolo", "Plain Saw", beforeDict, afterDict);

    setActiveStepFn.("D2", "Un-bypass CURRENT tremolo", "Saw with tremolo returns");
    sayFn.("Un-bypass CURRENT tremolo. Starting in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.bypassCurrent(\tremolo, false);
    showFn.();
    sayFn.("Tremolo should be back.");
    waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("D2", "un-bypass tremolo", "Saw with tremolo", beforeDict, afterDict);

    // E) Prepare NEXT: Atten + Lofi + Saw (swap), then switch
    setActiveStepFn.("E1", "Prepare NEXT: add Atten then Lofi; swap; then switch", "Saw with heavy attenuation + crushing");
    sayFn.("Prepare NEXT: add \\atten near sink (index 1) and \\lofi after it, then swap them.");
    sayFn.("Adding \\atten at index 1 in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.addAt(\atten, 1);
    showFn.();

    sayFn.("Adding \\lofi at index 2 in");
    countdownFn.(2);
    pedalboard.addAt(\lofi, 2);
    showFn.();

    sayFn.("Swap NEXT indices 1 and 2 in");
    countdownFn.(2);
    pedalboard.swap(1, 2);
    showFn.();
    sayFn.("Switch to NEXT so Atten+Lofi+Saw becomes CURRENT. Starting in");
    countdownFn.(3);
    pedalboard.switchChain;
    showFn.();
    sayFn.("You should hear Saw with lower level and obvious bitcrush/decimation.");
    waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("E1", "switch to Atten+Lofi+Saw", "Quiet + crushed Saw", beforeDict, afterDict);

    // F) On NEXT: remove index 1, then clear
    setActiveStepFn.("F1", "On NEXT: remove index 1, then clear", "NEXT ends as [sink, source]");
    sayFn.("On NEXT, remove the processor at index 1 (nearest the sink), then clear.");
    sayFn.("Removing at index 1 on NEXT in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.removeAt(1);
    showFn.();

    sayFn.("Clear NEXT back to [sink, source] in");
    countdownFn.(2);
    pedalboard.clearChain;
    showFn.();
    waitIfPausedFn.(); waitShortDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("F1", "remove + clear NEXT", "[sink, source]", beforeDict, afterDict);

    // G) NEXT source to Sine, then switch
    setActiveStepFn.("G1", "Set NEXT source to Sine, then switch", "Steady sine tone");
    sayFn.("Set NEXT source to Sine and then switch.");
    sayFn.("Starting in");
    countdownFn.(3);
    beforeDict = snapshotFn.();
    setNextSourceRobustFn.(\tsSine);
    pedalboard.switchChain;
    showFn.();
    sayFn.("You should now hear a steady sine tone.");
    waitIfPausedFn.(); waitMedDur.wait; waitIfPausedFn.();
    afterDict = snapshotFn.();
    pushStepFn.("G1", "switch to Sine", "Steady sine tone", beforeDict, afterDict);

    // Wrap up
    setActiveStepFn.("Z", "Demo complete", "Nothing playing after stop");
    sayFn.("Demo complete. Stopping current chain in");
    countdownFn.(3);
    pedalboard.stopCurrent;

    // Summary
    {
        var summaryStr;

        "========== MagicPedalboardNew QA Summary ==========".postln;
        ("Class " ++ MagicPedalboardNew.version).postln;
        ("Steps run: " ++ ~qa.steps.size).postln;
        if(~qa.issues.size == 0 and: { ~qa.pendingIssues.size == 0 }) {
            "No issues were flagged. 🎉".postln;
        }{
            ("% issues flagged (submitted during run):".format(~qa.issues.size)).postln;
            ~qa.steps.do { |st|
                if(st[\userFlagged] == true) {
                    (st[\id] ++ " — " ++ st[\title]).postln;
                    ("Expected: " ++ st[\expected]).postln;
                    ("Before: current=" ++ st[\before].current ++ " next=" ++ st[\before].next).postln;
                    ("After : current=" ++ st[\after].current ++ " next=" ++ st[\after].next).postln;
                    ("Bypass(Current/Next): " ++ st[\after].bypassCurrent ++ " / " ++ st[\after].bypassNext).postln;
                    if(st[\userNote].notNil and: { st[\userNote] != "" }) {
                        ("Note: " ++ st[\userNote]).postln;
                    };
                    "".postln;
                };
            };
            if(~qa.pendingIssues.size > 0) {
                "Pending issues captured before step completion:".postln;
                ~qa.pendingIssues.keysValuesDo { |sid, rec|
                    (sid ++ "  (no step snapshot available yet)").postln;
                    ("Note: " ++ rec[\note]).postln;
                };
            };
        };

        summaryStr = String.streamContents { |str|
            str << "========== MagicPedalboardNew QA Summary ==========" << Char.nl;
            str << ("Class " ++ MagicPedalboardNew.version) << Char.nl;
            str << ("Steps run: " ++ ~qa.steps.size) << Char.nl;
            if(~qa.issues.size == 0 and: { ~qa.pendingIssues.size == 0 }) {
                str << "No issues were flagged." << Char.nl;
            }{
                str << ("% issues flagged:".format(~qa.issues.size)) << Char.nl;
                ~qa.steps.do { |st|
                    if(st[\userFlagged] == true) {
                        str << (st[\id] ++ " — " ++ st[\title]) << Char.nl;
                        str << ("Expected: " ++ st[\expected]) << Char.nl;
                        str << ("Before: current=" ++ st[\before].current ++ " next=" ++ st[\before].next) << Char.nl;
                        str << ("After : current=" ++ st[\after].current ++ " next=" ++ st[\after].next) << Char.nl;
                        str << ("Bypass(Current/Next): " ++ st[\after].bypassCurrent
                            ++ " / " ++ st[\after].bypassNext) << Char.nl;
                        if(st[\userNote].notNil and: { st[\userNote] != "" }) {
                            str << ("Note: " ++ st[\userNote]) << Char.nl;
                        };
                        str << Char.nl;
                    };
                };
                if(~qa.pendingIssues.size > 0) {
                    str << "Pending issues captured before step completion:" << Char.nl;
                    ~qa.pendingIssues.keysValuesDo { |sid, rec|
                        str << sid << "  (no step snapshot available yet)" << Char.nl;
                        str << ("Note: " ++ rec[\note]) << Char.nl;
                    };
                };
            };
        };

        if(GUI.respondsTo(\setClipboard)) {
            GUI.setClipboard(summaryStr);
            "Summary copied to clipboard.".postln;
        };
    }.value;

}).play(SystemClock); // Routine on SystemClock
)

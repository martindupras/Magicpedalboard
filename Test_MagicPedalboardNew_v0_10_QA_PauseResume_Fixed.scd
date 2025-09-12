/* Test_MagicPedalboardNew_v0_10_QA_PauseResume_Fixed.scd
   Interactive QA demo for MagicPedalboardNew v0.1.5
   - Two-step issue capture:
       [Report Issue (Pause)] -> type note -> [Submit Issue & Resume]  (or [Resume (No Issue)])
   - Routine runs on SystemClock; GUI updates are deferred to AppClock.
   - Robust against missing setSource / setSourceCurrent (uses fallbacks).
*/

(
var qaWindow, infoText, noteTextField, reportButton, submitButton, resumeButton, updateInfoFn;
var waitShortDur, waitMedDur;
var sayFn, countdownFn, showFn;
var snapshotFn, setActiveStepFn, pushStepFn, absorbPendingIssueForFn;
var requestPauseFn, waitIfPausedFn, submitIssueFn, resumeNoIssueFn;
var setCurrentSourceRobustFn, setNextSourceRobustFn;
var runRoutine;

var beforeDict, afterDict;     // used within the Routine
var activeStepId, activeStepTitle, activeStepExpected;

var pedalboard;

// ─────────────────────────────────────────────────────────────────
// 0) Sources and processors (stereo; processors use \in)
// ─────────────────────────────────────────────────────────────────
Ndef(\ts0,   { Silent.ar(2) });                      // silent baseline
Ndef(\tsDust,{ Dust.ar(2000) ! 2 });                 // irregular bursts
Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });             // bright saw
Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });       // steady sine

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
// 1) Instantiate + reset
// ─────────────────────────────────────────────────────────────────
pedalboard = MagicPedalboardNew.new;
pedalboard.reset; // canonical baseline

// Robust helpers for source setting (handle older class versions)
setCurrentSourceRobustFn = { |key|
    var hasSetter;
    hasSetter = pedalboard.respondsTo(\setSourceCurrent);
    if(hasSetter) {
        pedalboard.setSourceCurrent(key);
    }{
        // fallback: temporarily switch, set NEXT as current, switch back
        pedalboard.switchChain;
        if(pedalboard.respondsTo(\setSourceCurrent)) {
            pedalboard.setSourceCurrent(key);
        }{
            "ERROR: setSourceCurrent missing; cannot set current source.".warn;
        };
        pedalboard.switchChain;
    }
};

setNextSourceRobustFn = { |key|
    var hasSetter;
    hasSetter = pedalboard.respondsTo(\setSource);
    if(hasSetter) {
        pedalboard.setSource(key);
    }{
        // fallback: temporarily switch to make NEXT current, set current, switch back
        pedalboard.switchChain;
        if(pedalboard.respondsTo(\setSourceCurrent)) {
            pedalboard.setSourceCurrent(key);
        }{
            "ERROR: missing setSource and setSourceCurrent; cannot set next source.".warn;
        };
        pedalboard.switchChain;
    }
};

// ─────────────────────────────────────────────────────────────────
// 2) QA state (no GUI calls here)
// ─────────────────────────────────────────────────────────────────
~qa = (
    steps: Array.new,
    issues: Array.new,
    currentStep: nil,                  // after a step is pushed, points to that entry
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
        if(~qa.issues.includes(stepId).not) {
            ~qa.issues = ~qa.issues.add(stepId);
        };
        ~qa.pendingIssues.removeAt(stepId);
    };
};

// ─────────────────────────────────────────────────────────────────
// 3) Pause / resume workflow
// ─────────────────────────────────────────────────────────────────
requestPauseFn = {
    ~qa.pauseRequested = true;
    AppClock.sched(0, {
        infoText.string = "PAUSED at % — %\nType your note, then Submit or Resume."
            .format(activeStepId ? "(unknown)", activeStepTitle ? "(unknown)");
        qaWindow.name = "MPBNew QA – PAUSED";
        nil
    });
};

waitIfPausedFn = {
    // This is called inside the Routine (on SystemClock now).
    while { ~qa.pauseRequested } {
        ~qa.pauseCondition.wait; // signal comes from AppClock handlers (buttons/keys)
    };
};

submitIssueFn = {
    var noteText, reasonText, stepIdLocal;
    noteText = noteTextField.string;
    reasonText = "user report (paused)";
    stepIdLocal = activeStepId ? ("unknown-" ++ Main.elapsedTime.round(0.01));

    ~qa.pendingIssues[stepIdLocal] = (reason: reasonText, note: noteText);

    ("[QA] Issue captured for step %".format(stepIdLocal)).postln;
    if(noteText.notNil and: { noteText != "" }) { ("[QA] Note: " ++ noteText).postln };

    ~qa.pauseRequested = false;
    ~qa.pauseCondition.signal;

    AppClock.sched(0, {
        infoText.string = "Captured issue for step %.\nResuming…".format(stepIdLocal);
        qaWindow.name = "MPBNew QA – two-step issue capture";
        nil
    });
};

resumeNoIssueFn = {
    ~qa.pauseRequested = false;
    ~qa.pauseCondition.signal;

    AppClock.sched(0, {
        infoText.string = "Resuming without logging an issue…";
        qaWindow.name = "MPBNew QA – two-step issue capture";
        nil
    });
};

// ─────────────────────────────────────────────────────────────────
// 4) Console helpers
// ─────────────────────────────────────────────────────────────────
sayFn = { |text|
    var msg;
    msg = text.asString;
    msg.postln;
};

countdownFn = { |seconds = 3|
    var remaining;
    remaining = seconds;
    while { remaining > 0 } {
        waitIfPausedFn.();             // allow pausing mid-countdown
        (remaining.asString ++ "...").postln;
        1.wait;                        // SystemClock wait
        remaining = remaining - 1;
    };
    waitIfPausedFn.();                 // pause again before executing the action
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
qaWindow = Window("MPBNew QA – two-step issue capture", Rect(100, 100, 640, 210)).front.alwaysOnTop_(true);
infoText = StaticText(qaWindow, Rect(10, 10, 620, 40)).string_("Step: (pending)");
noteTextField = TextField(qaWindow, Rect(10, 60, 620, 24)).string_("Type your note here…");

// left: report (pause). middle: submit & resume. right: resume without logging.
reportButton = Button(qaWindow, Rect(10, 100, 200, 30))
    .states_([["Report Issue (Pause)", Color.white, Color.red]])
    .action_({ requestPauseFn.() });

submitButton = Button(qaWindow, Rect(220, 100, 200, 30))
    .states_([["Submit Issue & Resume", Color.white, Color(0, 0.5, 0)]])
    .action_({ submitIssueFn.() });

resumeButton = Button(qaWindow, Rect(430, 100, 200, 30))
    .states_([["Resume (No Issue)", Color.white, Color.gray]])
    .action_({ resumeNoIssueFn.() });

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
    setActiveStepFn.("A1", "Start silent \\\\ts0 on CURRENT", "Silence");
    sayFn.("Starting with a silent CURRENT chain: [\\chainA, \\ts0]. Starting in");
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
    pedalboard.add(\tremolo);     // inserts before source
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

    // Summary (build + copy to clipboard)
    {
        var summaryStr;

        "========== MagicPedalboardNew QA Summary ==========".postln;
        ("Class " ++ MagicPedalboardNew.version).postln;
        ("Steps run: " ++ ~qa.steps.size).postln;
        if(~qa.issues.size == 0 and: { ~qa.pendingIssues.size == 0 }) {
            "No issues were flagged. 🎉".postln;
        }{
            ("% issues flagged (submitted during run):".format(~qa.issues.size)).postln;
            ~qa.steps.do { |stepEntry|
                if(stepEntry[\userFlagged] == true) {
                    (stepEntry[\id] ++ " — " ++ stepEntry[\title]).postln;
                    ("Expected: " ++ stepEntry[\expected]).postln;
                    ("Before: current=" ++ stepEntry[\before].current ++ " next=" ++ stepEntry[\before].next).postln;
                    ("After : current=" ++ stepEntry[\after].current ++ " next=" ++ stepEntry[\after].next).postln;
                    ("Bypass(Current/Next): " ++ stepEntry[\after].bypassCurrent ++ " / " ++ stepEntry[\after].bypassNext).postln;
                    if(stepEntry[\userNote].notNil and: { stepEntry[\userNote] != "" }) {
                        ("Note: " ++ stepEntry[\userNote]).postln;
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
                ~qa.steps.do { |stepEntry|
                    if(stepEntry[\userFlagged] == true) {
                        str << (stepEntry[\id] ++ " — " ++ stepEntry[\title]) << Char.nl;
                        str << ("Expected: " ++ stepEntry[\expected]) << Char.nl;
                        str << ("Before: current=" ++ stepEntry[\before].current ++ " next=" ++ stepEntry[\before].next) << Char.nl;
                        str << ("After : current=" ++ stepEntry[\after].current ++ " next=" ++ stepEntry[\after].next) << Char.nl;
                        str << ("Bypass(Current/Next): " ++ stepEntry[\after].bypassCurrent ++ " / " ++ stepEntry[\after].bypassNext) << Char.nl;
                        if(stepEntry[\userNote].notNil and: { stepEntry[\userNote] != "" }) {
                            str << ("Note: " ++ stepEntry[\userNote]) << Char.nl;
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

}).play(SystemClock);   // <<< IMPORTANT: run on SystemClock (not AppClock)
)

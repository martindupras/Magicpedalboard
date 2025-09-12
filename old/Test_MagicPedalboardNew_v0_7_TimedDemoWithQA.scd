/* Test_MagicPedalboardNew_v0_7_TimedDemoWithQA.scd
   Comprehensive, narrated demo with interactive QA for MagicPedalboardNew v0.1.5.

   HOW TO USE:
   - Keep the QA window focused. When narration says what you SHOULD hear,
     press 'X' (or click the red Mark Issue button) if you DON'T hear that.
   - You can add an optional note in the text field before marking the issue.
   - At the end, a diagnostic summary is printed (and copied to clipboard if supported).
*/

(
var qaWindow, infoText, noteTextField, markIssueButton, updateInfoFn;
var waitShortDur, waitMedDur, beforeSnapshot, afterSnapshot;
var sayFn, countdownFn, showFn, pushStepFn, markIssueFn, snapshotFn, runRoutine;
var pedalboard;

// ─────────────────────────────────────────────────────────────────
// 0) Sources and processors (stereo; processors use \in)
// ─────────────────────────────────────────────────────────────────
Ndef(\ts0,   { Silent.ar(2) });                      // silent (baseline)
Ndef(\tsDust,{ Dust.ar(2000) ! 2 });                 // noisy bursts
Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });             // bright saw
Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });       // steady sine

// processors (clear audible effect choices)
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
// 1) Instantiate and reset pedalboard
// ─────────────────────────────────────────────────────────────────
pedalboard = MagicPedalboardNew.new;
pedalboard.reset; // clean start every time

// helper: set current source, with fallback if method is absent
~setCurrentSource = { |key|
    if(pedalboard.respondsTo(\setSourceCurrent)) {
        pedalboard.setSourceCurrent(key);
    }{
        // fallback: switch to NEXT, set its source, switch back
        pedalboard.switchChain;
        pedalboard.setSource(key);
        pedalboard.switchChain;
    }
};

// ─────────────────────────────────────────────────────────────────
// 2) QA data + helpers (no GUI calls here)
// ─────────────────────────────────────────────────────────────────
~qa = (steps: Array.new, issues: Array.new, currentStep: nil);

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

pushStepFn = { |stepId, stepTitle, expectedText, beforeDict, afterDict|
    var entry;
    entry = (
        id: stepId,
        title: stepTitle,
        expected: expectedText,
        before: beforeDict,
        after: afterDict,
        userFlagged: false,
        userReason: nil,
        userNote: nil
    );
    ~qa.steps = ~qa.steps.add(entry);
    ~qa.currentStep = entry;
};

markIssueFn = { |reason = "user pressed X"|
    var stepEntry;
    stepEntry = ~qa.currentStep;
    if(stepEntry.notNil) {
        stepEntry.userFlagged = true;
        stepEntry.userReason = reason;
        stepEntry.userNote = noteTextField.string;
        if(~qa.issues.includes(stepEntry.id).not) {
            ~qa.issues = ~qa.issues.add(stepEntry.id);
        };
        ("[QA] Issue marked at step %: %".format(stepEntry.id, reason)).postln;
        if(stepEntry.userNote.notNil and: { stepEntry.userNote != "" }) {
            ("[QA] Note: " ++ stepEntry.userNote).postln;
        };
    }{
        "[QA] No active step to mark yet.".postln;
    };
};

sayFn = { |text| text.asString.postln; };

countdownFn = { |seconds = 3|
    var remaining;
    remaining = seconds;
    while { remaining > 0 } {
        (remaining.asString ++ "...").postln;
        1.wait;
        remaining = remaining - 1;
    };
    "Now.".postln;
};

showFn = {
    "— Chains —".postln;
    pedalboard.printChains;
    "".postln;
};

// ─────────────────────────────────────────────────────────────────
// 3) QA UI (GUI must run on AppClock; we also defer updates)
// ─────────────────────────────────────────────────────────────────
qaWindow = Window("MPBNew QA – press X to mark issue", Rect(100, 100, 520, 180)).front.alwaysOnTop_(true);
infoText = StaticText(qaWindow, Rect(10, 10, 500, 40)).string_("Step: (pending)");
noteTextField = TextField(qaWindow, Rect(10, 60, 500, 24)).string_("Optional note about mismatch…");
markIssueButton = Button(qaWindow, Rect(10, 100, 200, 30))
    .states_([["Mark Issue (X)", Color.white, Color.red]])
    .action_({ markIssueFn.("button") });

qaWindow.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    if(char == $x or: { char == $X }) { markIssueFn.("key") };
};

updateInfoFn = { |stepId, stepTitle, expectedText|
    AppClock.sched(0, {
        infoText.string = "Step: % — %\nExpect: %".format(stepId, stepTitle, expectedText);
        nil
    });
};

// ─────────────────────────────────────────────────────────────────
// 4) The narrated, interactive sequence (RUN ON AppClock)
// ─────────────────────────────────────────────────────────────────
waitShortDur = 1.8;
waitMedDur   = 3.0;

runRoutine = Routine({
    var beforeDict, afterDict;

    // A) Start silent on current (A)
    updateInfoFn.("A1", "Start silent \\\\ts0 on CURRENT", "Silence");
    sayFn.("Starting with a silent CURRENT chain: [\\chainA, \\ts0]. Starting in");
    countdownFn.(3);
    beforeDict = snapshotFn.();
    ~setCurrentSource.(\ts0);
    pedalboard.playCurrent;
    showFn.();
    sayFn.("You should hear nothing.");
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("A1", "silent on CURRENT", "You should hear nothing.", beforeDict, afterDict);

    // B) Change CURRENT source to Dust
    updateInfoFn.("B1", "Change CURRENT source to Dust", "Irregular noise bursts (stereo)");
    sayFn.("Change CURRENT source to Dust(2000). Starting in");
    countdownFn.(3);
    beforeDict = snapshotFn.();
    ~setCurrentSource.(\tsDust);
    showFn.();
    sayFn.("You should hear irregular noise bursts in stereo.");
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("B1", "dust on CURRENT", "Irregular noise bursts", beforeDict, afterDict);

    // C) Prepare NEXT with Saw + Tremolo, then switch
    updateInfoFn.("C1", "Prepare NEXT: Saw + Tremolo, then switch", "Saw with deep tremolo");
    sayFn.("Prepare NEXT: set source to Saw; add Tremolo just before the source.");
    sayFn.("Setting NEXT source to Saw in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.setSource(\tsSaw);
    pedalboard.add(\tremolo);     // inserts before source
    showFn.();
    sayFn.("Switch to NEXT (so Tremolo+Saw becomes CURRENT). Starting in");
    countdownFn.(3);
    pedalboard.switchChain;
    showFn.();
    sayFn.("You should hear a saw tone with strong amplitude modulation (tremolo).");
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("C1", "switch to Saw + Tremolo", "Saw with strong tremolo", beforeDict, afterDict);

    // D) Bypass tremolo on CURRENT, then un-bypass
    updateInfoFn.("D1", "Bypass CURRENT tremolo", "Plain Saw (no tremolo)");
    sayFn.("Bypass CURRENT tremolo. Starting in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.bypassCurrent(\tremolo, true);
    showFn.();
    sayFn.("You should hear plain Saw (no tremolo).");
    waitShortDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("D1", "bypass tremolo", "Plain Saw", beforeDict, afterDict);

    updateInfoFn.("D2", "Un-bypass CURRENT tremolo", "Saw with tremolo returns");
    sayFn.("Un-bypass CURRENT tremolo. Starting in");
    countdownFn.(2);
    beforeDict = snapshotFn.();
    pedalboard.bypassCurrent(\tremolo, false);
    showFn.();
    sayFn.("Tremolo should be back.");
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("D2", "un-bypass tremolo", "Saw with tremolo", beforeDict, afterDict);

    // E) Prepare NEXT: Atten + Lofi + Saw (swap order), then switch
    updateInfoFn.("E1", "Prepare NEXT: add Atten then Lofi; swap; then switch", "Saw with heavy attenuation + crushing");
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
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("E1", "switch to Atten+Lofi+Saw", "Quiet + crushed Saw", beforeDict, afterDict);

    // F) Remove a processor on NEXT and clear
    updateInfoFn.("F1", "On NEXT: remove index 1, then clear", "NEXT ends as [sink, source]");
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
    waitShortDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("F1", "remove + clear NEXT", "[sink, source]", beforeDict, afterDict);

    // G) Change NEXT source to Sine and switch
    updateInfoFn.("G1", "Set NEXT source to Sine, then switch", "Steady sine tone");
    sayFn.("Set NEXT source to Sine and then switch.");
    sayFn.("Starting in");
    countdownFn.(3);
    beforeDict = snapshotFn.();
    pedalboard.setSource(\tsSine);
    pedalboard.switchChain;
    showFn.();
    sayFn.("You should now hear a steady sine tone.");
    waitMedDur.wait;
    afterDict = snapshotFn.();
    pushStepFn.("G1", "switch to Sine", "Steady sine tone", beforeDict, afterDict);

    // Wrap up
    updateInfoFn.("Z", "Demo complete", "Nothing playing after stop");
    sayFn.("Demo complete. Stopping current chain in");
    countdownFn.(3);
    pedalboard.stopCurrent;

    // Summary
    {
        var summaryStr;

        "========== MagicPedalboardNew QA Summary ==========".postln;
        ("Class " ++ MagicPedalboardNew.version).postln;
        ("Steps run: " ++ ~qa.steps.size).postln;
        if(~qa.issues.size == 0) {
            "No issues were flagged. 🎉".postln;
        }{
            ("% issues flagged:".format(~qa.issues.size)).postln;
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
        };

        summaryStr = String.streamContents { |str|
            str << "========== MagicPedalboardNew QA Summary ==========" << Char.nl;
            str << ("Class " ++ MagicPedalboardNew.version) << Char.nl;
            str << ("Steps run: " ++ ~qa.steps.size) << Char.nl;
            if(~qa.issues.size == 0) {
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
            };
        };

        if(GUI.respondsTo(\setClipboard)) {
            GUI.setClipboard(summaryStr);
            "Summary copied to clipboard.".postln;
        };
    }.value;

}).play(AppClock);   // <<< Run the Routine on AppClock
)

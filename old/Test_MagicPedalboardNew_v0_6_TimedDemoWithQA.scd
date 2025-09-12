/* Test_MagicPedalboardNew_v0_6_TimedDemoWithQA.scd
   Comprehensive, narrated demo with interactive QA for MagicPedalboardNew v0.1.5.

   HOW TO USE:
   - Keep the QA window focused. When narration says what you SHOULD hear,
     press 'X' (or click the red Mark Issue button) if you DON'T hear that.
   - You can add an optional note in the text field before marking the issue.
   - At the end, a diagnostic summary is printed (and copied to clipboard if supported).
*/

(
var w, infoView, noteField, markButton, updateInfo;
var waitShort, waitMed, beforeSnap, afterSnap;
var say, countdown, show, pushStep, markIssue, snap, run;

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
/* 1) Instantiate and reset pedalboard */
// ─────────────────────────────────────────────────────────────────
m = MagicPedalboardNew.new;
m.reset; // clean start every time

// ─────────────────────────────────────────────────────────────────
/* 2) QA data + helpers (no GUI calls here) */
// ─────────────────────────────────────────────────────────────────
~qa = (steps: Array.new, issues: Array.new, currentStep: nil);

snap = {
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

pushStep = { |id, title, expected, beforeDict, afterDict|
    var entry;
    entry = (
        id: id,
        title: title,
        expected: expected,
        before: beforeDict,
        after: afterDict,
        userFlagged: false,
        userReason: nil,
        userNote: nil
    );
    ~qa.steps = ~qa.steps.add(entry);
    ~qa.currentStep = entry;
};

markIssue = { |reason = "user pressed X"|
    var step;
    step = ~qa.currentStep;
    if(step.notNil) {
        step.userFlagged = true;
        step.userReason = reason;
        step.userNote = noteField.string;
        if(~qa.issues.includes(step.id).not) {
            ~qa.issues = ~qa.issues.add(step.id);
        };
        ("[QA] Issue marked at step %: %".format(step.id, reason)).postln;
        if(step.userNote.notNil and: { step.userNote != "" }) {
            ("[QA] Note: " ++ step.userNote).postln;
        };
    }{
        "[QA] No active step to mark yet.".postln;
    };
};

say = { |text| text.asString.postln; };

countdown = { |seconds = 3|
    var remaining;
    remaining = seconds;
    while { remaining > 0 } {
        (remaining.asString ++ "...").postln;
        1.wait;
        remaining = remaining - 1;
    };
    "Now.".postln;
};

show = {
    "— Chains —".postln;
    m.printChains;
    "".postln;
};

// ─────────────────────────────────────────────────────────────────
/* 3) QA UI (GUI must run on AppClock; we also defer updates) */
// ─────────────────────────────────────────────────────────────────
w = Window("MPBNew QA – press X to mark issue", Rect(100, 100, 520, 180)).front.alwaysOnTop_(true);
infoView = StaticText(w, Rect(10, 10, 500, 40)).string_("Step: (pending)");
noteField = TextField(w, Rect(10, 60, 500, 24)).string_("Optional note about mismatch…");
markButton = Button(w, Rect(10, 100, 200, 30))
    .states_([["Mark Issue (X)", Color.white, Color.red]])
    .action_({ markIssue.("button") });

w.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    if(char == $x or: { char == $X }) { markIssue.("key") };
};

updateInfo = { |id, title, expected|
    AppClock.sched(0, {
        infoView.string = "Step: % — %\nExpect: %".format(id, title, expected);
        nil
    });
};

// ─────────────────────────────────────────────────────────────────
/* 4) The narrated, interactive sequence (RUN ON AppClock) */
// ─────────────────────────────────────────────────────────────────
waitShort = 1.8;
waitMed   = 3.0;

run = Routine({
    var beforeDict, afterDict;

    // A) Start silent on current (A)
    updateInfo.("A1", "Start silent \\\\ts0 on CURRENT", "Silence");
    say.("Starting with a silent CURRENT chain: [\\chainA, \\ts0]. Starting in");
    countdown.(3);
    beforeDict = snap.();
    m.setSourceCurrent(\ts0);
    m.playCurrent;
    show.();
    say.("You should hear nothing.");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("A1", "silent on CURRENT", "You should hear nothing.", beforeDict, afterDict);

    // B) Change CURRENT source to Dust
    updateInfo.("B1", "Change CURRENT source to Dust", "Irregular noise bursts (stereo)");
    say.("Change CURRENT source to Dust(2000). Starting in");
    countdown.(3);
    beforeDict = snap.();
    m.setSourceCurrent(\tsDust);
    show.();
    say.("You should hear irregular noise bursts in stereo.");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("B1", "dust on CURRENT", "Irregular noise bursts", beforeDict, afterDict);

    // C) Prepare NEXT with Saw + Tremolo, then switch
    updateInfo.("C1", "Prepare NEXT: Saw + Tremolo, then switch", "Saw with deep tremolo");
    say.("Prepare NEXT: set source to Saw; add Tremolo just before the source.");
    say.("Setting NEXT source to Saw in");
    countdown.(2);
    beforeDict = snap.();
    m.setSource(\tsSaw);
    m.add(\tremolo);     // inserts before source
    show.();
    say.("Switch to NEXT (so Tremolo+Saw becomes CURRENT). Starting in");
    countdown.(3);
    m.switchChain;
    show.();
    say.("You should hear a saw tone with strong amplitude modulation (tremolo).");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("C1", "switch to Saw + Tremolo", "Saw with strong tremolo", beforeDict, afterDict);

    // D) Bypass tremolo on CURRENT, then un-bypass
    updateInfo.("D1", "Bypass CURRENT tremolo", "Plain Saw (no tremolo)");
    say.("Bypass CURRENT tremolo. Starting in");
    countdown.(2);
    beforeDict = snap.();
    m.bypassCurrent(\tremolo, true);
    show.();
    say.("You should hear plain Saw (no tremolo).");
    waitShort.wait;
    afterDict = snap.();
    pushStep.("D1", "bypass tremolo", "Plain Saw", beforeDict, afterDict);

    updateInfo.("D2", "Un-bypass CURRENT tremolo", "Saw with tremolo returns");
    say.("Un-bypass CURRENT tremolo. Starting in");
    countdown.(2);
    beforeDict = snap.();
    m.bypassCurrent(\tremolo, false);
    show.();
    say.("Tremolo should be back.");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("D2", "un-bypass tremolo", "Saw with tremolo", beforeDict, afterDict);

    // E) Prepare NEXT: Atten + Lofi + Saw (swap order), then switch
    updateInfo.("E1", "Prepare NEXT: add Atten then Lofi; swap; then switch", "Saw with heavy attenuation + crushing");
    say.("Prepare NEXT: add \\atten near sink (index 1) and \\lofi after it, then swap them.");
    say.("Adding \\atten at index 1 in");
    countdown.(2);
    beforeDict = snap.();
    m.addAt(\atten, 1);
    show.();

    say.("Adding \\lofi at index 2 in");
    countdown.(2);
    m.addAt(\lofi, 2);
    show.();

    say.("Swap NEXT indices 1 and 2 in");
    countdown.(2);
    m.swap(1, 2);
    show.();
    say.("Switch to NEXT so Atten+Lofi+Saw becomes CURRENT. Starting in");
    countdown.(3);
    m.switchChain;
    show.();
    say.("You should hear Saw with lower level and obvious bitcrush/decimation.");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("E1", "switch to Atten+Lofi+Saw", "Quiet + crushed Saw", beforeDict, afterDict);

    // F) Remove a processor on NEXT and clear
    updateInfo.("F1", "On NEXT: remove index 1, then clear", "NEXT ends as [sink, source]");
    say.("On NEXT, remove the processor at index 1 (nearest the sink), then clear.");
    say.("Removing at index 1 on NEXT in");
    countdown.(2);
    beforeDict = snap.();
    m.removeAt(1);
    show.();

    say.("Clear NEXT back to [sink, source] in");
    countdown.(2);
    m.clearChain;
    show.();
    waitShort.wait;
    afterDict = snap.();
    pushStep.("F1", "remove + clear NEXT", "[sink, source]", beforeDict, afterDict);

    // G) Change NEXT source to Sine and switch
    updateInfo.("G1", "Set NEXT source to Sine, then switch", "Steady sine tone");
    say.("Set NEXT source to Sine and then switch.");
    say.("Starting in");
    countdown.(3);
    beforeDict = snap.();
    m.setSource(\tsSine);
    m.switchChain;
    show.();
    say.("You should now hear a steady sine tone.");
    waitMed.wait;
    afterDict = snap.();
    pushStep.("G1", "switch to Sine", "Steady sine tone", beforeDict, afterDict);

    // Wrap up
    updateInfo.("Z", "Demo complete", "Nothing playing after stop");
    say.("Demo complete. Stopping current chain in");
    countdown.(3);
    m.stopCurrent;

    // Summary (on AppClock already; safe for GUI clipboard)
    {
        var summaryStr;

        "========== MagicPedalboardNew QA Summary ==========".postln;
        ("Class " ++ MagicPedalboardNew.version).postln;
        ("Steps run: " ++ ~qa.steps.size).postln;
        if(~qa.issues.size == 0) {
            "No issues were flagged. 🎉".postln;
        }{
            ("% issues flagged:".format(~qa.issues.size)).postln;
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
        };

        summaryStr = String.streamContents { |str|
            str << "========== MagicPedalboardNew QA Summary ==========" << Char.nl;
            str << ("Class " ++ MagicPedalboardNew.version) << Char.nl;
            str << ("Steps run: " ++ ~qa.steps.size) << Char.nl;
            if(~qa.issues.size == 0) {
                str << "No issues were flagged." << Char.nl;
            }{
                str << ("% issues flagged:".format(~qa.issues.size)) << Char.nl;
                ~qa.steps.do { |st|
                    if(st[\userFlagged] == true) {
                        str << (st[\id] ++ " — " ++ st[\title]) << Char.nl;
                        str << ("Expected: " ++ st[\expected]) << Char.nl;
                        str << ("Before: current=" ++ st[\before].current ++ " next=" ++ st[\before].next) << Char.nl;
                        str << ("After : current=" ++ st[\after].current ++ " next=" ++ st[\after].next) << Char.nl;
                        str << ("Bypass(Current/Next): " ++ st[\after].bypassCurrent ++ " / " ++ st[\after].bypassNext) << Char.nl;
                        if(st[\userNote].notNil and: { st[\userNote] != "" }) {
                            str << ("Note: " ++ st[\userNote]) << Char.nl;
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

/*  MPB_Scenarios_v6.scd
    Scenarios for MagicPedalboardNew v0.3.8
    MD 20250915

    Contents
    [0] Prep: boot, minimal processors, pedalboard instance
    [A] Audio sanity: should I hear sound? (mic and test tone checks)
    [1] Scenario 1: build -> switch -> clone -> add reverb -> switch -> replace -> switch
    [2] Scenario 2: bypass and swap ordering while switching
    [3] Scenario 3: live tweaks on CURRENT while playing
    [4] Scenario 4 (optional): larger chain and granular re-order
    [5] Scenario 5 (optional): soft reset & rebuild walkthrough
*/

// ───────────────────────────────────────────────────────────────
// [0] Prep
// ───────────────────────────────────────────────────────────────

// 0.1 Boot the server (run once per session)
Server.default.boot;

// 0.2 Minimal stereo-safe processors (idempotent: only defines if missing)
(
var ensureProxyFunc;

// helper that only defines if the Ndef has no source yet
ensureProxyFunc = { arg key, func;
    var hasSource, canRun;
    hasSource = Ndef(key).source.notNil;
    canRun = Server.default.serverRunning;
    if(hasSource.not and: { canRun }) {
        Server.default.bind({
            Ndef(key, func);
            Ndef(key).ar(2); // ensure 2ch bus
        });
    };
};

// sources
ensureProxyFunc.(\ts0, {
    var inputSignal;
    inputSignal = SoundIn.ar([0, 1]); // mac internal mic is often mono; this keeps stereo shape
    inputSignal
});

// utility test tone (quiet)
ensureProxyFunc.(\testsig, { SinOsc.ar(220 ! 2, 0, 0.08) });

// effects
ensureProxyFunc.(\delay, {
    var inputSignal, time, fb, mix, delayed;
    inputSignal = \in.ar(2);
    time = \time.kr(0.35).clip(0.01, 2.0);
    fb   = \fb.kr(0.35).clip(0.0, 0.95);
    mix  = \mix.kr(0.25).clip(0.0, 1.0);
    delayed = CombC.ar(inputSignal, 2.0, time, time * (fb * 6 + 0.1));
    XFade2.ar(inputSignal, delayed, (mix * 2 - 1))
});

ensureProxyFunc.(\tremolo, {
    var inputSignal, rate, depth, lfo;
    inputSignal = \in.ar(2);
    rate  = \rate.kr(5).clip(0.1, 20);
    depth = \depth.kr(0.5).clip(0, 1);
    lfo   = SinOsc.kr(rate).range(1 - depth, 1);
    inputSignal * lfo
});

ensureProxyFunc.(\reverb, {
    var inputSignal, mix, room, damp;
    inputSignal = \in.ar(2);
    mix  = \mix.kr(0.25).clip(0, 1);
    room = \room.kr(0.5).clip(0, 1);
    damp = \damp.kr(0.3).clip(0, 1);
    FreeVerb.ar(inputSignal, mix, room, damp) // stereo-safe
});

ensureProxyFunc.(\chorus, {
    var inputSignal, rate, depth, baseDelay, modDelay;
    inputSignal = \in.ar(2);
    rate      = \rate.kr(0.8).clip(0.1, 5);
    depth     = \depth.kr(0.008).clip(0.0, 0.02);
    baseDelay = \base.kr(0.020).clip(0.0, 0.05);
    modDelay  = baseDelay + (SinOsc.kr(rate, 0, depth));
    DelayC.ar(inputSignal, 0.1, modDelay)
});

ensureProxyFunc.(\drive, {
    var inputSignal, gain;
    inputSignal = \in.ar(2);
    gain = \gain.kr(2.5).clip(1, 10);
    (inputSignal * gain).tanh
});
);

// 0.3 Create the pedalboard (your class should have the "soft" reset now)
~pedalboard = MagicPedalboardNew.new;

// 0.4 Quick baseline check
~pedalboard.printChains;

// ───────────────────────────────────────────────────────────────
// [A] Audio sanity: should I hear sound?
// ───────────────────────────────────────────────────────────────

// A.1 With mic as source (ts0). Expect live input → speakers (some latency).
~pedalboard.reset; ~pedalboard.printChains; // CURRENT = Lane A, source ts0
Ndef(\chainA).isPlaying.postln;  // should print true

// Speak/clap near the mic. If silence, try the test tone:

// A.2 Test tone as source on NEXT, then switch.
~pedalboard.setSource(\testsig);  // sets NEXT source
~pedalboard.switchChain(0.1);     // you should hear a quiet sine

// A.3 Restore to mic source if desired:
~pedalboard.setSource(\ts0);
~pedalboard.switchChain(0.1);

// Tip: If still silent, verify your SC output device in ServerOptions,
// and confirm your system output volume. You can also crank the testsig amplitude a bit:
// Ndef(\testsig, { SinOsc.ar(220 ! 2, 0, 0.2) }); Ndef(\testsig).ar(2);

// ───────────────────────────────────────────────────────────────
// [1] Scenario 1 — build, switch, clone, add, switch, replace, switch
// ───────────────────────────────────────────────────────────────

// 1.1 Start clean
~pedalboard.reset;

// 1.2 Add delay to NEXT and inspect
~pedalboard.add(\delay); ~pedalboard.printChains;

// 1.3 Crossfade to NEXT (~100 ms)
~pedalboard.switchChain(0.1);

// 1.4 Clone CURRENT processors into NEXT (keep same source)
~procs = ~pedalboard.effectiveCurrent; ~currentProcs = if(~procs.size > 2) { ~procs.copyRange(1, ~procs.size-2) } { [] };

~pedalboard.clearChain;
(
var indexCounter;
indexCounter = 0;
while({ indexCounter < ~currentProcs.size }, {
    ~pedalboard.add(~currentProcs[indexCounter]);
    indexCounter = indexCounter + 1;
});
~pedalboard.setSource(~procs.last);
);
~pedalboard.printChains;

// 1.5 Add reverb after delay in NEXT and inspect
~pedalboard.add(\reverb); ~pedalboard.printChains;

// 1.6 Switch to NEXT (now delay -> reverb)
~pedalboard.switchChain(0.12);

// 1.7 Replace delay with tremolo in NEXT, same position
~effNext = ~pedalboard.effectiveNext; ~delayIndex = ~effNext.indexOf(\delay);

if(~delayIndex.notNil and: { ~delayIndex > 0 and: { ~delayIndex < (~effNext.size-1) } }) {
    ~pedalboard.removeAt(~delayIndex);
    ~pedalboard.addAt(\tremolo, ~delayIndex);
};
~pedalboard.printChains;

// 1.8 Switch again (tremolo -> reverb)
~pedalboard.switchChain(0.1);

// ───────────────────────────────────────────────────────────────
// [2] Scenario 2 — bypass & order swaps
// ───────────────────────────────────────────────────────────────

// 2.1 Build on NEXT: tremolo -> chorus -> delay -> reverb
~pedalboard.clearChain; ~pedalboard.add(\tremolo); ~pedalboard.add(\chorus); ~pedalboard.add(\delay); ~pedalboard.add(\reverb); ~pedalboard.printChains;

// 2.2 Bypass chorus and reverb in NEXT
~pedalboard.bypass(\chorus, true); ~pedalboard.bypass(\reverb, true); ~pedalboard.printChains;

// 2.3 A/B with gentle crossfade (will clamp at 0.2s)
~pedalboard.switchChain(0.25);

// 2.4 Bring chorus back, keep reverb bypassed
~pedalboard.bypass(\chorus, false); ~pedalboard.printChains;

// 2.5 Swap order of tremolo and chorus (processor indexes 1 and 2)
~pedalboard.swap(1, 2); ~pedalboard.printChains;

// 2.6 Longer musical crossfade (still clamped internally)
~pedalboard.switchChain(0.5);

// 2.7 Un-bypass reverb and switch again
~pedalboard.bypass(\reverb, false); ~pedalboard.switchChain(0.1);

// ───────────────────────────────────────────────────────────────
// [3] Scenario 3 — live tweaks on CURRENT while playing
// ───────────────────────────────────────────────────────────────

// 3.1 Inspect current live lane and effective chain
~pedalboard.printChains;

// 3.2 Bypass the first processor in CURRENT (index 1)
~pedalboard.bypassAtCurrent(1, true); ~pedalboard.printChains;

// 3.3 Un-bypass it
~pedalboard.bypassAtCurrent(1, false);

// 3.4 Change the source feeding CURRENT explicitly to \ts0
~pedalboard.setSourceCurrent(\ts0);

// 3.5 Quick A/B to NEXT and back
~pedalboard.switchChain(0.1);
~pedalboard.switchChain(0.1);

// 3.6 Edit NEXT while CURRENT plays: remove last processor and insert drive before it
~effNext = ~pedalboard.effectiveNext; ~lastProcIdx = ~effNext.size - 2;
if(~lastProcIdx >= 1) { ~pedalboard.removeAt(~lastProcIdx); ~pedalboard.addAt(\drive, ~lastProcIdx); };
~pedalboard.printChains;

// 3.7 Take the edited NEXT live
~pedalboard.switchChain(0.1);

// ───────────────────────────────────────────────────────────────
// [4] Scenario 4 (optional) — larger chain and granular re-order
// ───────────────────────────────────────────────────────────────

~pedalboard.clearChain;
~pedalboard.add(\drive); ~pedalboard.add(\tremolo); ~pedalboard.add(\chorus); ~pedalboard.add(\delay); ~pedalboard.add(\reverb);
~pedalboard.printChains;

~pedalboard.swap(4, 3); // move reverb before delay
~pedalboard.swap(3, 2); // chorus up
~pedalboard.swap(2, 1); // chorus to front
~pedalboard.printChains;

~pedalboard.switchChain(0.1);

~pedalboard.removeAt(2); ~pedalboard.add(\tremolo);
~pedalboard.printChains;

~pedalboard.switchChain(0.1);

// ───────────────────────────────────────────────────────────────
// [5] Scenario 5 (optional) — soft reset & rebuild walkthrough
// ───────────────────────────────────────────────────────────────

~pedalboard.reset;

~pedalboard.add(\delay); ~pedalboard.add(\reverb);
~pedalboard.switchChain(0.1);

~effCur = ~pedalboard.effectiveCurrent; ~procsCur = if(~effCur.size > 2) { ~effCur.copyRange(1, ~effCur.size-2) } { [] };
~pedalboard.clearChain; ~procsCur.do({ arg keySymbol; ~pedalboard.add(keySymbol) }); ~pedalboard.add(\chorus);
~pedalboard.bypass(\delay, true);
~pedalboard.printChains;

~pedalboard.setSource(\ts0);
~pedalboard.switchChain(0.1);

~pedalboard.printChains;

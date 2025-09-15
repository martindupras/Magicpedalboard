// scenarios.scd v.0.1
// MD 20250914



/////////////////////////////////
// [0] Run this at the beginning
(
// Minimal processor bootstrap so the symbols exist.
// Each processor reads from \in.ar and returns processed audio.
// Keep it simple and neutral; you can swap these later.

var defineProxy;

// this is a wrapper that makes sure that any Ndef created is audio and two channels.
defineProxy = { arg key, func;
    var canRun;
    canRun = Server.default.serverRunning;
    if(canRun) {
        Server.default.bind({
            Ndef(key, func); // define or overwrite
            Ndef(key).ar(2); // 2 channels by default; matches your pedalboard default
        });
    } {
        "Server not running; start the server first.".postln;
    };
};

// Source tap (ts0) – your default source
defineProxy.(\ts0, {
    var inputSignal;
    inputSignal = SoundIn.ar((0..1)); // stereo in
    inputSignal * 1.0
});

// Simple delay
defineProxy.(\delay, {
    var inputSignal, time, fb, mix, delayed;
    inputSignal = \in.ar;               // adapt to proxy channels
    time = \time.kr(0.35).clip(0.01, 2.0);
    fb   = \fb.kr(0.35).clip(0.0, 0.95);
    mix  = \mix.kr(0.25).clip(0.0, 1.0);
    delayed = CombC.ar(inputSignal, 2.0, time, time * (fb * 6 + 0.1));
    XFade2.ar(inputSignal, delayed, (mix * 2 - 1))
});

// Tremolo
defineProxy.(\tremolo, {
    var inputSignal, rate, depth, lfo;
    inputSignal = \in.ar;
    rate  = \rate.kr(5).clip(0.1, 20);
    depth = \depth.kr(0.5).clip(0, 1);
    lfo   = (SinOsc.kr(rate).range(1 - depth, 1) );
    inputSignal * lfo
});

// Reverb
defineProxy.(\reverb, {
    var inputSignal, mix, room, damp;
    inputSignal = \in.ar;
    mix  = \mix.kr(0.25).clip(0, 1);
    room = \room.kr(0.5).clip(0, 1);
    damp = \damp.kr(0.3).clip(0, 1);
    XFade2.ar(inputSignal, FreeVerb2.ar(inputSignal[0], inputSignal[1], mix, room, damp), 0)
});


// Chorus (simple modulated short delay)
defineProxy.(\chorus, {
    var inputSignal, rate, depth, baseDelay, modDelay;
    inputSignal = \in.ar;
    rate      = \rate.kr(0.8).clip(0.1, 5);
    depth     = \depth.kr(0.008).clip(0.0, 0.02);
    baseDelay = \base.kr(0.020).clip(0.0, 0.05);
    modDelay  = baseDelay + (SinOsc.kr(rate, 0, depth));
    DelayC.ar(inputSignal, 0.1, modDelay)
});

// Gentle drive
defineProxy.(\drive, {
    var inputSignal, gain;
    inputSignal = \in.ar;
    gain = \gain.kr(2.5).clip(1, 10);
    (inputSignal * gain).tanh
});

// Create the pedalboard (no display for now)
~pedalboard = MagicPedalboardNew.new;

// Quick sanity
~pedalboard.printChains;
)





/////////////////////////////////
// [1] Build, switch, clone, replace

(
// ensure clean baseline
var processors, currentProcs, delayIndex;

// 1) reset to source-only on both lanes
~pedalboard.reset;
~pedalboard.printChains;

// 2) add a delay to NEXT (before source) and inspect
~pedalboard.add(\delay);
~pedalboard.printChains;

// 3) go live with NEXT (crossfade ~100 ms)
~pedalboard.switchChain(0.1);

// 4) clone CURRENT’s processors into NEXT (same order), same source
//    (CURRENT is now Lane A)
processors = ~pedalboard.effectiveCurrent;
currentProcs = if(processors.size > 2) { processors.copyRange(1, processors.size-2) } { [] };
~pedalboard.clearChain;
currentProcs.do({ arg key; ~pedalboard.add(key) });
~pedalboard.setSource(processors.last);
~pedalboard.printChains;

// 5) add a reverb after the delay in NEXT and inspect
~pedalboard.add(\reverb);
~pedalboard.printChains;

// 6) switch to NEXT (now has delay -> reverb)
~pedalboard.switchChain(0.12);

// 7) replace delay with tremolo in NEXT
//    find the index of \delay (processors start at index 1)
processors = ~pedalboard.effectiveNext;
delayIndex = processors.indexOf(\delay); // this is in the effective list
if(delayIndex.notNil and: { delayIndex > 0 and: { delayIndex < (processors.size-1) } }) {
    // translate from effective index to chain index (same here since only processors differ)
    ~pedalboard.removeAt(delayIndex);          // remove \delay
    ~pedalboard.addAt(\tremolo, delayIndex);   // add \tremolo in the same position
};
~pedalboard.printChains;

// 8) switch again: we should now hear tremolo -> reverb
~pedalboard.switchChain(0.1);
)

/////////////////////////////////
// [2] Bypass, swap order, fine‑tune fades
(
// Assumes Scenario 1 ran. We'll work on NEXT for safe edits.
var procs;

// 1) build NEXT as: tremolo -> chorus -> delay -> reverb
~pedalboard.clearChain;
~pedalboard.add(\tremolo);
~pedalboard.add(\chorus);
~pedalboard.add(\delay);
~pedalboard.add(\reverb);
~pedalboard.printChains;

// 2) temporarily bypass chorus and reverb in NEXT
~pedalboard.bypass(\chorus, true);
~pedalboard.bypass(\reverb, true);
~pedalboard.printChains;

// 3) A/B with a gentle crossfade (200 ms clamp)
~pedalboard.switchChain(0.25); // will clamp to 0.2 inside the method

// 4) bring chorus back, keep reverb bypassed
~pedalboard.bypass(\chorus, false);
~pedalboard.printChains;

// 5) swap order of tremolo and chorus (indexes 1 and 2 among processors)
~pedalboard.swap(1, 2);
~pedalboard.printChains;

// 6) longer musical crossfade (still clamped internally)
~pedalboard.switchChain(0.5);

// 7) un-bypass reverb and switch again
~pedalboard.bypass(\reverb, false);
~pedalboard.switchChain(0.1);
)


/////////////////////////////////
// [3] Live tweaks on CURRENT while playing
(
// Starting from Scenario 2’s end, we’ll tweak CURRENT safely.

var currentEff, lastProcIndex;

// 1) print current live lane and effective chain
~pedalboard.printChains;

// 2) bypass the first processor in CURRENT (index 1)
~pedalboard.bypassAtCurrent(1, true);
~pedalboard.printChains;

// 3) un-bypass it
~pedalboard.bypassAtCurrent(1, false);

// 4) change the source feeding CURRENT to \ts0 (explicit, even if it's already so)
~pedalboard.setSourceCurrent(\ts0);

// 5) quickly A/B to NEXT and back with short fades
~pedalboard.switchChain(0.1);
~pedalboard.switchChain(0.1);

// 6) remove the last processor in NEXT and insert drive before it
currentEff = ~pedalboard.effectiveNext;
lastProcIndex = currentEff.size - 2;
if(lastProcIndex >= 1) {
    ~pedalboard.removeAt(lastProcIndex);
    ~pedalboard.addAt(\drive, lastProcIndex);
};
~pedalboard.printChains;

// 7) take it live
~pedalboard.switchChain(0.1);
)

/////////////////////////////////
// [4] Build a larger chain, then re‑order granularly
(
// We'll target NEXT, build: drive -> tremolo -> chorus -> delay -> reverb

// 1) reset NEXT to empty (sink, source)
~pedalboard.clearChain;

// 2) add a stack
~pedalboard.add(\drive);
~pedalboard.add(\tremolo);
~pedalboard.add(\chorus);
~pedalboard.add(\delay);
~pedalboard.add(\reverb);

// 3) check
~pedalboard.printChains;

// 4) move reverb before delay (swap processor positions)
~pedalboard.swap(4, 3);  // indexes within processor band (1..n)

// 5) bring chorus to the front (swap it up twice)
~pedalboard.swap(3, 2);
~pedalboard.swap(2, 1);
~pedalboard.printChains;

// 6) A/B in
~pedalboard.switchChain(0.1);

// 7) try removing tremolo and adding it back at the end
~pedalboard.removeAt(2);
~pedalboard.add(\tremolo);
~pedalboard.printChains;

// 8) switch again
~pedalboard.switchChain(0.1);
)

/////////////////////////////////
// [5] Panic‑safe reset and rebuild both lanes
(
// 1) full safe reset
~pedalboard.reset;

// 2) build NEXT quickly: delay -> reverb
~pedalboard.add(\delay);
~pedalboard.add(\reverb);

// 3) go live
~pedalboard.switchChain(0.1);

// 4) copy CURRENT to NEXT, add chorus, bypass delay
var eff, procs;
eff = ~pedalboard.effectiveCurrent;
procs = if(eff.size > 2) { eff.copyRange(1, eff.size-2) } { [] };
~pedalboard.clearChain;
procs.do({ arg key; ~pedalboard.add(key) });
~pedalboard.add(\chorus);
~pedalboard.bypass(\delay, true);
~pedalboard.printChains;

// 5) set a different source for NEXT (still \ts0 here, but shows how)
~pedalboard.setSource(\ts0);

// 6) A/B in
~pedalboard.switchChain(0.1);

// 7) final inspection
~pedalboard.printChains;
)

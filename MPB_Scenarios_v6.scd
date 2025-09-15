/* MPB_Scenarios_v6.scd — SuperCollider-only (no Markdown)
   NO MIC TODAY: ts0 is overridden to an internal test source.
   Test sources are time-varying so delay/reverb are obvious.
   MD 20250915
*/

// [0] Prep — boot server
Server.default.boot;

// [0.1] (Optional hard block) Disable *all* audio input at driver level, then reboot.
// Comment out if you don't want to reboot.
// (
// Server.default.quit;
// Server.default.options.numInputBusChannels = 0;  // hard disable input
// Server.default.options.numOutputBusChannels = 2;
// Server.default.reboot;
// )

// [0.2] Define musical test sources and effects (idempotent)

// Helper to define an Ndef only if it isn't already defined
(
var ensureProxyFunc;

ensureProxyFunc = { arg key, func;
    var hasSource, canRun;
    hasSource = Ndef(key).source.notNil;
    canRun = Server.default.serverRunning;
    if(hasSource.not and: { canRun }) {
        Server.default.bind({
            Ndef(key, func);
            Ndef(key).ar(2); // stereo bus guarantee
        });
    };
};

// ---- Test sources (no microphone) ----

// Percussive melody pings (pitches change; great for delay/reverb)
ensureProxyFunc.(\testmelody, {
    var trig, freqSeq, freq, ampEnv, panPos, tone;
    trig    = Impulse.kr(3.5);
    freqSeq = Dseq([220, 277.18, 329.63, 392.00, 329.63, 277.18, 246.94], inf);
    freq    = Demand.kr(trig, 0, freqSeq);
    ampEnv  = Decay2.kr(trig, 0.01, 0.35);
    panPos  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
    tone    = SinOsc.ar(freq) * ampEnv * 0.25;
    Pan2.ar(tone, panPos)
});

// Sparse tonal bursts (reverb tails are obvious)
ensureProxyFunc.(\testbursts, {
    var trig, env, freq, tone, panPos;
    trig   = Impulse.kr(1.2);
    env    = EnvGen.kr(Env.perc(0.005, 0.8, 0.6), trig);
    freq   = TExpRand.kr(180, 660, trig);
    tone   = SinOsc.ar(freq) * env * 0.35;
    panPos = LFNoise1.kr(0.2).range(-0.7, 0.7);
    Pan2.ar(tone, panPos)
});

// ---- Effects (stereo-safe, simple defaults) ----
ensureProxyFunc.(\delay, {
    var inputSignal, time, fb, mix, delayed;
    inputSignal = \in.ar(2);
    time = \time.kr(0.45).clip(0.01, 2.0);
    fb   = \fb.kr(0.35).clip(0.0, 0.95);
    mix  = \mix.kr(0.5).clip(0.0, 1.0);
    delayed = CombC.ar(inputSignal, 2.0, time, time * (fb * 6 + 0.1));
    XFade2.ar(inputSignal, delayed, (mix * 2 - 1))
});

ensureProxyFunc.(\tremolo, {
    var inputSignal, rate, depth, lfo;
    inputSignal = \in.ar(2);
    rate  = \rate.kr(5).clip(0.1, 20);
    depth = \depth.kr(0.6).clip(0, 1);
    lfo   = SinOsc.kr(rate).range(1 - depth, 1);
    inputSignal * lfo
});

ensureProxyFunc.(\reverb, {
    var inputSignal, mix, room, damp;
    inputSignal = \in.ar(2);
    mix  = \mix.kr(0.35).clip(0, 1);
    room = \room.kr(0.5).clip(0, 1);
    damp = \damp.kr(0.3).clip(0, 1);
    FreeVerb.ar(inputSignal, mix, room, damp)
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
)

// [0.3] NO MIC GUARANTEE — override \ts0 to be an internal source (before creating pedalboard)
(
Server.default.bind({
    // Use testmelody (or switch to \testbursts by replacing the function)
    Ndef(\ts0, {
        var trig, freqSeq, freq, env, panPos, tone;
        trig    = Impulse.kr(3.5);
        freqSeq = Dseq([220, 277.18, 329.63, 392.00, 329.63, 277.18, 246.94], inf);
        freq    = Demand.kr(trig, 0, freqSeq);
        env     = Decay2.kr(trig, 0.01, 0.35);
        panPos  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
        tone    = SinOsc.ar(freq) * env * 0.25;
        Pan2.ar(tone, panPos)
    });
    Ndef(\ts0).ar(2);
});
);

// [0.4] Pedalboard instance (uses \ts0 internally, now safe)
~pedalboard = MagicPedalboardNew.new;
~pedalboard.printChains;

// [A] Audio sanity (no microphone)
~pedalboard.reset; // CURRENT plays \ts0 which is internal testmelody now
~pedalboard.setSource(\testmelody); ~pedalboard.switchChain(0.1);

// ======================
// [1] Scenario 1 — basic
// ======================

~pedalboard.reset;
~pedalboard.setSource(\testmelody); ~pedalboard.switchChain(0.1);
~pedalboard.add(\delay); ~pedalboard.printChains;
~pedalboard.switchChain(0.1);
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
~pedalboard.add(\reverb); ~pedalboard.printChains;
~pedalboard.switchChain(0.12);
~effNext = ~pedalboard.effectiveNext; ~delayIndex = ~effNext.indexOf(\delay);
if(~delayIndex.notNil and: { ~delayIndex > 0 and: { ~delayIndex < (~effNext.size-1) } }) {
    ~pedalboard.removeAt(~delayIndex);
    ~pedalboard.addAt(\tremolo, ~delayIndex);
};
~pedalboard.printChains;
~pedalboard.switchChain(0.1);

// ==========================
// [2] Scenario 2 — bypass/swap
// ==========================

~pedalboard.clearChain; ~pedalboard.add(\tremolo); ~pedalboard.add(\chorus); ~pedalboard.add(\delay); ~pedalboard.add(\reverb); ~pedalboard.printChains;
~pedalboard.bypass(\chorus, true); ~pedalboard.bypass(\reverb, true); ~pedalboard.printChains;
~pedalboard.switchChain(0.25);
~pedalboard.bypass(\chorus, false); ~pedalboard.printChains;
~pedalboard.swap(1, 2); ~pedalboard.printChains;
~pedalboard.switchChain(0.5);
~pedalboard.bypass(\reverb, false); ~pedalboard.switchChain(0.1);

// ===============================
// [3] Scenario 3 — live tweaks now
// ===============================

~pedalboard.printChains;
~pedalboard.bypassAtCurrent(1, true); ~pedalboard.printChains;
~pedalboard.bypassAtCurrent(1, false);
~pedalboard.switchChain(0.1); ~pedalboard.switchChain(0.1);
~effNext = ~pedalboard.effectiveNext; ~lastProcIdx = ~effNext.size - 2;
if(~lastProcIdx >= 1) { ~pedalboard.removeAt(~lastProcIdx); ~pedalboard.addAt(\drive, ~lastProcIdx); };
~pedalboard.printChains;
~pedalboard.switchChain(0.1);




~assertHas = { arg list, key;
    if(list.includes(key).not) { ("ASSERT missing " ++ key).postln };
};
~assertEnds = { arg list, key;
    if(list.last != key) { ("ASSERT last must be " ++ key).postln };
};

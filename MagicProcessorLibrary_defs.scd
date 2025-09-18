/* MagicProcessorLibrary_defs.scd
   Register a few defaults. Keep this file small and readable.
*/
(
var lib, define;

lib = MagicProcessorLibrary.new;

define = { arg key, func; lib.register(key, func) };

// Sources
define.(\ts0, {
    var inputSignal;
    inputSignal = Silent.ar((0..1));
    inputSignal * 1.0
});

// Effects – same as in bootstrap, or your refined versions
define.(\delay, {
    var inputSignal, time, fb, mix, delayed;
    inputSignal = \in.ar;
    time = \time.kr(0.35).clip(0.01, 2.0);
    fb   = \fb.kr(0.35).clip(0.0, 0.95);
    mix  = \mix.kr(0.25).clip(0.0, 1.0);
    delayed = CombC.ar(inputSignal, 2.0, time, time * (fb * 6 + 0.1));
    XFade2.ar(inputSignal, delayed, (mix * 2 - 1))
});

define.(\tremolo, {
    var inputSignal, rate, depth;
    inputSignal = \in.ar;
    rate  = \rate.kr(5).clip(0.1, 20);
    depth = \depth.kr(0.5).clip(0, 1);
    inputSignal * SinOsc.kr(rate).range(1 - depth, 1)
});

define.(\reverb, {
    var inputSignal, mix, room, damp;
    inputSignal = \in.ar;
    mix  = \mix.kr(0.25).clip(0, 1);
    room = \room.kr(0.5).clip(0, 1);
    damp = \damp.kr(0.3).clip(0, 1);
    XFade2.ar(inputSignal, FreeVerb2.ar(inputSignal[0], inputSignal[1], mix, room, damp), 0)
});

define.(\chorus, {
    var inputSignal, rate, depth, baseDelay, modDelay;
    inputSignal = \in.ar;
    rate      = \rate.kr(0.8).clip(0.1, 5);
    depth     = \depth.kr(0.008).clip(0.0, 0.02);
    baseDelay = \base.kr(0.020).clip(0.0, 0.05);
    modDelay  = baseDelay + (SinOsc.kr(rate, 0, depth));
    DelayC.ar(inputSignal, 0.1, modDelay)
});

define.(\drive, {
    var inputSignal, gain;
    inputSignal = \in.ar;
    gain = \gain.kr(2.5).clip(1, 10);
    (inputSignal * gain).tanh
});

// Expose the library in a tilde var for convenience
~procLib = lib;

// Ensure a basic set now (optional; you can call ensureFromChain later)
~procLib.ensureMany(~procLib.keys, 2);
)

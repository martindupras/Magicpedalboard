
// Simple sources / processors (stereo)
Ndef(\ts0, { Silent.ar(2) });
Ndef(\tsSaw, { Saw.ar(200, 0.12) ! 2 });
Ndef(\tsDust, { Dust.ar(2000) ! 2 });

Ndef(\tremolo, { |rate = 5, depth = 0.8|
    var inSig = \in.ar(2);
    inSig * SinOsc.kr(rate).range(1 - depth, 1)
});

// Create display + pedalboard
d = MagicDisplay.new(1);          // verbose console
m = MagicPedalboardNew.new(d);    // pass display at construction
// Exercise a few actions
m.setSourceCurrent(\tsSaw);
m.add(\tremolo);
m.printChains;

m.switchChain;
m.setSource(\tsDust);
m.clearChain;
m.printChains;

m.stopCurrent;


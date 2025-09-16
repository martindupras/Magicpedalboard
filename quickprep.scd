// quickprep.scd
// v0.1
// MD 20250916


(
// ===== Acceptance Prep =====
var linkedDisplay, hasGui, chainAName, chainBName;

linkedDisplay = nil;
hasGui = (~gui.notNil) and: { ~gui.isKindOf(MagicDisplayGUI) };
if(hasGui) { linkedDisplay = ~gui };

if(~mpb.isNil) {
    ~mpb = MagicPedalboardNew.new(linkedDisplay);
} {
    if(linkedDisplay.notNil) { ~mpb.setDisplay(linkedDisplay) };
};

// create a simple stereo test melody (safe levels)
Ndef(\testmelody, {
    var freq, lfo, sig;
    lfo = LFTri.kr(0.13).range(0.5, 1.0);
    freq = [220, 330] * lfo;
    sig = SinOsc.ar(freq, 0, 0.08);  // quiet
    sig
});

// set source to \testmelody on both chains (explicit)
~mpb.setSourceCurrent(\testmelody);
~mpb.setSource(\testmelody);

// start CURRENT sink (A by default on fresh boot)
~mpb.playCurrent;

// convenience: names for readability
chainAName = \chainA;
chainBName = \chainB;

// status
"Prep done. CURRENT is playing. A.isPlaying=%, B.isPlaying=%"
    .format(Ndef(chainAName).isPlaying, Ndef(chainBName).isPlaying).postln;
)

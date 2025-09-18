// Verify_SetSourcesBoth_Today.scd
// v0.2
// MD 2025-09-18 11:55 BST

// Purpose:
// - Verify both chains have an explicit source without assuming ~mpb exists.
// - Uses supported API: setSource (NEXT) and setSourceCurrent (CURRENT).
// Style:
// - var-first; lowercase; no server.sync; server ops inside Server.default.bind.

(
var warn, ensureSources;

warn = { arg s; ("[VERIFY] " ++ s).warn };

if(~mpb.isNil) {
    warn.("~mpb is nil. Run StartHere_CleanBoot_OneWindow_BringUp.scd first.");
    ^nil;
};

// Ensure generated sources exist (no SoundIn).
ensureSources = {
    Server.default.bind({
        Ndef(\testmelody, {
            var trig = Impulse.kr(3.2);
            var seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
            var f    = Demand.kr(trig, 0, seq);
            var env  = Decay2.kr(trig, 0.01, 0.35);
            var pan  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
            Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
        });
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
};

// Do it
ensureSources.();
~mpb.setSourceCurrent(\testmelody);  // CURRENT’s source
~mpb.setSource(\testmelody);         // NEXT’s source
~mpb.printChains;
"[VERIFY] Both chains point to \\testmelody (CURRENT and NEXT)".postln;
)

// Verify_SetSourcesBoth_Today.scd
// v0.2
// MD 2025-09-18 13:46 BST

// Purpose
// - Verify that both chains have \testmelody as their source symbol, without assuming ~mpb exists.
// Style
// - var-first; lowercase; no server.sync; server ops via class methods only.

(
var warn, ensureSources;
warn = { arg s; var msg; msg = "[VERIFY] " ++ s; msg.warn };

if(~mpb.isNil) {
    warn.("~mpb is nil. Run StartHere_CleanBoot_OneWindow_BringUp.scd first.");
    ^nil;
};

ensureSources = {
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, f, env, pan;
                trig = Impulse.kr(3.2);
                seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                f    = Demand.kr(trig, 0, seq);
                env  = Decay2.kr(trig, 0.01, 0.35);
                pan  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
};

ensureSources.();
~mpb.setSourceCurrent(\testmelody);
~mpb.setSource(\testmelody);
~mpb.printChains;
"[VERIFY] Both chains point to \\testmelody (CURRENT and NEXT)".postln;
)

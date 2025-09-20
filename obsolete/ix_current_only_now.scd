// fix_current_only_now.scd
// v0.1
// MD 20250916-1007

(
var log;

log = { arg m; ("[FIX] " ++ m).postln };

// stop NEXT sink explicitly
if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop; log.("stopped \\chainB"); };

// re-wire CURRENT effective list with the correct operator and play only CURRENT
Server.default.bind({
    // ensure stereo busses (cheap no-op if already set)
    Ndef(\chainA).ar(2);
    Ndef(\testmelody).ar(2);

    // correct embed operator you use in this project:
    Ndef(\chainA) <<> Ndef(\testmelody);

    // play CURRENT sink only
    Ndef(\chainA).play(numChannels: 2);
});

~pedalboard.printChains;
"[FIX] chainA <<> testmelody; chainA.play done.".postln;
)

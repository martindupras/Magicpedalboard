// fix_current_exclusive_now.scd
// v0.3
// MD 20250916-1132

(
// 0) Stop any direct-to-out and both sinks first (clean slate)
if(Ndef(\testmelody).isPlaying) { Ndef(\testmelody).stop; "[FIX] stopped \\testmelody direct".postln; };
if(Ndef(\chainA).isPlaying)     { Ndef(\chainA).stop;     "[FIX] stopped \\chainA".postln; };
if(Ndef(\chainB).isPlaying)     { Ndef(\chainB).stop;     "[FIX] stopped \\chainB".postln; };

// 1) Ensure stereo busses (cheap no-op if already set)
Ndef(\testmelody).ar(2);
Ndef(\chainA).ar(2);

// 2) Wire CURRENT explicitly with the correct JITLib operator you use in this project,
//    and play CURRENT only (no chainB)
Server.default.bind({
    Ndef(\chainA) <<> Ndef(\testmelody);
    Ndef(\chainA).play(numChannels: 2);
});

// 3) Quick status (target: testmelody=false, chainA=true, chainB=false)
[\testmelody, \chainA, \chainB, \delay, \chorus].do({ arg nm;
    ("[PLAY] " ++ nm ++ " = " ++ Ndef(nm).isPlaying).postln;
});
)

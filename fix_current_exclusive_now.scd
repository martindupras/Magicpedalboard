// fix_current_exclusive_now.scd
// v0.1
// MD 20250916-1117

(
var log;

log = { arg m; ("[FIX] " ++ m).postln };

// Stop everything that could be sending directly to outputs
if(Ndef(\testmelody).isPlaying) { Ndef(\testmelody).stop; log.("stopped \\testmelody direct") };
if(Ndef(\chainA).isPlaying)     { Ndef(\chainA).stop;     log.("stopped \\chainA") };
if(Ndef(\chainB).isPlaying)     { Ndef(\chainB).stop;     log.("stopped \\chainB") };

// Ensure stereo busses (cheap no-op if already set)
Ndef(\testmelody).ar(2);
Ndef(\chainA).ar(2);

// Wire CURRENT explicitly with the correct operator and start CURRENT only
Server.default.bind({
    Ndef(\chainA) <<> Ndef(\testmelody);   // sink receives source through the ‘in’ slot
    Ndef(\chainA).play(numChannels: 2);    // play CURRENT only
});

~pedalboard.printChains;
"[FIX] CURRENT exclusive: chainA <<> testmelody; chainA.play".postln;
)

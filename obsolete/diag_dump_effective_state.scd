// diag_dump_effective_state.scd
// v0.1
// MD 20250916

(


var aPlaying, bPlaying, line;

~mpb.printChains;

aPlaying = Ndef(\chainA).isPlaying;
bPlaying = Ndef(\chainB).isPlaying;
line = "[diag] A.isPlaying=%  B.isPlaying=%".format(aPlaying, bPlaying);
line.postln;
)

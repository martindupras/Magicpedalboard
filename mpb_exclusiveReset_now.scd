(
// mpb_exclusiveReset_now.scd
// v0.1
// MD 20250916

var reportStatus;

reportStatus = {
    var aPlaying, bPlaying, textOut;
    aPlaying = Ndef(\chainA).isPlaying;
    bPlaying = Ndef(\chainB).isPlaying;
    textOut = "[status] A.playing=%  B.playing=%".format(aPlaying, bPlaying);
    textOut.postln;
};

// Reset MPB: leaves CURRENT playing and NEXT stopped
~mpb.reset;
reportStatus.();
)

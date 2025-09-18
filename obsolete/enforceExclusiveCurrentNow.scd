// enforceExclusiveCurrentNow.scd
// v0.2
// MD 20250916


(

var listCurrent, listNext, currentSink, nextSink, postStatus, numCh;

if(~mpb.isNil) { "[enforceExclusive] ~mpb is nil".warn; ^nil };

listCurrent = ~mpb.currentChain;
listNext    = ~mpb.nextChain;

currentSink = listCurrent[0];
nextSink    = listNext[0];

numCh = (~mpb.respondsTo(\defaultNumChannels) ? ~mpb.defaultNumChannels) ?? { 2 };

Server.default.bind({
    // Rebuild both chains without resets; wiring via <<>
    ~mpb.rebuildUnbound(listNext);     // should stop NEXT sink
    ~mpb.rebuildUnbound(listCurrent);  // should play CURRENT sink

    // Belt-and-braces: explicitly enforce state
    if(Ndef(nextSink).isPlaying) { Ndef(nextSink).stop };
    if(Ndef(currentSink).isPlaying.not) { Ndef(currentSink).play(numChannels: numCh) };
});

// Print status a short moment later (no server.sync)
postStatus = {
    AppClock.sched(0.20, {
        var aPlaying, bPlaying, line;
        aPlaying = Ndef(\chainA).isPlaying;
        bPlaying = Ndef(\chainB).isPlaying;
        line = "[status] A.playing=%  B.playing=%".format(aPlaying, bPlaying);
        line.postln;
        nil
    });
};
postStatus.();
)

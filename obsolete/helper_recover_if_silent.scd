// helper_recover_if_silent.scd
// v0.2

(
~recoverLog = ~recoverLog ?? { arg messageString;
    ("[RECOVER] " ++ messageString).postln;
};

~recoverIfSilent = {
    var ensureStereo, connectPair, connectList, currentEff, nextEff;
    var currentSink, nextSink, indexCounter, lastIndex;

    if(~mpb.isNil) { ~recoverLog.("~mpb is nil"); ^false };

    // Temporarily disable meters to avoid control-rate warnings during repair
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false) };

    // Ensure sinks are audio-rate
    Server.default.bind({
        Ndef(\chainA).ar(2);
        Ndef(\chainB).ar(2);
    });

    // Effective lists from pedalboard
    currentEff = ~mpb.effectiveCurrent;
    nextEff    = ~mpb.effectiveNext;

    ensureStereo = { arg keySymbol; Ndef(keySymbol).ar(2) };

    connectPair = { arg leftKey, rightKey;
        // matches project operator direction: left receives right
        Server.default.bind({ Ndef(leftKey) <<> Ndef(rightKey) });
    };

    connectList = { arg listSymbols;
        indexCounter = 0;
        lastIndex = listSymbols.size - 1;
        while({ indexCounter < lastIndex }, {
            var leftKey, rightKey;
            leftKey  = listSymbols[indexCounter];
            rightKey = listSymbols[indexCounter + 1];
            ensureStereo.(leftKey);
            ensureStereo.(rightKey);
            connectPair.(leftKey, rightKey);
            indexCounter = indexCounter + 1;
        });
    };

    // Rebuild both chains end-to-end
    connectList.(currentEff);
    connectList.(nextEff);

    // Enforce: CURRENT plays, NEXT stopped
    currentSink = currentEff[0];
    nextSink    = nextEff[0];
    Server.default.bind({
        if(Ndef(nextSink).isPlaying)        { Ndef(nextSink).stop };
        if(Ndef(currentSink).isPlaying.not) { Ndef(currentSink).play(numChannels: 2) };
    });

    // Re-enable meters (after AR is guaranteed)
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(true) };

    ~recoverLog.("reconnected. currentEff=" ++ currentEff ++ " nextEff=" ++ nextEff);

    // Status a moment later (no server.sync)
    AppClock.sched(0.20, {
        var aPlaying, bPlaying, line;
        aPlaying = Ndef(\chainA).isPlaying;
        bPlaying = Ndef(\chainB).isPlaying;
        line = "[status] A.playing=% B.playing=%".format(aPlaying, bPlaying);
        line.postln; nil
    });

    true
};
)

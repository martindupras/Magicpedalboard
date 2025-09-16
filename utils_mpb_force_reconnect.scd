// utils_mpb_force_reconnect.scd
// v0.2
// MD 20250916-1057

(
~mpb_forceReconnect = { arg pedalboard;
    var log, connectPair, reconnectList, effCur, effNext, sinkCur, sinkNext, indexCounter, lastIndex;

    log = { arg txt; ("[FIX] " ++ txt).postln };

    connectPair = { arg leftKey, rightKey;
        Server.default.bind({
            // Correct JITLib embed operator used in your project:
            Ndef(leftKey) <<> Ndef(rightKey);
        });
    };

    reconnectList = { arg listSymbols;
        indexCounter = 0;
        lastIndex = listSymbols.size - 1;
        while({ indexCounter < lastIndex }, {
            connectPair.(listSymbols[indexCounter], listSymbols[indexCounter + 1]);
            indexCounter = indexCounter + 1;
        });
    };

    effCur = pedalboard.effectiveCurrent;
    effNext = pedalboard.effectiveNext;

    reconnectList.(effCur);
    reconnectList.(effNext);

    sinkCur = effCur[0];
    sinkNext = effNext[0];

    Server.default.bind({
        if(Ndef(sinkCur).isPlaying.not) { Ndef(sinkCur).play(numChannels: 2) };
        if(Ndef(sinkNext).isPlaying)    { Ndef(sinkNext).stop };
    });

    log.("forceReconnect done. current=" ++ effCur ++ "  next=" ++ effNext);
};
)

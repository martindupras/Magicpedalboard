// fix_chain_current_exclusive.scd
// v0.1
// MD 20250916-1103

(
var log, ensureStereo, stopSinks, connectEffectiveCurrent;

log = { arg m; ("[FIX] " ++ m).postln };

ensureStereo = { arg keySym;
    // Make sure every Ndef we will touch has a stereo bus
    Ndef(keySym).ar(2);
};

stopSinks = {
    // Stop both sinks so we can relaunch CURRENT cleanly
    if(Ndef(\chainA).isPlaying) { Ndef(\chainA).stop };
    if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop };
    log.("stopped sinks chainA/chainB");
};

connectEffectiveCurrent = {
    var eff, indexCounter, lastIndex, leftKey, rightKey, sinkKey;

    // Compute CURRENT effective list from your pedalboard
    eff = ~pedalboard.effectiveCurrent;

    // Ensure stereo busses for all nodes involved
    eff.do({ arg k; ensureStereo.(k) });

    // Connect pairwise using the correct JITLib operator you use in this project
    indexCounter = 0;
    lastIndex = eff.size - 1;
    while({ indexCounter < lastIndex }, {
        leftKey  = eff[indexCounter];
        rightKey = eff[indexCounter + 1];
        Server.default.bind({
            Ndef(leftKey) <<> Ndef(rightKey);
        });
        indexCounter = indexCounter + 1;
    });

    // Launch CURRENT sink only
    sinkKey = eff[0];
    Server.default.bind({
        Ndef(sinkKey).play(numChannels: 2);
    });

    log.("reconnected CURRENT: " ++ eff);
};

// --- run the steps ---
stopSinks.();
connectEffectiveCurrent.();
)

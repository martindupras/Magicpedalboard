// switchDelayCheck.scd
// v0.1
// MD 20250916

(
// Goal: add \delay to NEXT, switch with a crossfade, and confirm audio continues on CURRENT.

// --- Preconditions: GUI + MPB exist; audibleSanity.scd already run today. ---

var log, cleanupDirectPlays, prepStatus, addDelayToNext, doSwitch, afterSwitchCheck, recoverIfSilent;

log = { arg m; ("[switchDelay] " ++ m).postln };

cleanupDirectPlays = {
    // ensure no direct-to-out play is active for the generator
    if(Ndef(\testmelody).isPlaying) { Ndef(\testmelody).stop; log.("stopped direct \\testmelody") };
};

prepStatus = {
    ~mpb.printChains;
    ("[before] A=%  B=%"
        .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
};

addDelayToNext = {
    ~mpb.clearChain;            // keep NEXT minimal before adding
    ~mpb.add(\delay);           // add to NEXT
    ~mpb.printChains;
};

doSwitch = {
    ~mpb.switchChain(0.12);     // short crossfade; CURRENT <-> NEXT
};

afterSwitchCheck = {
    AppClock.sched(0.35, {
        ~mpb.printChains;
        ("[after]  A=%  B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        nil
    });
};

// If for any reason we went silent, rebuild connections & enforce CURRENT-only play.
// (Equivalent to your enforceExclusiveCurrentNow utilities)
recoverIfSilent = {
    AppClock.sched(0.60, {
        var curEff, curSink;
        curEff = ~mpb.effectiveCurrent;
        curSink = curEff[0];
        Server.default.bind({
            ~mpb.rebuildUnbound(~mpb.currentChain);
            ~mpb.rebuildUnbound(~mpb.nextChain);
            // enforce exclusive current
            if(curSink == \chainA) {
                if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop };
                if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
            }{
                if(Ndef(\chainA).isPlaying) { Ndef(\chainA).stop };
                if(Ndef(\chainB).isPlaying.not) { Ndef(\chainB).play(numChannels: 2) };
            };
        });
        log.("reconnect enforced, currentEff=" ++ curEff);
        nil
    });
};

// --- run steps ---
cleanupDirectPlays.value;
prepStatus.value;
addDelayToNext.value;
doSwitch.value;
afterSwitchCheck.value;
recoverIfSilent.value;
)

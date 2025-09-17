// Enforce_ExclusiveBySilencingNext.scd
// v0.2
// MD 20250916-1714

//
// Purpose: Guarantee audible exclusivity immediately by silencing the NEXT sink’s source.
//          CURRENT remains { \in.ar(2) } and audible; NEXT is set to Silent.ar(2). This avoids
//          NodeProxy monitor tail/race issues where isPlaying may remain true on NEXT.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, getCurrentNextSinks, silenceNextSink, ensureCurrentAudible, retargetMeters, verify, sinks;

log = { arg messageString; ("[XONLY] " ++ messageString).postln; };

// Identify sink symbols for CURRENT and NEXT from ~mpb
getCurrentNextSinks = {
    if(~mpb.isNil) {
        "[XONLY] ~mpb is nil".warn;
        ^nil
    };
    ^(
        current: ~mpb.effectiveCurrent[0],   // \chainA or \chainB
        next:    ~mpb.effectiveNext[0]       // the other one
    )
};

// Replace NEXT sink source with silence; keep bus AR so meters won’t warn
silenceNextSink = { arg nextSinkSym;
    Server.default.bind({
        Ndef(nextSinkSym, { Silent.ar(2) });  // hard silence at the sink
        Ndef(nextSinkSym).ar(2);
        Ndef(nextSinkSym).fadeTime_(0.01);
        Ndef(nextSinkSym).stop;               // stop its monitor quickly (optional)
    });
    log.("NEXT " ++ nextSinkSym.asString ++ " silenced");
};

// Ensure CURRENT uses robust sink source and is playing
ensureCurrentAudible = { arg currentSinkSym;
    Server.default.bind({
        Ndef(currentSinkSym, { \in.ar(2) });
        Ndef(currentSinkSym).ar(2);
        Ndef(currentSinkSym).fadeTime_(0.05);
        if(Ndef(currentSinkSym).isPlaying.not) {
            Ndef(currentSinkSym).play(numChannels: 2);
        };
    });
    log.("CURRENT " ++ currentSinkSym.asString ++ " robust+playing");
};

// Reattach meters safely after AR guarantee
retargetMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(false);
        ~gui.enableMeters(true);
    };
};

// Post final state a moment later
verify = {
    ~mpb.printChains;
    AppClock.sched(0.25, {
        var aPlaying, bPlaying, lineText;
        aPlaying = Ndef(\chainA).isPlaying;
        bPlaying = Ndef(\chainB).isPlaying;
        lineText = "[PLAY] A=%  B=%".format(aPlaying, bPlaying);
        lineText.postln;
        nil
    });
};

// --- run ---
sinks = getCurrentNextSinks.value;
if(sinks.notNil) {
    ensureCurrentAudible.(sinks[\current]);
    silenceNextSink.(sinks[\next]);
    retargetMeters.value;
    verify.value;
};
)

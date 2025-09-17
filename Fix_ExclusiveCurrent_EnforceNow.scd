// Fix_ExclusiveCurrent_EnforceNow.scd
// v0.3
// MD 20250916-1700

//
// Purpose: Force “CURRENT=A playing, NEXT=B stopped” deterministically, even if a prior crossfade
//          or monitor tail keeps B reporting ‘playing’. Handles stop→pause→(last‑resort) clear+restore.
// Style:   tilde vars, var-first, lowercase names, no server.sync, Server.default.bind for server ops.

(
var log, phase1_stopWithShortFade, phase2_pauseIfStill, phase3_lastResort, startAIfNeeded, verifyFinal;

log = { arg s; ("[FIX] " ++ s).postln; };

// Phase 1: small fades, stop B (start fade-down)
phase1_stopWithShortFade = {
    Server.default.bind({
        Ndef(\chainA).fadeTime_(0.05);
        Ndef(\chainB).fadeTime_(0.01);
        Ndef(\chainB).stop;
    });
    log.("phase1: set fade A=0.05 B=0.01; B.stop");
};

// Phase 2: after short wait, pause B (hard drop of monitor) and ensure A is playing
phase2_pauseIfStill = {
    AppClock.sched(0.12, {
        Server.default.bind({
            if(Ndef(\chainB).isPlaying) { Ndef(\chainB).pause };  // kills monitor immediately
            if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
        });
        log.("phase2: B.pause (if needed), A.play (if needed)");
        nil
    });
};

// Phase 3: last resort — if B still reports playing, clear + restore robust sink source
phase3_lastResort = {
    AppClock.sched(0.26, {
        if(Ndef(\chainB).isPlaying) {
            log.("phase3: B still playing -> clear+restore sink");
            Server.default.bind({
                // Replace B’s source with robust \in.ar(2) and reassert AR bus
                Ndef(\chainB).clear(0);
                Ndef(\chainB, { \in.ar(2) });
                Ndef(\chainB).ar(2);
            });
        };
        nil
    });
};

// Safety: if A not playing after everything, start it
startAIfNeeded = {
    AppClock.sched(0.30, {
        Server.default.bind({
            if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
            // ensure B is not audible
            if(Ndef(\chainB).isPlaying) { Ndef(\chainB).pause };
        });
        nil
    });
};

// Final verification
verifyFinal = {
    AppClock.sched(0.35, {
        var a, b;
        a = Ndef(\chainA).isPlaying;
        b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=%  B=%".format(a, b)).postln;
        nil
    });
};

// Run the phases
phase1_stopWithShortFade.value;
phase2_pauseIfStill.value;
phase3_lastResort.value;
startAIfNeeded.value;
verifyFinal.value;
)

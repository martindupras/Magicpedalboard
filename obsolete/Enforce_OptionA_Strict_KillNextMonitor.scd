// Enforce_OptionA_Strict_KillNextMonitor.scd
// v0.1
// MD 20250917-1155
//
// Purpose: Deterministically silence NEXT and drop its monitor (pause+stop+end),
// while keeping CURRENT audible. Avoids GUI/server races by disabling meters first.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, disableMeters, getSinks, killNextHard, ensureCurrent, enableMeters, verify, sinks;

log = { arg s; ("[X-ENFORCE] " ++ s).postln };

disableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        AppClock.sched(0.0, { ~gui.enableMeters(false); nil });
        AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
        log.("meters disabled");
    };
};

getSinks = {
    // Use effective lists so we match CURRENT/NEXT after any recent switch
    sinks = ( current: ~mpb.effectiveCurrent[0], next: ~mpb.effectiveNext[0] );
    log.("current=" ++ sinks[\current].asString ++ " next=" ++ sinks[\next].asString);
};

killNextHard = {
    var nextSink = sinks[\next];
    Server.default.bind({
        // Source = hard silence, stereo bus; then kill monitor with pause+stop+end
        Ndef(nextSink, { Silent.ar(2) });
        Ndef(nextSink).ar(2);
        Ndef(nextSink).fadeTime_(0.01);
        // Kill monitor by every legal means; safe even if not playing
        Ndef(nextSink).pause;
        Ndef(nextSink).stop;
        Ndef(nextSink).end(0.01);   // fades/ends any residual monitor synth
    });
    log.("NEXT " ++ nextSink.asString ++ " silenced and monitor ended");
};

ensureCurrent = {
    var cur = sinks[\current];
    Server.default.bind({
        Ndef(cur, { \in.ar(2) });
        Ndef(cur).ar(2);
        Ndef(cur).fadeTime_(0.08);
        if(Ndef(cur).isPlaying.not) { Ndef(cur).play(numChannels: 2) };
    });
    log.("CURRENT " ++ cur.asString ++ " robust+playing");
};

enableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(true);   // re-sends meter SynthDefs and guards AR buses
        log.("meters re-enabled");
    };
};

verify = {
    AppClock.sched(0.35, {
        var a = Ndef(\chainA).isPlaying;
        var b = Ndef(\chainB).isPlaying;
        ("[X-ENFORCE] [PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

// run
disableMeters.value;
getSinks.value;
killNextHard.value;
ensureCurrent.value;
enableMeters.value;
verify.value;
)

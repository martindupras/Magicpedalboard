// Fix_Now_BringUp_Recovery.scd
// v0.1
// MD 20250917-1136
//
// Purpose: Recover from early meter attach + channel wraps: disable meters,
// ensure stereo sinks, define stereo ts0 (silent), ensure testmelody, re‑enforce
// Option A exclusivity, then cleanly re‑enable meters.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, ensureServer, disableMetersNow, ensureStereoSinks, defineTs0StereoSilent,
    defineTestMelody, reassertExclusive, enableMetersClean, verify;

log = { arg s; ("[RECOVER] " ++ s).postln };

ensureServer = {
    if(Server.default.serverRunning.not, { Server.default.boot });
};

disableMetersNow = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        // do it twice on AppClock to beat any queued auto-enable
        AppClock.sched(0.0, { ~gui.enableMeters(false); nil });
        AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
        log.("meters disabled");
    };
};

ensureStereoSinks = {
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
    log.("sinks set to robust stereo (\\in.ar)");
};

defineTs0StereoSilent = {
    // make NEXT's default source unambiguously stereo to avoid 2→1 wraps
    Server.default.bind({
        Ndef(\ts0, { Silent.ar(2) });
        Ndef(\ts0).ar(2);
    });
    log.("\\ts0 defined as stereo Silent");
};

defineTestMelody = {
    Server.default.bind({
        Ndef(\testmelody, {
            var trig = Impulse.kr(3.2);
            var seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            var f    = Demand.kr(trig, 0, seq);
            var env  = Decay2.kr(trig, 0.01, 0.35);
            var tone = SinOsc.ar(f) * env * 0.25;
            var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        });
        Ndef(\testmelody).ar(2);
    });
    log.("\\testmelody (stereo) ensured");
};

reassertExclusive = {
    // Use class-level Option A (CURRENT audible; NEXT hard-silenced)
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    log.("class-level exclusivity reasserted (Option A)");
};

enableMetersClean = {
    // Your GUI’s enableMeters() re-sends SynthDefs each time
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(true);
        log.("meters re-enabled");
    };
};

verify = {
    AppClock.sched(0.25, {
        var a = Ndef(\chainA).isPlaying;
        var b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

// run
ensureServer.value;
disableMetersNow.value;
ensureStereoSinks.value;
defineTs0StereoSilent.value;
defineTestMelody.value;
reassertExclusive.value;
enableMetersClean.value;
verify.value;
)

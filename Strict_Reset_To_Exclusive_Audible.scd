// Strict_Reset_To_Exclusive_Audible.scd
// v0.1
// MD 20250917-1145
//
// Purpose: Deterministic recovery: disable meters, hard-reset MPB to A=current/B=next,
// define stereo ts0 (Silent) and testmelody, enforce Option A, re-enable meters,
// verify A XOR B is true.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, disableMeters, defineStereoTs0, defineTestMelody, doReset, enforceExclusive, enableMeters, verify;

log = { arg s; ("[STRICT] " ++ s).postln };

disableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        AppClock.sched(0.0, { ~gui.enableMeters(false); nil });
        AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
        log.("meters disabled");
    };
};

defineStereoTs0 = {
    Server.default.bind({
        Ndef(\ts0, { Silent.ar(2) });  // NEXT-safe, stereo
        Ndef(\ts0).ar(2);
    });
    log.("\\ts0 set to stereo Silent");
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
    log.("\\testmelody ensured (stereo)");
};

doReset = {
    // Reset reinitialises chainA/B lists and calls the class logic that enforces exclusivity at end.
    ~mpb.reset;
    log.("mpb.reset done");
};

enforceExclusive = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;                        // MPB already enforces Option A post-play
    ~mpb.enforceExclusiveCurrentOptionA(0.1); // belt-and-braces
    log.("Option A exclusivity asserted");
};

enableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(true);             // guards for AR buses and re-sends SynthDefs
        log.("meters re-enabled");
    };
};

verify = {
    AppClock.sched(0.30, {
        var a = Ndef(\chainA).isPlaying;
        var b = Ndef(\chainB).isPlaying;
        ("[STRICT] [PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

disableMeters.value;
defineStereoTs0.value;
defineTestMelody.value;
doReset.value;
enforceExclusive.value;
enableMeters.value;
verify.value;
)

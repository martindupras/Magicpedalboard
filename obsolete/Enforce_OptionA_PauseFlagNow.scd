// Enforce_OptionA_PauseFlagNow.scd
// v0.3
// MD 20250917-1216
//
// Purpose: Deterministic exclusivity for both audio *and* flags.
//          - mold sinks to stereo
//          - set NEXT source to Silent.ar(2)
//          - stop + pause NEXT to drop monitor flag
//          - small retry loop (max 6) with short waits
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, curSink, nextSink, tries, maxTries, waitS, dropFlag;

log = { arg s; ("[X-ENFORCE] " ++ s).postln };

if(~mpb.isNil) { "[X-ENFORCE] ~mpb is nil".warn; ^nil };

curSink  = ~mpb.currentChain[0];
nextSink = ~mpb.nextChain[0];
tries    = 0; maxTries = 6; waitS = 0.08;

log.("meters off (if GUI present)");
if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
    AppClock.sched(0.00, { ~gui.enableMeters(false); nil });
    AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
};

// pin stereo + enforce Option A once
Server.default.bind({
    // shape first
    Ndef(curSink ).mold(2, \audio); Ndef(nextSink).mold(2, \audio);

    // robust CURRENT
    Ndef(curSink,  { \in.ar(2) }); Ndef(curSink ).ar(2); Ndef(curSink ).fadeTime_(0.10);
    if(Ndef(curSink).isPlaying.not) { Ndef(curSink).play(numChannels: 2) };

    // NEXT: hard silence at source + stop
    Ndef(nextSink, { Silent.ar(2) }); Ndef(nextSink).ar(2); Ndef(nextSink).fadeTime_(0.01);
    Ndef(nextSink).stop;
});

// retry loop: if NEXT still reports playing, clear->reset Silent, pause, re-check
Routine({
    var still;
    dropFlag = {
        Server.default.bind({
            Ndef(nextSink).clear(0);            // drop any lingering node
            Ndef(nextSink, { Silent.ar(2) });   // re-assert Silent source
            Ndef(nextSink).ar(2);
            Ndef(nextSink).pause;               // ensure monitor flag false
        });
    };
    while({
        still = Ndef(nextSink).isPlaying;
        (still and: { tries < maxTries })
    }, {
        tries = tries + 1;
        dropFlag.();
        waitS.wait;
    });

    // meters back on
    AppClock.sched(0.00, {
        if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(true) };
        ("[X-ENFORCE] [PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        nil
    });
}).play(SystemClock);
)

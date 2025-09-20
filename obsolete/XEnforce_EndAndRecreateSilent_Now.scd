// XEnforce_EndAndRecreateSilent_Now.scd
// v0.1
// MD 20250917-1305
//
// Purpose: Deterministically enforce Option A for both audio *and* flags.
//          - CURRENT robust \in.ar(2), playing
//          - NEXT: .end (drops monitor + flag), then recreate Silent.ar(2) + mold(2,\audio)
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, curSink, nextSink;
log = { arg s; ("[XEND] " ++ s).postln };

if(~mpb.isNil) { "[XEND] ~mpb is nil".warn; ^nil };

curSink  = ~mpb.currentChain[0];
nextSink = ~mpb.nextChain[0];

if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false) };

Server.default.bind({
    // CURRENT: robust + stereo + playing
    Ndef(curSink,  { \in.ar(2) }); Ndef(curSink).mold(2, \audio);
    if(Ndef(curSink).isPlaying.not) { Ndef(curSink).play(numChannels: 2) };

    // NEXT: end monitor -> recreate as silent stereo (no play)
    Ndef(nextSink).end;                              // flag reliably drops
    Ndef(nextSink, { Silent.ar(2) });                // silent source
    Ndef(nextSink).mold(2, \audio);                  // stereo pin
});

log.("enforced; checking in 250ms…");
AppClock.sched(0.25, {
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
    ("[XEND] [PLAY] A=% B=%".format(a, b)).postln;
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(true) };
    nil
});
)

// Milestone_QueueResponse.scd
// v0.1.1
// MD 2025-09-18 13:56 BST
/*
Purpose
- One-button milestone demo: build the token-harness, run a short token playlist,
  and print concise checks. Use after bring-up.

Style
- var-first; lowercase; no server.sync; GUI on AppClock; audio graph owned by class code.
*/

(
var log, need, ensureSources, verify, run;

log = { arg s; ("[MILESTONE] " ++ s).postln };

need = {
    var ok;
    ok = (~mpb.notNil and: { ~gui.notNil });
    if(ok.not) { "[MILESTONE] ~mpb/~gui are nil. Run the bring-up script first.".warn };
    ^ok;
};

ensureSources = {
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, f, env, pan;
                trig = Impulse.kr(3.2);
                seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                f    = Demand.kr(trig, 0, seq);
                env  = Decay2.kr(trig, 0.01, 0.35);
                pan  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
};

verify = { arg tag = "now";
    var aPlaying, bPlaying;
    aPlaying = Ndef(\chainA).isPlaying;
    bPlaying = Ndef(\chainB).isPlaying;
    ("[PLAY] A=% B=%".format(aPlaying, bPlaying)).postln;
    ~mpb.printChains;
    ("[CHECK] " ++ tag).postln;
};

run = {
    var gap, h, playlist;
    gap = 0.60;

    "CT_TokenQueueHarness.scd".loadRelative;
    ~ctq = ~ctq_makeHarness.(~mpb, ~gui, gap);

    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.setSource(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    verify.("after prime");

    playlist = [
        ["insert","delay"],
        ["switch"],
        ["bypass","delay","on"],
        ["bypass","delay","off"],
        ["switch"]
    ];

    ~ctq[\runPlaylist].(playlist, gap);
    AppClock.sched(playlist.size * gap + 0.8, { verify.("after playlist"); nil });
};

if(need.()) {
    ensureSources.();
    run.();
};
)

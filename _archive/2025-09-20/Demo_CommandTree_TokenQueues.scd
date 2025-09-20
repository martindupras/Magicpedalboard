// Demo_CommandTree_TokenQueues.scd
// v0.1.1
// MD 2025-09-18 13:56 BST

/*
Purpose
- Demonstrate MagicPedalboardNew responding to CommandTree-like token queues, via
  CT_TokenQueueHarness (tokens -> adapter paths -> pedalboard).

Style
- Requires that StartHere_CleanBoot_OneWindow_BringUp.scd has run (so ~mpb, ~gui exist).
- var-first; lowercase; no server.sync; server ops inside Server.default.bind; GUI on AppClock.
*/

(
var ensureSources, primeSources, gap, h, playlistA, playlistB, after;

if(~mpb.isNil or: { ~gui.isNil }) {
    "[DEMO] ~mpb/~gui are nil. Run StartHere_CleanBoot_OneWindow_BringUp.scd first.".warn;
    ^nil;
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

primeSources = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.setSource(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    ~mpb.printChains;
};

gap = 0.60;
"CT_TokenQueueHarness.scd".loadRelative;
h = ~ctq_makeHarness.(~mpb, ~gui, gap);

// Example token playlists
playlistA = [
    ["insert","delay"],
    ["switch"]
];

playlistB = [
    ["bypass","delay","on"],
    ["bypass","delay","off"],
    ["switch"]
];

ensureSources.();
primeSources.();

h[\runPlaylist].(playlistA, gap);
after = (playlistA.size * gap + 1.0).max(1.0);
AppClock.sched(after, {
    h[\runPlaylist].(playlistB, gap);
    nil
});
)

// Run_Milestone_Today.scd
// v0.1.0
// MD 20250918-19:40 BST

/* Purpose
   - Run today's milestone playlist via the adapter, assuming runner v0.6 has already succeeded.
   Style
   - var-first in every closure; lowercase; no server.sync; server ops inside adapter/MPB.
*/

(
var ok, log, guard, apply, run, gap, playlist;

log = { arg s; var t; t = "[TOKENS] " ++ s; t.postln };

ok = (~mpb.notNil) and: { ~gui.notNil } and: { ~ct_applyOSCPathToMPB.notNil };
if(ok.not) {
    "[TOKENS] Missing ~mpb/~gui or adapter. Run StartHere_* and load adapter first.".warn;
    ^nil;
};

guard = {
    var last;
    last = ~mpb.effectiveNext.last;
    if(last == \ts0) { log.("guard: NEXT ends with \\ts0 -> /setSource/testmelody"); ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui) };
};

apply = { arg path;
    var p;
    p = path.asString;
    log.("apply -> " ++ p);
    ~ct_applyOSCPathToMPB.(p, ~mpb, ~gui);
};

run = {
    var idx, count, step;
    ~mpb.setSourcesBoth(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    ~mpb.printChains;
    ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;

    idx = 0; count = playlist.size;
    step = {
        if(idx >= count) {
            AppClock.sched(0.9, {
                ("[PLAY] A=% B=%"
                  .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
                ~mpb.printChains;
                nil
            });
            ^nil
        };
        if(playlist[idx] == "/switch") { guard.value };
        apply.value(playlist[idx]);
        idx = idx + 1;
        AppClock.sched(gap, step);
    };
    AppClock.sched(gap, step);
};

playlist = [
    "/add/delay",
    "/switch",
    "/bypass/delay/on",
    "/bypass/delay/off",
    "/switch"
];

gap = 0.60;
run.value;
)

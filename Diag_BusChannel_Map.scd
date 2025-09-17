// Diag_BusChannel_Map.scd
// v0.1
// MD 20250917-1154
//
// Purpose: Post bus rate + channel count for every Ndef in CURRENT and NEXT
//          effective lists; helps catch mono nodes causing "2→1 wrap".
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, reportList;

log = { arg s; ("[BUS]" ++ " " ++ s).postln };

reportList = { arg label, listSyms;
    var rows;
    rows = listSyms.collect({ arg k;
        var b = Ndef(k).bus;
        var rate = (b.notNil).if({ b.rate }, { \unknown });
        var ch   = (b.notNil).if({ b.numChannels }, { -1 });
        var play = Ndef(k).isPlaying;
        [k, rate, ch, play]
    });
    (label ++ " = " ++ rows.asString).postln;
};

~mpb.printChains;  // also drives your GUI detail view
reportList.("CURRENT", ~mpb.effectiveCurrent);
reportList.("NEXT   ", ~mpb.effectiveNext);
)

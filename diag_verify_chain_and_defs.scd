// diag_verify_chain_and_defs.scd
// v0.1

(
var listOne, listTwo, lastIndex, checkList, report;

if(~mpb.isNil) { "[DIAG] ~mpb is nil".warn; ^nil };

checkList = { arg label, chainList;
    var idx, last, missing;
    if(chainList.isNil) { ("[DIAG] " ++ label ++ ": chain is nil").postln; ^nil };
    last = chainList.size - 1;
    missing = Array.new;
    idx = 1; // processors are 1 .. last-1
    while({ idx < last }, {
        var key = chainList[idx];
        var hasDef = Ndef(key).source.notNil;  // <- definition present?
        if(hasDef.not) { missing = missing.add(key) };
        idx = idx + 1;
    });
    ("[DIAG] " ++ label ++ " = " ++ chainList).postln;
    if(missing.isEmpty) { "[DIAG] all processors have sources".postln }
    { ("[DIAG] missing sources for: " ++ missing).warn };
};

listOne = ~mpb.effectiveCurrent;
listTwo = ~mpb.effectiveNext;

checkList.("CURRENT", listOne);
checkList.("NEXT   ", listTwo);

"[[PLAY]] A=%  B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying).postln;
)

// CTQ_MinHarness_Inline.scd
// v0.1.0
// MD 2025-09-18 14:05 BST

/*Purpose
- Minimal, reliable inline harness to drive MagicPedalboardNew from CommandTree-like token queues
  without relying on a returned dictionary. Good for today's milestone demo.
Style
- tilde vars; var-first in every function/closure; lowercase method names; no server.sync;
  GUI on AppClock; Ndef connections happen inside class code with exact <<> operator.*/


(
// 0) Preconditions and adapter
var need;

need = {
    if(~mpb.isNil or: { ~gui.isNil }) {
        "[CTQ] ~mpb/~gui are nil. Run StartHere_CleanBoot_OneWindow_BringUp.scd first.".warn;
        ^false
    }; ^true
};

if(need.().not) { ^nil };

// load adapter once (defines ~ct_applyOSCPathToMPB)
if(~ct_applyOSCPathToMPB.isNil) {
    "adapter_CommandTree_to_MagicPedalboard.scd".loadRelative;
    "[CTQ] adapter loaded".postln;
} {
    "[CTQ] adapter already present".postln;
};

// 1) Token → path mapper (safe subset for today)
~ctq_tokensToPath = { arg tokensIn;
    var tokens, verb, args, lowerOnOff, result;
    tokens = tokensIn.collect({ arg t; t.asString });
    if(tokens.size <= 0) { ^nil };
    verb = tokens[0].toLower;
    args = if(tokens.size > 1) { tokens.copyRange(1, tokens.size - 1) } { [] };
    result = nil;

    if(verb == "insert" or: { verb == "add" }) {
        if(args.size >= 1) { result = "/add/" ++ args[0] };
    } {
        if(verb == "bypass") {
            if(args.size >= 1) {
                lowerOnOff = if(args.size >= 2) { args[1].toLower } { "on" };
                lowerOnOff = (["on","off","true","false","1","0"].includes(lowerOnOff)).if({
                    if((lowerOnOff == "true") or: { lowerOnOff == "1" }) { "on" } { lowerOnOff }
                }, { "on" });
                result = "/bypass/" ++ args[0] ++ "/" ++ lowerOnOff;
            };
        } {
            if(verb == "setsource" or: { verb == "source" } or: { verb == "setsrc" }) {
                if(args.size >= 1) { result = "/setSource/" ++ args[0] };
            } {
                if(verb == "switch" or: { verb == "commit" }) {
                    result = "/switch";
                } {
                    if(verb == "removeat") {
                        if(args.size >= 1) { result = "/removeAt/" ++ args[0] };
                    } {
                        if(verb == "swap") {
                            if(args.size >= 2) { result = "/swap/" ++ args[0] ++ "/" ++ args[1] };
                        } {
                            result = nil; // unmapped today
                        };
                    };
                };
            };
        };
    };
    ^result;
};

// 2) Guard so /switch never lands on \ts0
~ctq_guardSwitchAudible = {
    var effNext, last;
    effNext = ~mpb.effectiveNext;
    last = effNext[effNext.size - 1];
    if(last == \ts0) {
        "[CTQ] NEXT ends with \\ts0; injecting /setSource/testmelody before /switch".postln;
        ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
    };
};

// 3) Apply a single token array
~ctq_applyOneTokens = { arg tokens;
    var path;
    path = ~ctq_tokensToPath.(tokens);
    if(path.isNil) {
        ("[CTQ] unmapped tokens: " ++ tokens.asString).postln; ^nil
    };
    if(path == "/switch") { ~ctq_guardSwitchAudible.() };
    ("[CTQ] apply " ++ tokens.asString ++ " -> " ++ path).postln;
    ~ct_applyOSCPathToMPB.(path, ~mpb, ~gui);
};

// 4) Run a playlist of token arrays with a gap (Routine on AppClock)
~ctq_runPlaylist = { arg listOfTokenLists, gapSeconds = 0.6;
    var routineLocal, gap;
    gap = gapSeconds ? 0.6;
    routineLocal = Routine({
        var i;
        i = 0;
        while({ i < listOfTokenLists.size }, {
            ~ctq_applyOneTokens.( listOfTokenLists[i] );
            gap.wait;
            i = i + 1;
        });
        "[CTQ] done.".postln;
    });
    routineLocal.play(AppClock);
    ^routineLocal
};

// 5) Quick prime (today we want audible switches using \testmelody)
~ctq_primeSources = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.setSource(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    ~mpb.printChains;
    AppClock.sched(0.25, {
        ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        nil
    });
};

"[CTQ] inline harness ready".postln;
)

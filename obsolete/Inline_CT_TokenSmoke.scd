// Inline_CT_TokenSmoke.scd
// v0.1.2
// MD 2025-09-18 14:12 BST

// Purpose:
// - Demonstrate that MagicPedalboardNew responds to CommandTree-shaped *token* queues today
//   without external file loads (audible and logged).
// - Flow: ensure sources -> tiny token-harness -> prime sources -> apply tokens -> verify.
// Style:
// - var-first in every function/closure; lowercase names; no server.sync;
// - all server ops inside Server.default.bind; GUI ops on AppClock; NodeProxy connections
//   remain inside class rebuilds using the exact <<> operator.

(
var log, need, ensureSources, tokensToPath, isNextSilent, guardSwitchAudible,
    applyOneTokens, runPlaylist, doRun, playlist, gap;

// --- logging helper (var-first inside) ---
log = { arg s;
    var str;
    str = "[TOKENS] " ++ s;
    str.postln;
};

// --- precondition guard (var-first inside) ---
need = {
    var ok;
    ok = (~mpb.isNil.not) and: { ~gui.isNil.not };
    if(ok.not) {
        "[TOKENS] ~mpb/~gui are nil. Run StartHere_CleanBoot_OneWindow_BringUp.scd first.".warn;
    };
    ok
};

// --- ensure generated sources exist (no SoundIn) ---
ensureSources = {
    var define;
    define = {
        var made;
        made = false;
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, f, env, pan;
                trig = Impulse.kr(3.2);
                seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                f    = Demand.kr(trig, 0, seq);
                env  = Decay2.kr(trig, 0.01, 0.35);
                pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
            made = true;
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) });  Ndef(\ts0).ar(2);
        made
    };
    Server.default.bind({ define.value; });
};

// --- token -> canonical path mapping understood by the adapter ---
tokensToPath = { arg tokensIn;
    var tokens, verb, args, result, onOff;
    tokens = tokensIn.collect({ arg t; t.asString });
    if(tokens.size <= 0) { ^nil };
    verb = tokens[0].toLower;
    args = if(tokens.size > 1) { tokens.copyRange(1, tokens.size - 1) } { [] };
    result = nil;

    if(verb == "insert" or: { verb == "add" }) {
        if(args.size >= 1) { result = "/add/" ++ args[0] };
    }{
        if(verb == "bypass") {
            onOff = if(args.size >= 2) { args[1].toLower } { "on" };
            onOff = if(#["on","off","true","false","1","0"].includes(onOff)) {
                if((onOff == "true") or: { onOff == "1" }) { "on" } { onOff }
            } { "on" };
            if(args.size >= 1) { result = "/bypass/" ++ args[0] ++ "/" ++ onOff };
        }{
            if(verb == "setsource" or: { verb == "source" } or: { verb == "setsrc" }) {
                if(args.size >= 1) { result = "/setSource/" ++ args[0] };
            }{
                if(verb == "removeat") {
                    if(args.size >= 1) { result = "/removeAt/" ++ args[0] };
                }{
                    if(verb == "swap") {
                        if(args.size >= 2) { result = "/swap/" ++ args[0] ++ "/" ++ args[1] };
                    }{
                        if(verb == "switch" or: { verb == "commit" }) {
                            result = "/switch";
                        }{
                            result = nil;
                        };
                    };
                };
            };
        };
    };
    ^result
};

// --- guard so /switch never lands on a silent NEXT (\ts0 tail) ---
isNextSilent = {
    var effNext, last;
    effNext = ~mpb.effectiveNext;
    last = effNext[effNext.size - 1];
    ^(last == \ts0)
};

guardSwitchAudible = {
    var needed;
    needed = isNextSilent.value;
    if(needed) {
        log.("NEXT ends with \\ts0; injecting /setSource/testmelody before /switch");
        if(~ct_applyOSCPathToMPB.notNil) {
            ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
        }{
            "[TOKENS] adapter missing; cannot auto-fix source".warn;
        };
    };
};

// --- apply one token step via your existing adapter ---
applyOneTokens = { arg tokens;
    var path;
    path = tokensToPath.value(tokens);
    if(path.isNil) {
        log.("unmapped tokens: " ++ tokens.asString);
        ^nil;
    };
    if(path == "/switch") { guardSwitchAudible.value };
    if(~ct_applyOSCPathToMPB.notNil) {
        log.("apply " ++ tokens.asString ++ "  -> " ++ path);
        ~ct_applyOSCPathToMPB.(path, ~mpb, ~gui);
    }{
        ("[TOKENS] adapter missing; would apply " ++ path).warn;
    };
};

// --- run a playlist of token steps with a gap (AppClock) ---
runPlaylist = { arg listOfTokenLists, gapSeconds = 0.6;
    var rt;
    rt = Routine({
        var i;
        i = 0;
        while({ i < listOfTokenLists.size }, {
            applyOneTokens.value(listOfTokenLists[i]);
            gapSeconds.wait;
            i = i + 1;
        });
        log.("done.");
    }).play(AppClock);
    ^rt
};

// --- end-to-end demo: prime sources (today), run, verify ---
doRun = {
    var verify;
    gap = 0.60;

    // For today: both chains end with \testmelody; NEXT stays silent at sink (Option A).
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.setSource(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);

    // Example playlist: insert delay -> switch -> bypass on -> bypass off -> switch back
    playlist = [
        ["insert","delay"],
        ["switch"],
        ["bypass","delay","on"],
        ["bypass","delay","off"],
        ["switch"]
    ];

    runPlaylist.value(playlist, gap);

    verify = {
        var a, b;
        a = Ndef(\chainA).isPlaying; b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=% B=%".format(a, b)).postln;
        ~mpb.printChains;
    };

    AppClock.sched(playlist.size * gap + 0.9, { verify.value; nil });
};

// --- go ---
if(need.value) {
    ensureSources.value;
    doRun.value;
};
)

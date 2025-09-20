// CT_TokenQueue_Milestone_ClockChain.scd
// v0.3.0
// MD 2025-09-18 15:08 BST

// Purpose:
// - Demonstrate (audibly & with logs) that MagicPedalboardNew responds to CommandTree-like
//   *token* queues today, sequenced without Routine/Task (AppClock-only, chain scheduling).
// - Flow: ensure sources -> load adapter via absolute path -> prime sources -> token playlist -> verify.
// Style:
// - var-first in every function/closure; lowercase names; no server.sync;
// - all server ops inside Server.default.bind; GUI ops on AppClock;
// - NodeProxy connections remain inside class rebuilds using the exact <<> operator.

(
var here, loadLocal, log, need, ensureSources, tokensToPath, isNextSilent, guardSwitchAudible;
var applyOneTokens, startClockChain, stopClockChain, verifyAtEnd, startDemo;
var playlist, gap, gen;

// --- path helper: load sibling files from this script's folder ---
here = PathName(thisProcess.nowExecutingPath).pathOnly;
loadLocal = { arg leafName;
    var full;
    full = here +/+ leafName;
    full.load;
};

// --- logging helper ---
log = { arg s;
    var str;
    str = "[TOKENS] " ++ s;
    str.postln;
};

// --- precondition guard (requires bring-up so ~mpb / ~gui exist) ---
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

// --- load adapter robustly (absolute path) ---
if(~ct_applyOSCPathToMPB.isNil) {
    loadLocal.value("adapter_CommandTree_to_MagicPedalboard.scd");
    log.("adapter loaded");
} {
    log.("adapter already present");
};

// --- token -> canonical path mapping (what the adapter expects) ---
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
        ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
    };
};

// --- apply one token step via the adapter ---
applyOneTokens = { arg tokens;
    var path;
    path = tokensToPath.value(tokens);
    if(path.isNil) {
        log.("unmapped tokens: " ++ tokens.asString);
        ^nil;
    };
    if(path == "/switch") { guardSwitchAudible.value };
    log.("apply " ++ tokens.asString ++ "  -> " ++ path);
    ~ct_applyOSCPathToMPB.(path, ~mpb, ~gui);
};

// --- STOP any previous chain by bumping a generation counter ---
stopClockChain = {
    var old;
    old = ~ctq_gen ? 0;
    ~ctq_gen = old + 1;
    log.("chain stopped (gen=" ++ ~ctq_gen ++ ")");
};

// --- Start a playlist using AppClock chaining; no Routine/Task involved ---
startClockChain = { arg listOfTokenLists, gapSeconds = 0.6;
    var startGen, total, stepFn, scheduleNext, index;

    // bump generation to cancel older scheduled callbacks
    stopClockChain.value;

    startGen = ~ctq_gen;
    total = listOfTokenLists.size;
    index = 0;

    stepFn = {
        var tokens, stillMine;
        tokens = listOfTokenLists[index];
        stillMine = (~ctq_gen == startGen);
        if(stillMine.not) { ^nil }; // cancelled

        applyOneTokens.value(tokens);

        index = index + 1;
        if(index < total) {
            scheduleNext.value;
        }{
            log.("done.");
        };
    };

    scheduleNext = {
        var delay;
        delay = gapSeconds ? 0.6;
        AppClock.sched(delay, {
            var stillMine;
            stillMine = (~ctq_gen == startGen);
            if(stillMine) { stepFn.value } { nil };
        });
    };

    // kick off immediately
    AppClock.sched(0.0, {
        var stillMine;
        stillMine = (~ctq_gen == startGen);
        if(stillMine) { stepFn.value } { nil };
    });

    ^startGen
};

// --- verify tail ---
verifyAtEnd = {
    var a, b;
    a = Ndef(\chainA).isPlaying;
    b = Ndef(\chainB).isPlaying;
    ("[PLAY] A=% B=%".format(a, b)).postln;
    ~mpb.printChains;
};

// --- end-to-end run ---
startDemo = {
    var ok, runGen, tailDelay;
    ok = need.value;
    if(ok.not) { ^nil };

    ensureSources.value;

    // For today: both chains end with \testmelody; NEXT remains silent at sink (Option A).
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.setSource(\testmelody);
    ~mpb.enforceExclusiveCurrentOptionA(0.1);

    // Example playlist
    playlist = [
        ["insert","delay"],
        ["switch"],
        ["bypass","delay","on"],
        ["bypass","delay","off"],
        ["switch"]
    ];
    gap = 0.60;

    runGen = startClockChain.value(playlist, gap);

    // verify near the end; computed tail = steps * gap + small margin
    tailDelay = playlist.size * gap + 0.9;
    AppClock.sched(tailDelay, {
        var stillMine;
        stillMine = (~ctq_gen == runGen);
        if(stillMine) { verifyAtEnd.value };
        nil
    });
};

// --- go ---
startDemo.value;
)

// CT_TokenQueueHarness.scd
// v0.1.1
// MD 2025-09-18 13:56 BST

/*
Purpose
- Minimal harness that accepts CommandTree-like token arrays (e.g. ["insert","delay"])
  and maps them to canonical OSC-style paths understood by your existing adapter
  (~ct_applyOSCPathToMPB). Adds a guard so "/switch" never lands on a silent NEXT.

Style
- tilde vars allowed at top level.
- var-first in every function/closure; lowercase method names.
- no server.sync; all server ops inside Server.default.bind.
- This file does not manipulate Ndefs directly; MagicPedalboardNew handles audio and <<>.
*/

(
// Public factory: ~ctq_makeHarness.(mpb, gui, secondsBetween)
// Returns an IdentityDictionary with keys:
//  - \applyOneTokens : { |tokens| ... }         // tokens = ["insert","delay"] etc.
//  - \runPlaylist    : { |listOfTokenLists, gapSeconds| ... }
//  - \tokensToPath   : { |tokens| ... }         // mapping only
//  - \stop           : { ... }                  // stop current run (if any)

var makeHarness;
makeHarness = { arg mpb, gui, secondsBetween = 0.5;
    var state, log, ensureAdapter, tokensToPath, isNextSilent, guardSwitchAudible;
    var applyOneTokens, runPlaylist, stop, runner;

    log = { arg s;
        var msg;
        msg = "[CTQ] " ++ s;
        msg.postln;
    };

    ensureAdapter = {
        var loadedAlready;
        loadedAlready = (~ct_applyOSCPathToMPB.notNil);
        if(loadedAlready.not) {
            "adapter_CommandTree_to_MagicPedalboard.scd".loadRelative;
            log.("adapter loaded");
        }{
            log.("adapter already present");
        };
    };

    tokensToPath = { arg tokensIn;
        var tokens, verb, args, result, lowerOnOff;
        tokens = tokensIn.collect({ arg t; t.asString });
        if(tokens.size <= 0) { ^nil };
        verb = tokens[0].toLower;
        args = if(tokens.size > 1) { tokens.copyRange(1, tokens.size - 1) } { [] };
        result = nil;

        if(verb == "insert" or: { verb == "add" }) {
            if(args.size >= 1) { result = "/add/" ++ args[0] };
        }{
            if(verb == "bypass") {
                if(args.size >= 1) {
                    lowerOnOff = if(args.size >= 2) { args[1].toLower } { "on" };
                    lowerOnOff = (["on","off","true","false","1","0"].includes(lowerOnOff)).if({
                        if((lowerOnOff == "true") or: { lowerOnOff == "1" }) { "on" } { lowerOnOff }
                    },{
                        "on"
                    });
                    result = "/bypass/" ++ args[0] ++ "/" ++ lowerOnOff;
                };
            }{
                if(verb == "setsource" or: { verb == "source" } or: { verb == "setsrc" }) {
                    if(args.size >= 1) { result = "/setSource/" ++ args[0] };
                }{
                    if(verb == "switch" or: { verb == "commit" }) {
                        result = "/switch";
                    }{
                        if(verb == "removeat") {
                            if(args.size >= 1) { result = "/removeAt/" ++ args[0] };
                        }{
                            if(verb == "swap") {
                                if(args.size >= 2) { result = "/swap/" ++ args[0] ++ "/" ++ args[1] };
                            }{
                                result = nil;
                            };
                        };
                    };
                };
            };
        };
        ^result;
    };

    isNextSilent = {
        var effNext, last;
        effNext = mpb.effectiveNext;
        last = effNext[effNext.size - 1];
        ^(last == \ts0);
    };

    guardSwitchAudible = {
        var needed;
        needed = isNextSilent.();
        if(needed) {
            log.("NEXT ends with \\ts0; injecting /setSource/testmelody before /switch");
            ~ct_applyOSCPathToMPB.("/setSource/testmelody", mpb, gui);
        };
    };

    applyOneTokens = { arg tokens;
        var path;
        path = tokensToPath.(tokens);
        if(path.isNil) {
            log.("unmapped tokens: " ++ tokens.asString);
            ^nil;
        };
        if(path == "/switch") { guardSwitchAudible.() };
        ~ct_applyOSCPathToMPB.(path, mpb, gui);
    };

    runPlaylist = { arg listOfTokenLists, gapSeconds;
        var gapLocal, routineLocal;
        gapLocal = gapSeconds ? secondsBetween;
        routineLocal = Routine({
            var i, step;
            i = 0;
            while({ i < listOfTokenLists.size }, {
                step = listOfTokenLists[i];
                log.("apply " ++ step.asString);
                applyOneTokens.(step);
                gapLocal.wait;
                i = i + 1;
            });
            log.("done.");
        });
        runner = routineLocal.play(AppClock);
        ^runner;
    };

    stop = {
        if(runner.notNil) { runner.stop; runner = nil };
        log.("stopped.");
    };

    ensureAdapter.();
    state = IdentityDictionary[
        \applyOneTokens -> applyOneTokens,
        \runPlaylist    -> runPlaylist,
        \tokensToPath   -> tokensToPath,
        \stop           -> stop
    ];
    ^state;
};

~ctq_makeHarness = makeHarness;
)

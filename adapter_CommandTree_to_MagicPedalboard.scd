// adapter_commandtree_to_magicpedalboard.scd
// v0.3.1
// MD 20250916-14:49

(

var alreadyWrapped;

~ct_knownVerbs = #[\add, \bypass, \removeAt, \swap, \clear, \setSource, \switch];
~ct_knownProcs = #[\delay, \chorus, \tremolo, \reverb, \drive, \transpose, \hex, \audio, \filters, \delays, \noise, \oscillators];
~ct_log = { arg messageString; ("[CT->MPB] " ++ messageString).postln };

~ct_normalizeTokens = { arg oscPathString;
    var rawTokens, tokens;
    rawTokens = oscPathString.asString.split($/).reject({ arg one; one.isEmpty });
    tokens = if(rawTokens.size > 0 and: { rawTokens[0].asSymbol == \commands }) {
        rawTokens.copyRange(1, rawTokens.size - 1)
    }{
        rawTokens
    };
    tokens.collect({ arg one; one.asSymbol })
};

~ct_applyOneVerb = { arg tokens, pedalboard, gui;
    var consumed, verb, params, indexCount;
    consumed = 0;
    if(tokens.isEmpty) { ^0 };
    verb = tokens[0];
    params = tokens.copyRange(1, tokens.size - 1);

    switch(verb,

/*        \add, {
            if(params.size >= 1) { pedalboard.add(params[0]); ~ct_log.("add " ++ params[0]); consumed = 2; }
            { ~ct_log.("add: missing processor"); consumed = 1; };
        },*/
\add, {
    if(params.size >= 1) {
        var procSym;
        procSym = params[0].asSymbol;
        ~ct_ensureProcessor.(procSym);        // <-- ensure Ndef exists and is stereo
        pedalboard.add(procSym);
        ~ct_log.("add " ++ procSym);
        consumed = 2;
    }{
        ~ct_log.("add: missing processor"); consumed = 1;
    };
},

		\bypass, {
            if(params.size >= 2) {
                var procSym, stateBool;
                procSym = params[0];
                stateBool = (params[1] == \on);
                pedalboard.bypass(procSym, stateBool);
                ~ct_log.("bypass " ++ procSym ++ " -> " ++ stateBool);
                consumed = 3;
            }{ ~ct_log.("bypass: need proc and on/off"); consumed = 1; };
        },
        \removeAt, {
            if(params.size >= 1) {
                var indexInteger;
                indexInteger = params[0].asString.asInteger;
                pedalboard.removeAt(indexInteger);
                ~ct_log.("removeAt " ++ indexInteger);
                consumed = 2;
            }{ ~ct_log.("removeAt: need index"); consumed = 1; };
        },
        \swap, {
            if(params.size >= 2) {
                var aIndex, bIndex;
                aIndex = params[0].asString.asInteger;
                bIndex = params[1].asString.asInteger;
                pedalboard.swap(aIndex, bIndex);
                ~ct_log.("swap " ++ aIndex ++ " <-> " ++ bIndex);
                consumed = 3;
            }{ ~ct_log.("swap: need two indices"); consumed = 1; };
        },
        \clear, { pedalboard.clearChain; ~ct_log.("clear NEXT"); consumed = 1; },
        \setSource, {
            if(params.size >= 1) { pedalboard.setSource(params[0]); ~ct_log.("setSource " ++ params[0]); consumed = 2; }
            { ~ct_log.("setSource: missing symbol"); consumed = 1; };
        },
        \switch, { pedalboard.switchChain(0.12); ~ct_log.("switch crossfade"); consumed = 1; },
        {
            if(~ct_knownProcs.includes(verb)) {
                pedalboard.add(verb); ~ct_log.("add (fallback) " ++ verb); consumed = 1;
            }{ ~ct_log.("unknown verb: " ++ verb); consumed = 1; };
        }
    );
    consumed
};

~ct_applyOSCPathToMPB = { arg oscPathString, pedalboard, gui;
    var tokens, tokenIndex, consumedNow, appliedCount, tailTokens;
    tokens = ~ct_normalizeTokens.(oscPathString);
    if(tokens.isEmpty) { ~ct_log.("empty OSC path"); ^false };
    ~ct_log.("path=" ++ oscPathString ++ "  tokens=" ++ tokens);
    tokenIndex = 0; appliedCount = 0;
    while({ tokenIndex < tokens.size }, {
        tailTokens = tokens.copyRange(tokenIndex, tokens.size - 1);
        consumedNow = ~ct_applyOneVerb.(tailTokens, pedalboard, gui);
        if(consumedNow <= 0) { consumedNow = 1 };
        tokenIndex = tokenIndex + consumedNow;
        appliedCount = appliedCount + 1;
    });
    appliedCount > 0
};

~ct_applyQueueToMPBFromCM = { arg commandManager, pedalboard, gui;
    var oscPathString, listSnapshot;
    listSnapshot = commandManager.midiManager.queue.commandList;
    ~ct_log.("queue snapshot: " ++ listSnapshot);
    oscPathString = commandManager.midiManager.queue.exportAsOSCPath;
    ~ct_log.("exported path: " ++ oscPathString);
    ~ct_applyOSCPathToMPB.(oscPathString, pedalboard, gui);
    commandManager.midiManager.queue.clear;
    true
};

~ct_sendAndApply = { arg commandManager, pedalboard, gui;
    ~ct_applyQueueToMPBFromCM.(commandManager, pedalboard, gui);
};



// 0) Capture the original adapter exactly once so we can delegate non-switch paths safely.
alreadyWrapped = (~ct_applyOSCPathToMPB_raw.notNil);
if(alreadyWrapped.not) {
    ~ct_applyOSCPathToMPB_raw = ~ct_applyOSCPathToMPB;
};

// 1) Helper: guard NEXT tail before switch, then audit after fade and recover if needed.

~ct_switchWithRecovery = { arg mpb, gui, fade = 0.12;
    var ensureNextAudible, auditAndFix, fadeLocal, myGen;

    // initialize state vars once
    if(~ct_switchBusy.isNil) { ~ct_switchBusy = false };
    if(~ct_switchGen.isNil)  { ~ct_switchGen  = 0     };

    // prevent overlapping switches (re-entrant safe)
    if(~ct_switchBusy == true) {
        "[CT->MPB] switch ignored (busy)".postln;
        ^nil;
    };

    ~ct_switchBusy = true;
    ~ct_switchGen  = ~ct_switchGen + 1;
    myGen          = ~ct_switchGen;

    ensureNextAudible = {
        var effNext, last;
        effNext = mpb.effectiveNext;
        last    = effNext[effNext.size - 1];
        if(last == \ts0) {
            "[CT->MPB] guard: NEXT tail \\ts0 -> /setSource/testmelody".postln;
            // Use the original adapter to avoid wrapping recursion
            ~ct_applyOSCPathToMPB_raw.("/setSource/testmelody", mpb, gui);
        };
    };

    auditAndFix = {
        var a, b;
        // ignore stale audits from older generations
        if(~ct_switchGen != myGen) { ^nil };

        a = Ndef(\chainA).isPlaying;
        b = Ndef(\chainB).isPlaying;

        if((a or: { b }).not) {
            "[CT->MPB] post-switch audit: both stopped -> recovering CURRENT & OptionA".postln;
            mpb.playCurrent;
            mpb.enforceExclusiveCurrentOptionA(0.1);
        };
        ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;

        // release busy flag only after our generation’s audit runs
        ~ct_switchBusy = false;
    };

    fadeLocal = fade ? 0.12;

    ensureNextAudible.value;
    mpb.switchChain(fadeLocal);

    // schedule audit a bit after the fade completes; protect with generation check
    AppClock.sched(fadeLocal + 0.20, { auditAndFix.value; nil });
};


/*~ct_switchWithRecovery = { arg mpb, gui, fade = 0.12;
    var ensureNextAudible, auditAndFix, fadeLocal;

    // Ensure NEXT ends with an audible source before switching.
    ensureNextAudible = {
        var effNext, last;
        effNext = mpb.effectiveNext;
        last = effNext[effNext.size - 1];
        if(last == \ts0) {
            "[CT->MPB] guard: NEXT tail \\ts0 -> /setSource/testmelody".postln;
            ~ct_applyOSCPathToMPB_raw.("/setSource/testmelody", mpb, gui);
        };
    };

    // After the crossfade, check A/B; if both false, make CURRENT audible and re-enforce Option A.
    auditAndFix = {
        var a, b;
        a = Ndef(\chainA).isPlaying;
        b = Ndef(\chainB).isPlaying;
        if((a or: { b }).not) {
            "[CT->MPB] post-switch audit: both stopped -> recovering CURRENT & OptionA".postln;
            mpb.playCurrent;
            mpb.enforceExclusiveCurrentOptionA(0.1);
        };
        ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    };

    fadeLocal = fade ? 0.12;
    ensureNextAudible.value;
    mpb.switchChain(fadeLocal);
    AppClock.sched(fadeLocal + 0.20, { auditAndFix.value; nil });
};*/

// 2) Wrapper adapter: intercept ONLY "/switch"; delegate all other paths to the original.
~ct_applyOSCPathToMPB = { arg path, mpb, gui;
    var p, f;
    p = path.asString;
    if(p == "/switch") {
        f = 0.12; // keep your usual fade; adjust if you use a different default
        ~ct_switchWithRecovery.(mpb, gui, f);
    }{
        ~ct_applyOSCPathToMPB_raw.(p, mpb, gui);
    };
};


~ct_ensureProcessor = { arg keySym;
    var k;
    k = keySym.asSymbol;

    Server.default.bind({
        var defineDelay, defineBypass, defineIdentity;

        defineIdentity = {
            var make;
            make = {
                // pass-through “processor” that keeps stereo and \in.ar(2)
                // used as a safe fallback for unknown keys
                Ndef(k, { var sig; sig = \in.ar(2); sig });
                Ndef(k).ar(2);
            };
            if(Ndef(k).source.isNil) { make.value } { Ndef(k).ar(2) };
        };

        defineDelay = {
            var make;
            make = {
                // simple stereo delay: read from \in.ar(2) → short delay → mix
                Ndef(\delay, {
                    var sig, del, time, fb, mix;
                    sig  = \in.ar(2);
                    time = 0.25;   // s
                    fb   = 0.25;
                    mix  = 0.5;
                    del  = DelayC.ar(sig + (LocalIn.ar(2) * fb), 1.0, time);
                    LocalOut.ar(del);
                    XFade2.ar(sig, del, (mix * 2 - 1).clip(-1, 1))
                });
                Ndef(\delay).ar(2);
            };
            if(Ndef(\delay).source.isNil) { make.value } { Ndef(\delay).ar(2) };
        };

        defineBypass = {
            // A named pass-through “processor” you might use in test chains
            var make;
            make = {
                Ndef(\bypass, { \in.ar(2) });
                Ndef(\bypass).ar(2);
            };
            if(Ndef(\bypass).source.isNil) { make.value } { Ndef(\bypass).ar(2) };
        };

        // choose per key
        if(k == \delay) { defineDelay.value }
        { if(k == \bypass) { defineBypass.value } { defineIdentity.value } };
    });
};


)

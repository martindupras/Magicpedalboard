// adapter_commandtree_to_magicpedalboard.scd
// v0.3
// MD 20250916-1038

(
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
        \add, {
            if(params.size >= 1) { pedalboard.add(params[0]); ~ct_log.("add " ++ params[0]); consumed = 2; }
            { ~ct_log.("add: missing processor"); consumed = 1; };
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
)

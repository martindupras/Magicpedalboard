// adapter_commandtree_to_magicpedalboard.scd
// v0.2
// MD 20250916-0848

(
~ct_knownVerbs = #[\add, \bypass, \removeAt, \swap, \clear, \setSource, \switch];
~ct_knownProcs = #[\delay, \chorus, \tremolo, \reverb, \drive, \transpose, \hex, \audio, \filters, \delays, \noise, \oscillators];
// ^ extend this list as you add processors to your library/tree
~ct_applyOSCPathToMPB = { arg oscPathString, pedalboard, gui;
    var tokens, verb, params, postMsg;

    postMsg = { arg text; ("[CT->MPB] " ++ text).postln };

    tokens = oscPathString.asString.split($/).reject({ arg one; one.isEmpty });
    if (tokens.isEmpty) { postMsg.("empty OSC path"); ^false };

    // smart fallback: if first token is a processor (not a verb), treat as add/<proc>
    if (~ct_knownVerbs.includes(tokens[0].asSymbol).not and: { ~ct_knownProcs.includes(tokens[0].asSymbol) }) {
        tokens = ["add"] ++ tokens;
    };

    verb = tokens[0].asSymbol;
    params = tokens.copyRange(1, tokens.size - 1).collect({ arg one; one.asSymbol });

    postMsg.("path=" ++ oscPathString ++ "  -> verb=" ++ verb ++ " params=" ++ params);

    switch(verb,
        \add, {
            if (params.size >= 1) { pedalboard.add(params[0]); postMsg.("add " ++ params[0]) }
            { postMsg.("add: missing processor") };
        },
        \bypass, {
            var stateBool = (params.size >= 2) and: { params[1] == \on };
            if (params.size >= 1) { pedalboard.bypass(params[0], stateBool); postMsg.("bypass " ++ params[0] ++ " -> " ++ stateBool) }
            { postMsg.("bypass: need proc and on/off") };
        },
        \removeAt, {
            if (params.size >= 1) { pedalboard.removeAt(params[0].asString.asInteger); postMsg.("removeAt " ++ params[0]) }
            { postMsg.("removeAt: need index") };
        },
        \swap, {
            if (params.size >= 2) {
                pedalboard.swap(params[0].asString.asInteger, params[1].asString.asInteger);
                postMsg.("swap " ++ params[0] ++ " <-> " ++ params[1]);
            } { postMsg.("swap: need two indices") };
        },
        \clear, { pedalboard.clearChain; postMsg.("clear NEXT") },
        \setSource, {
            if (params.size >= 1) { pedalboard.setSource(params[0]); postMsg.("setSource " ++ params[0]) }
            { postMsg.("setSource: missing symbol") };
        },
        \switch, { pedalboard.switchChain(0.12); postMsg.("switch crossfade") },
        { postMsg.("unknown verb: " ++ verb) }
    );

    true
};

~ct_applyQueueToMPBFromCM = { arg commandManager, pedalboard, gui;
    var oscPathString;
    oscPathString = commandManager.midiManager.queue.exportAsOSCPath; // your queue method
    ~ct_applyOSCPathToMPB.(oscPathString, pedalboard, gui);
    commandManager.midiManager.queue.clear;
    true
};

~ct_sendAndApply = { arg commandManager, pedalboard, gui;
    var sendMode;
    sendMode = commandManager.midiManager.modes[\send];
    commandManager.midiManager.setMode(sendMode);   // will export & clear inside your code
    ~ct_applyQueueToMPBFromCM.(commandManager, pedalboard, gui);
};


)

// adapter_CommandTree_to_MagicPedalboard.scd
// v0.1
// MD 20250916-0832

(
~ct_applyOSCPathToMPB = { arg oscPathString, pedalboard, gui;
    var tokens, tokenCount, verb, params, successFlag;
    var postMsg;

    postMsg = { arg text; ("[CT->MPB] " ++ text).postln };

    // Parse "/verb/arg1/arg2" into tokens ["verb","arg1","arg2"]
    tokens = oscPathString.asString.split($/).reject({ arg one; one.isEmpty });
    tokenCount = tokens.size;

    if (tokenCount == 0) {
        postMsg.("empty OSC path; nothing to apply.");
        ^false
    };

    verb = tokens[0].asSymbol;
    params = tokens.copyRange(1, tokenCount - 1).collect({ arg one; one.asSymbol });

    postMsg.("path=" ++ oscPathString ++ "  verb=" ++ verb ++ "  params=" ++ params);

    // Map verbs to MagicPedalboardNew actions (NEXT by default; switch affects CURRENT)
    switch(verb,
        \add, {
            var procSym;
            if (params.size >= 1) {
                procSym = params[0];
                pedalboard.add(procSym);
                postMsg.("add " ++ procSym);
            } {
                postMsg.("add: missing processor symbol");
            };
        },
        \bypass, {
            var procSym, stateSym, stateBool;
            if (params.size >= 2) {
                procSym = params[0];
                stateSym = params[1];
                stateBool = (stateSym == \on);
                pedalboard.bypass(procSym, stateBool);
                postMsg.("bypass " ++ procSym ++ " -> " ++ stateBool);
            } {
                postMsg.("bypass: need proc and on/off");
            };
        },
        \removeAt, {
            var indexInteger;
            if (params.size >= 1) {
                indexInteger = params[0].asString.asInteger;
                pedalboard.removeAt(indexInteger);
                postMsg.("removeAt " ++ indexInteger);
            } {
                postMsg.("removeAt: need index");
            };
        },
        \swap, {
            var aIndex, bIndex;
            if (params.size >= 2) {
                aIndex = params[0].asString.asInteger;
                bIndex = params[1].asString.asInteger;
                pedalboard.swap(aIndex, bIndex);
                postMsg.("swap " ++ aIndex ++ " <-> " ++ bIndex);
            } {
                postMsg.("swap: need two indices");
            };
        },
        \clear, {
            pedalboard.clearChain;
            postMsg.("clear NEXT");
        },
        \setSource, {
            var srcSym;
            if (params.size >= 1) {
                srcSym = params[0];
                pedalboard.setSource(srcSym);
                postMsg.("setSource " ++ srcSym);
            } {
                postMsg.("setSource: missing symbol");
            };
        },
        \switch, {
            pedalboard.switchChain(0.12);
            postMsg.("switch NEXT->CURRENT (crossfade)");
        },
        { // default
            postMsg.("unknown verb: " ++ verb);
        }
    );

    // Drive the GUI via existing display hooks (no direct GUI ops here).
    // pedalboard.display.showChainsDetailed(...) is already called by pedalboard.printChains etc.

    successFlag = true;
    successFlag
};

~ct_applyQueueToMPBFromCM = { arg commandManager, pedalboard, gui;
    var oscPathString, listSnapshot;
    var postMsg;

    postMsg = { arg text; ("[CT->MPB] " ++ text).postln };

    // Take a snapshot before export (for debugging)
    listSnapshot = commandManager.midiManager.queue.commandList;   // from your classes
    postMsg.("queue before export: " ++ listSnapshot);

    // Export as OSC-style path (also sets ~commandToSend in your original queue code)
    oscPathString = commandManager.midiManager.queue.exportAsOSCPath;

    postMsg.("exported OSC path: " ++ oscPathString);

    // Apply to pedalboard, then clear queue
    ~ct_applyOSCPathToMPB.(oscPathString, pedalboard, gui);
    commandManager.midiManager.queue.clear;

    true
};

~ct_sendAndApply = { arg commandManager, pedalboard, gui;
    var modeDict, sendModeSymbol;
    modeDict = commandManager.midiManager.modes; // from your classes
    sendModeSymbol = modeDict[\send];
    commandManager.midiManager.setMode(sendModeSymbol); // triggers export and clear
    ~ct_applyQueueToMPBFromCM.(commandManager, pedalboard, gui);
};
)

// demo_commandtree_preformed_queues.scd
// v0.1
// MD 20250916-1048

(
var log, makeCMIfNeeded, enqueueTokensFromPath, playlist, indexCounter, totalCount;

log = { arg msg; ("[DEMO] " ++ msg).postln };

makeCMIfNeeded = {
    if(~cm.isNil) { ~cm = CommandManager.new; log.("CommandManager created and JSON imported."); };
};

enqueueTokensFromPath = { arg cm, pathString;
    var tokens, tokenCounter, tokenTotal, one;
    // convert "/verb/arg1/arg2" into a token list on the cm queue
    tokens = pathString.asString.split($/).reject({ arg oneToken; oneToken.isEmpty }).collect({ arg s; s.asSymbol });
    cm.midiManager.queue.clear;
    tokenCounter = 0; tokenTotal = tokens.size;
    while({ tokenCounter < tokenTotal }, {
        one = tokens[tokenCounter];
        cm.midiManager.queue.enqueueCommand(one);
        tokenCounter = tokenCounter + 1;
    });
    log.("enqueued: " ++ tokens);
};

// A small playlist of fully-formed queues, like the tree would send
// (You can add "/commands/..." variants too; adapter strips the prefix.)
playlist = [
    "/add/delay",
    "/switch",
    "/bypass/delay/on",
    "/bypass/delay/off",
    "/switch"
];

indexCounter = 0; totalCount = playlist.size;

~demo_next = {
    var path;
    makeCMIfNeeded.value;
    if(indexCounter >= totalCount) {
        log.("playlist complete.");
    }{
        path = playlist[indexCounter];
        enqueueTokensFromPath.(~cm, path);
        ~ct_sendAndApply.(~cm, ~pedalboard, ~gui);
        log.("applied: " ++ path);
        indexCounter = indexCounter + 1;
        ~pedalboard.printChains;
    };
};

~demo_restart = {
    indexCounter = 0;
    log.("playlist reset.");
};
)

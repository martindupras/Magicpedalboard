// diag_manual_chain_patch.scd
// v0.1
// MD 20250916-1018

(
var log;

log = { arg msg; ("[DIAG] " ++ msg).postln };

Server.default.bind({
    // ensure a sink for chainA that passes its input
    Ndef(\chainA, { \in.ar(2) });

    // patch toneTest -> chainA and play chainA
    Ndef(\chainA) <<>> Ndef(\toneTest);
    Ndef(\chainA).play;
});

log.("Manual patch: chainA <<>> toneTest; chainA.play — you should hear steady tone now.");
)

// ForceStereoMold_Now.scd
// v0.1
// MD 20250917-1215
//
// Purpose: Pin sinks to 2ch audio using .mold (stronger than .ar)
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
Server.default.bind({
    Ndef(\chainA).mold(2, \audio);
    Ndef(\chainB).mold(2, \audio);
});
)

// diag_more_state.scd
// v0.1

(
~mpb.printChains;

[
    [\testmelody,  Ndef(\testmelody).source.notNil,  Ndef(\testmelody).isPlaying],
    [\delay,       Ndef(\delay).source.notNil,       Ndef(\delay).isPlaying],
    [\chainA,      Ndef(\chainA).source.notNil,      Ndef(\chainA).isPlaying],
    [\chainB,      Ndef(\chainB).source.notNil,      Ndef(\chainB).isPlaying]
].do({ arg row;
    ("[NODE] " ++ row[0] ++ " source?=" ++ row[1] ++ " playing?=" ++ row[2]).postln;
});
)

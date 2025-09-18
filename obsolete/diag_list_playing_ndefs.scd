// diag_list_playing_ndefs.scd
// v0.1
// MD 20250916-1016

(
var names, reportRows, indexCounter, totalCount;

names = [\toneTest, \testmelody, \chainA, \chainB, \delay, \chorus];
reportRows = names.collect({ arg oneName; [oneName, Ndef(oneName).isPlaying] });

indexCounter = 0;
totalCount = reportRows.size;
while({ indexCounter < totalCount }, {
    var row;
    row = reportRows[indexCounter];
    ("[PLAY] " ++ row[0] ++ " = " ++ row[1]).postln;
    indexCounter = indexCounter + 1;
});
)

// test_editor_commandtree_add_demo_verbs_part_b.scd
// v0.1
// MD 20250916-0920

(
var jsonPath, loadOk, tree, countBefore, countAfter, assert, summary, passCount, failCount;

jsonPath = "/Users/martindupras/CommandTreeSavefiles/myTree.json".standardizePath;
passCount = 0; failCount = 0;

assert = { arg condition, label;
    var statusText;
    statusText = if(condition) { "PASS" } { "FAIL" };
    ("[TEST] " ++ statusText ++ " — " ++ label).postln;
    if(condition) { passCount = passCount + 1 } { failCount = failCount + 1 };
};

// 0) Precondition: you just re-ran editor_commandtree_add_demo_verbs.scd
// 1) Reload tree
tree = MDCommandTree.new;
loadOk = tree.importJSONFile(jsonPath);
assert.(loadOk, "JSON reloaded");

// 2) Compare node counts
countBefore = ~ct_nodecount_after_first ? -1;
countAfter  = tree.nodeMap.size;

("[TEST] nodeMap.size first=" ++ countBefore ++ " second=" ++ countAfter).postln;

// Expectation: no new nodes created on second run (idempotent)
assert.(countBefore == countAfter, "idempotent: nodeMap size unchanged after second run");

// 3) Summary
summary = "[TEST] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount;
summary.postln;
)

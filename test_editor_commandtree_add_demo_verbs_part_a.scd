// test_editor_commandtree_add_demo_verbs_part_a.scd
// v0.1
// MD 20250916-0919

(
var jsonPath, loadOk, tree, getNodeByPath, assert, expectPath, pathsToCheck, passCount, failCount, countAfter, summary;

jsonPath = "/Users/martindupras/CommandTreeSavefiles/myTree.json".standardizePath;
passCount = 0;
failCount = 0;

assert = { arg condition, label;
    var statusText;
    statusText = if(condition) { "PASS" } { "FAIL" };
    ("[TEST] " ++ statusText ++ " — " ++ label).postln;
    if(condition) { passCount = passCount + 1 } { failCount = failCount + 1 };
};

getNodeByPath = { arg treeRef, nameList;
    var foundNode;
    foundNode = treeRef.getNodeByNamePath(nameList);
    foundNode
};

expectPath = { arg treeRef, nameList;
    var nodeRef, lastName, hasNode, payloadMatches;
    nodeRef = getNodeByPath.(treeRef, nameList);
    lastName = nameList.last;
    hasNode = nodeRef.notNil;
    assert.(hasNode, "exists: " ++ nameList.join(" → "));
    if(hasNode) {
        payloadMatches = (nodeRef.payload == lastName);
        assert.(payloadMatches, "payload==name for: " ++ nameList.join(" → "));
    };
};

// 1) Load tree
tree = MDCommandTree.new;
loadOk = tree.importJSONFile(jsonPath);
assert.(loadOk, "JSON loaded from " ++ jsonPath);

// 2) Expected paths created by the editor script
pathsToCheck = [
    ["commands"],
    ["commands","add","delay"],
    ["commands","add","chorus"],
    ["commands","add","reverb"],
    ["commands","add","tremolo"],
    ["commands","bypass","delay","on"],
    ["commands","bypass","delay","off"],
    ["commands","switch"],
    ["commands","setSource","testmelody"]
];

// 3) Check each path exists and payload==name
pathsToCheck.do({ arg nameList; expectPath.(tree, nameList) });

// 4) Record node map size (for idempotency comparison later)
countAfter = tree.nodeMap.size;
~ct_nodecount_after_first = countAfter;  // store globally for Part B
("[TEST] nodeMap.size after first run = " ++ countAfter).postln;

// 5) Summary
summary = "[TEST] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount;
summary.postln;
)

// editor_commandtree_add_demo_verbs.scd
// v0.3
// MD 20250916-0957

(
var jsonPath, saveFolder, savePrefix;
var ensureChildUnder, ensurePath, rootNode, commandsNode;

// paths
jsonPath   = "/Users/martindupras/CommandTreeSavefiles/myTree.json".standardizePath;
saveFolder = "/Users/martindupras/CommandTreeSavefiles";
savePrefix = "myTree";

// load
~tree = MDCommandTree.new;
if (~tree.importJSONFile(jsonPath)) {
    "✅ Loaded tree for editing.".postln;
} {
    "❌ Failed to load tree JSON".warn; ^nil;
};

// helpers
ensureChildUnder = { arg parentNode, childName, fretNumber;
    var existingNode, createdNode;
    existingNode = parentNode.getChildByName(childName);
    if (existingNode.notNil) {
        existingNode
    } {
        createdNode = ~tree.addNode(parentNode.id, childName, fretNumber);
        if (createdNode.isNil) { ("⚠️ addNode failed for " ++ childName).postln };
        createdNode
    }
};

ensurePath = { arg pathArray, fretArray;
    var currentNode, stepIndex, childName, fretNumber, pathSize;
    currentNode = ~tree.root;
    pathSize = pathArray.size;
    stepIndex = 0;
    while({ stepIndex < pathSize }, {
        childName = pathArray[stepIndex];
        fretNumber = fretArray[stepIndex] ? 1;
        currentNode = ensureChildUnder.(currentNode, childName, fretNumber);
        stepIndex = stepIndex + 1;
    });
    currentNode
};

// ---- add demo verbs (idempotent) ----
rootNode = ~tree.root;
commandsNode = ensureChildUnder.(rootNode, "commands", 10);

// commands/add/<proc>
ensurePath.(["commands","add","delay"],   [10,1,1]);
ensurePath.(["commands","add","chorus"],  [10,1,2]);
ensurePath.(["commands","add","reverb"],  [10,1,3]);
ensurePath.(["commands","add","tremolo"], [10,1,4]);

// commands/bypass/<proc>/<on|off>
ensurePath.(["commands","bypass","delay","on"],  [10,2,1,2]);
ensurePath.(["commands","bypass","delay","off"], [10,2,1,3]);

// commands/switch
ensurePath.(["commands","switch"], [10,3]);

// commands/setSource/<src>
ensurePath.(["commands","setSource","testmelody"], [10,4,1]);

// set payloads == names (simple, visible)
~tree.assignPayloads;
~tree.printTreePretty;

// save using custom exporter (preserves payloads in JSON)
~ct_writeJsonWithPayloads.(~tree, jsonPath, true, saveFolder, savePrefix);
)

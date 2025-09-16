// editor_commandtree_add_demo_verbs.scd
// v0.3
// MD 20250916-0943

(
var jsonPath, saveFolder, savePrefix;
var ensureChildUnder, ensurePath, rootNode, commandsNode;

jsonPath   = "/Users/martindupras/CommandTreeSavefiles/myTree.json".standardizePath;
saveFolder = "/Users/martindupras/CommandTreeSavefiles";
savePrefix = "myTree";

// Load current tree JSON
~tree = MDCommandTree.new;
if (~tree.importJSONFile(jsonPath)) {
    "✅ Loaded tree for editing.".postln;
} {
    "❌ Failed to load tree JSON".warn;
    nil;
};

// Helpers
ensureChildUnder = { arg parentNode, childName, fretNumber;
    var existingNode, newNode;
    existingNode = parentNode.getChildByName(childName);
    if (existingNode.notNil) {
        existingNode
    }{
        newNode = ~tree.addNode(parentNode.id, childName, fretNumber);
        if (newNode.isNil) { ("⚠️ addNode failed for " ++ childName).postln };
        newNode
    }
};

ensurePath = { arg pathArray, fretArray;
    var currentNode, pathSize, indexCounter, childName, fretNumber;
    currentNode = ~tree.root;
    pathSize = pathArray.size;
    indexCounter = 0;
    while({ indexCounter < pathSize }, {
        childName = pathArray[indexCounter];
        fretNumber = fretArray[indexCounter] ? 1;
        currentNode = ensureChildUnder.(currentNode, childName, fretNumber);
        indexCounter = indexCounter + 1;
    });
    currentNode
};

// ---- Add demo verbs ----
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

// Make payloads equal to names (simple, explicit)
~tree.assignPayloads;

// Show result for visual confirmation
~tree.printTreePretty;

// Save a versioned copy and overwrite live JSON
~saver = ~saver ?? { CircularFileSave.new(savePrefix, saveFolder, 10) };
~saver.saveVersion(JSONlib.convertToJSON(~tree.root.asDictRecursively));
"💾 Versioned copy saved.".postln;

~tree.exportJSONFile(jsonPath);
"💾 Overwrote current JSON at: ".postln;
jsonPath.postln;
)

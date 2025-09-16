// saveonly_commandtree_current_to_json.scd
// v0.2
// MD 20250916-0942

(
var saveFolder, savePrefix, jsonPath, jsonString;

saveFolder = "/Users/martindupras/CommandTreeSavefiles";
savePrefix = "myTree";
jsonPath   = (saveFolder +/+ "myTree.json").standardizePath;

// Ensure a saver instance (if nil, create one)
~saver = ~saver ?? { CircularFileSave.new(savePrefix, saveFolder, 10) };

// Serialize current in‑memory tree to JSON text
jsonString = JSONlib.convertToJSON(~tree.root.asDictRecursively);

// Save a versioned copy and overwrite the live JSON file for CommandManager
~saver.saveVersion(jsonString);
~tree.exportJSONFile(jsonPath);

"💾 Saved versioned JSON and wrote current tree to: ".postln;
jsonPath.postln;
)

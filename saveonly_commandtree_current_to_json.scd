// saveonly_commandtree_current_to_json.scd
// v0.1
// MD 20250916-0931

(
var saveFolder, savePrefix, jsonPath, jsonString;

// paths
saveFolder = "/Users/martindupras/CommandTreeSavefiles";
savePrefix = "myTree";
jsonPath   = (saveFolder +/+ "myTree.json").standardizePath;

// versioned copy via CircularFileSave
~saver = ~saver ? { CircularFileSave.new(savePrefix, saveFolder, 10) }();
jsonString = JSONlib.convertToJSON(~tree.root.asDictRecursively);
~saver.saveVersion(jsonString);

// overwrite the live JSON file for CommandManager
~tree.exportJSONFile(jsonPath);
"💾 Saved versioned JSON and wrote current tree to: ".postln; jsonPath.postln;
)

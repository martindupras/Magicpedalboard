// tool_export_commandtree_with_payloads.scd
// v0.1
// MD 20250916-0956

(
~ct_nodeToDictWithPayload = { arg nodeRef;
    var childDicts, outDict;
    childDicts = Array.new;
    nodeRef.children.do({ arg childNode;
        childDicts = childDicts.add(~ct_nodeToDictWithPayload.(childNode));
    });
    outDict = (
        id: nodeRef.id,
        name: nodeRef.name,
        fret: nodeRef.fret,
        payload: nodeRef.payload,   // <— keep payload
        children: childDicts
    );
    outDict
};

~ct_writeJsonWithPayloads = {
    arg treeRef,
        outPath = "/Users/martindupras/CommandTreeSavefiles/myTree.json",
        writeVersioned = true,
        saveFolder = "/Users/martindupras/CommandTreeSavefiles",
        savePrefix = "myTree";

    var topDict, jsonString;

    // Top-level object: include root payload and nodeLimit if available
    topDict = (
        name: treeRef.root.name,
        id: treeRef.root.id,
        nodeLimit: treeRef.nodeLimit ? 200,
        payload: treeRef.root.payload,
        children: treeRef.root.children.collect({ arg child; ~ct_nodeToDictWithPayload.(child) })
    );

    jsonString = JSONlib.convertToJSON(topDict);

    if(writeVersioned) {
        var saver;
        saver = CircularFileSave.new(savePrefix, saveFolder, 10);
        saver.saveVersion(jsonString);  // versioned copy with payloads preserved
    };

    File.use(outPath.standardizePath, "w", { arg f; f.write(jsonString) });
    ("[CT] Wrote JSON with payloads -> " ++ outPath).postln;
};
)

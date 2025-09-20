// tool_xml_to_json_commandtree.scd
// v0.1
// MD 20250916-0850

(
~ct_convertXmlToJson = { arg inPath = "~/myTree.xml", outPath = "~/CommandTreeSavefiles/myTree.json";
    var xmlText, lines, stack, rootDict, currentDict, parseOpen, parseClose, parseAttrs, toJSON;

    inPath = inPath.standardizePath;
    outPath = outPath.standardizePath;

    xmlText = File.readAllString(inPath);
    if(xmlText.isNil or: { xmlText.isEmpty }) { "XML empty or unreadable.".warn; ^false };

    // Helpers
    parseAttrs = { arg tagLine;
        var dict, pairs;
        dict = IdentityDictionary.new;
        // crude attribute parse: key="value"
        pairs = tagLine.findAllRegexp("\"([^\"]*)\"");
        // We walk the string: extract id, name, fret, payload if present
        // Better: regex for key="value" tuples
        tagLine.findAllRegexp("(\\w+)\\s*=\\s*\"([^\"]*)\"").do({ arg m;
            var key = m[1].asString.asSymbol;
            var val = m[2].asString;
            dict[key] = val;
        });
        dict
    };

    parseOpen = { arg line;
        var attrs, dict, idNum, fretNum;
        attrs = parseAttrs.(line);
        dict = (
            id: (attrs[\id] ?? { "0" }).asInteger,
            name: (attrs[\name] ?? { "unnamed" }).asString,
            fret: (attrs[\fret] ?? { "0" }).asInteger,
            payload: (attrs[\payload] ?? { nil }),
            children: Array.new
        );
        dict
    };

    parseClose = { arg stackRef;
        if(stackRef.size > 1, {
            var child = stackRef.pop;
            stackRef.last[\children] = stackRef.last[\children].add(child);
        });
    };

    stack = Array.new;

    // Tokenize lines and handle <node .../> self-close and </node>
    lines = xmlText.replace($\t, $ ).replace($\r, $ ).split($\n);
    lines.do({ arg raw;
        var line = raw.trim;
        if(line.isEmpty) { ^nil };

        if(line.beginsWith("<node") and: { line.endsWith("/>") }) {
            var dict = parseOpen.(line);
            if(stack.isEmpty) { stack.push(dict) } { stack.last[\children] = stack.last[\children].add(dict) };
        }{
            if(line.beginsWith("</node")) {
                parseClose.(stack);
            }{
                if(line.beginsWith("<node")) {
                    stack.push(parseOpen.(line));
                };
            };
        };
    });

    // Close remaining nodes
    while({ stack.size > 1 }, { parseClose.(stack) });

    rootDict = if(stack.size == 1) { stack[0] } { nil };
    if(rootDict.isNil) { "Parse failed (no root)".warn; ^false };

    // Build top-level tree dict for MDCommandTree.fromDict
    currentDict = (
        name: rootDict[\name],
        id: rootDict[\id],
        nodeLimit: 200,
        payload: rootDict[\payload],
        children: rootDict[\children]
    );

    // Write JSON (uses JSONlib from your environment)
    File.use(outPath, "w", { arg f; f.write(JSONlib.convertToJSON(currentDict)) });
    ("[CT] Wrote JSON -> " ++ outPath).postln;
    true
};
)

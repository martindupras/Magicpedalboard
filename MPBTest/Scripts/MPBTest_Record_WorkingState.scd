// MPBTest_Record_WorkingState.scd
// v0.1.0
// MD 20250920-1930

(
var now, stamp, docDir, mdPath, jsonPath, mkDir;
var s, o, outDev, sr, blk, scv, lines, md, js;
var v_mpbtest_bring, v_mpbtest_scen, v_mpbtest_suites, v_mpbtest_assert;
var v_mpb, v_md, v_mdgui, v_mdgrid;
var fileList, classPaths;

// 0) Paths & timestamp
now   = Date.getDate.stamp; // "2025-09-20_19:30:15"
stamp = now.replace(":", "").replace("_", "-").keep(15); // e.g. 2025-09-20-1930
docDir = PathName(thisProcess.nowExecutingPath ?? thisProcess.cwd).pathOnly
    .standardizePath
    .split($/)
    .drop(-2) // climb out of Scripts/
    .addAll(["MPBTest","docs"])
    .join($/).standardizePath;

mkDir = { |p|
    var pn = PathName(p);
    if(pn.exists.not) { pn.mkdir }
};

// 1) Ensure docs dir
mkDir.(docDir);

// 2) Environment
s  = Server.default;
o  = s.options;
outDev = o.outDevice ? "default";
sr  = s.sampleRate ? 0;
blk = o.blockSize;
scv = Main.scVersionString ? Main.scVersion;

// 3) Versions
v_mpbtest_bring  = (MPBTest_BringUp.respondsTo(\version)).if({ MPBTest_BringUp.version },{ "unknown" });
v_mpbtest_scen   = (MPBTest_Scenario.respondsTo(\version)).if({ MPBTest_Scenario.version },{ "unknown" });
v_mpbtest_suites = (MPBTest_AcceptanceSuites.respondsTo(\version)).if({ MPBTest_AcceptanceSuites.version },{ "unknown" });
v_mpbtest_assert = (MPBTest_Assertions.respondsTo(\version)).if({ MPBTest_Assertions.version },{ "unknown" });

v_mpb    = (MagicPedalboardNew.respondsTo(\version)).if({ MagicPedalboardNew.version },{ "unknown" });
v_md     = (MagicDisplay.respondsTo(\version)).if({ MagicDisplay.version },{ "unknown" });
v_mdgui  = (MagicDisplayGUI.respondsTo(\version)).if({ MagicDisplayGUI.version },{ "unknown" });
v_mdgrid = (MagicDisplayGUI_GridDemo.respondsTo(\version)).if({ MagicDisplayGUI_GridDemo.version },{ "unknown" });

// 4) Class file paths (confirm there’s only one of each)
classPaths = Class.allClasses
    .select({ |c| ["MPBTest_BringUp","MPBTest_Scenario","MPBTest_AcceptanceSuites","MPBTest_Assertions"].includes(c.name.asString) })
    .collect(_.filenameSymbol.asString);

// 5) Chain snapshot
~mpb = ~mpb ?? { nil };
fileList = if(~mpb.notNil, {
    var effC = ~mpb.effectiveCurrent, effN = ~mpb.effectiveNext;
    [
        "CURRENT=" ++ effC.asString,
        "NEXT   =" ++ effN.asString,
        "[PLAY] A=" ++ Ndef(\chainA).isPlaying ++ " B=" ++ Ndef(\chainB).isPlaying
    ]
}, { ["no ~mpb"] });

// 6) Write Markdown + JSON
mdPath   = docDir +/+ ("WorkingState_" ++ stamp ++ ".md");
jsonPath = docDir +/+ ("WorkingState_" ++ stamp ++ ".json");

// Markdown
md = String.new;
md = md
++ "# MagicPedalboard – Working State (" ++ stamp ++ ")\n\n"
++ "## Versions\n"
++ "- MPBTest_BringUp: "   ++ v_mpbtest_bring  ++ "\n"
++ "- MPBTest_Scenario: "  ++ v_mpbtest_scen   ++ "\n"
++ "- MPBTest_AcceptanceSuites: " ++ v_mpbtest_suites ++ "\n"
++ "- MPBTest_Assertions: "++ v_mpbtest_assert ++ "\n"
++ "- MagicPedalboardNew: "++ v_mpb ++ "\n"
++ "- MagicDisplay: "      ++ v_md  ++ "\n"
++ "- MagicDisplayGUI: "   ++ v_mdgui  ++ "\n"
++ "- MagicDisplayGUI_GridDemo: " ++ v_mdgrid ++ "\n\n"
++ "## Environment\n"
++ "- sclang: " ++ scv ++ "\n"
++ "- output device: " ++ outDev ++ "\n"
++ "- sample rate: " ++ sr ++ "\n"
++ "- block size: " ++ blk ++ "\n\n"
++ "## Class Files\n- " ++ classPaths.join("\n- ") ++ "\n\n"
++ "## Chain Snapshot\n- " ++ fileList.join("\n- ") ++ "\n";

File.writeText(mdPath, md);

// JSON (minimal)
js = (
    timestamp: stamp,
    versions: (
        MPBTest_BringUp: v_mpbtest_bring, MPBTest_Scenario: v_mpbtest_scen,
        MPBTest_AcceptanceSuites: v_mpbtest_suites, MPBTest_Assertions: v_mpbtest_assert,
        MagicPedalboardNew: v_mpb, MagicDisplay: v_md,
        MagicDisplayGUI: v_mdgui, MagicDisplayGUI_GridDemo: v_mdgrid
    ),
    environment: (
        sclang: scv, outDevice: outDev, sampleRate: sr, blockSize: blk
    ),
    classFiles: classPaths
).asCompileString;

File.writeText(jsonPath, js);

("[RECORD] wrote\n- " ++ mdPath ++ "\n- " ++ jsonPath).postln;
)

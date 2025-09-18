// Run_Milestone_Today.scd
// v0.2.0
// MD 20250918-20:28 BST

/*
Purpose
- Minimal, reliable driver for today's milestone — no boot logic.
- Run one main block once to set up helpers + a small Processors HUD inside MagicDisplayGUI.
- Then run the single-line commands below, one by one, to hear/see the expected changes.

Style
- var-first in every function/closure; lowercase method names; no server.sync;
- server ops live in adapter/MPB methods; AppClock for GUI; one window only; generated audio only;
- JITLib connect operator remains exactly "<<>"; processors/sinks read from \in.ar(2).
*/

(
// ---------- setup ----------

var log, ensureAdapter, symbolsToString, extractTail, findGuiWindow;
var hudInstall, hudRender, hudUpdate, wrapApply, primeToday, guardSwitch, stateLine;

// small logger
log = { arg messageString;
    var lineText;
    lineText = "[TOKENS] " ++ messageString;
    lineText.postln;
};

// pretty chain printing
symbolsToString = { arg syms;
    var namesArray, joined;
    namesArray = syms.collect(_.asString);
    joined = namesArray.join(" \u2192 ");
    joined
};

// drop leading \chainA / \chainB
extractTail = { arg chainArray;
    var arr;
    arr = chainArray ? [];
    if(arr.size > 0) { arr.copyRange(1, arr.size - 1) } { [] }
};

// find existing MagicDisplayGUI window
findGuiWindow = {
    var wins, target;
    wins = Window.allWindows.select({ arg w;
        var nm, isMagic;
        nm = w.tryPerform(\name);
        isMagic = nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") };
        isMagic
    });
    target = wins.last;
    target
};

// --- Ensure adapter is loaded (absolute path, no loadRelative)
ensureAdapter = {
    var scriptDir, fileLower, fileCamel, ok;
    scriptDir = ~scriptDir ?? {
        var p, d;
        p = thisProcess.nowExecutingPath;
        d = if(p.notNil) { PathName(p).pathOnly } { thisProcess.cwd };
        d
    };
    fileLower = (scriptDir +/+ "adapter_commandtree_to_magicpedalboard.scd").standardizePath;
    fileCamel = (scriptDir +/+ "adapter_CommandTree_to_MagicPedalboard.scd").standardizePath;
    ok = (~ct_applyOSCPathToMPB.notNil);
    if(ok.not) {
        if(File.exists(fileLower)) { fileLower.load; ok = true };
        if(ok.not and: { File.exists(fileCamel) }) { fileCamel.load; ok = true };
    };
    if(ok) { "[RUN] adapter is available".postln } { "[RUN] adapter missing — please load adapter file".warn };
    ok
};

// --- HUD: install inside the existing MagicDisplayGUI window (no FlowLayout; explicit bounds)
hudInstall = {
    AppClock.sched(0, {
        var win, root, r, box, title, lineA, lineB;

        win = findGuiWindow.value;
        if(win.isNil) {
            "[HUD] MagicDisplayGUI window not found yet; open bring-up first".postln;
            ^nil
        };
        root = win.view;

        // if exists and alive, skip
        if(~procHud.notNil and: { ~procHud[\view].notNil } and: { ~procHud[\view].isClosed.not }) {
            ^nil
        };

        // panel bounds anchored to bottom with margins
        r = Rect(10, (root.bounds.height - 56).max(10), (root.bounds.width - 20).max(160), 46);

        box = CompositeView(root, r)
            .background_(Color(0.12, 0.12, 0.12, 0.88));

        title = StaticText(box, Rect(8, 6, (r.width - 16).max(80), 16))
            .string_("Processors HUD")
            .stringColor_(Color(0.9,0.9,0.9));

        lineA = StaticText(box, Rect(8, 22, (r.width - 16).max(80), 16))
            .string_("CURRENT: -")
            .stringColor_(Color(0.9,0.9,0.9));

        lineB = StaticText(box, Rect(8, 38, (r.width - 16).max(80), 16))
            .string_("NEXT:    -")
            .stringColor_(Color(0.8,0.8,0.8));

        ~procHud = IdentityDictionary[
            \view        -> box,
            \lineCurrent -> lineA,
            \lineNext    -> lineB
        ];

        "[HUD] installed in MagicDisplayGUI".postln;
        nil
    });
};

// --- HUD: render
hudRender = {
    AppClock.sched(0, {
        var ok, win, lineA, lineB, curArr, nextArr, curTail, nextTail, curStr, nextStr;

        ok = (~mpb.notNil);
        if(ok.not) { ^nil };

        if(~procHud.isNil or: { ~procHud[\view].isNil } or: { ~procHud[\view].isClosed }) {
            hudInstall.value;
            AppClock.sched(0.05, { hudRender.value; nil });
            ^nil
        };

        win = findGuiWindow.value; // not used, but keeps intent clear
        curArr  = ~mpb.effectiveCurrent;
        nextArr = ~mpb.effectiveNext;

        curTail = extractTail.value(curArr);
        nextTail = extractTail.value(nextArr);

        curStr = if(curTail.size > 0) { symbolsToString.value(curTail) } { "-" };
        nextStr = if(nextTail.size > 0) { symbolsToString.value(nextTail) } { "-" };

        lineA = ~procHud[\lineCurrent];
        lineB = ~procHud[\lineNext];

        if(lineA.notNil) { lineA.string = "CURRENT: " ++ curStr };
        if(lineB.notNil) { lineB.string = "NEXT:    " ++ nextStr };

        nil
    });
};

// --- a one-liner the user can call for manual refresh
hudUpdate = { hudRender.value };

// --- guard: ensure NEXT is audible before /switch (avoids switching to ts0)
guardSwitch = {
    var lastTail;
    lastTail = ~mpb.effectiveNext.last;
    if(lastTail == \ts0) {
        log.("guard: NEXT ends with \\ts0 -> /setSource/testmelody");
        ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
    };
    hudRender.value;
};

// --- state print (what you should see)
stateLine = {
    var line;
    ~mpb.printChains;
    line = "[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying);
    line.postln;
    hudRender.value;
};

// --- prime (for today's demo)
primeToday = {
    var ignore;
    ignore = nil;
    ~mpb.setSourcesBoth(\testmelody);    // both tails end with testmelody
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    stateLine.value;
};

// --- apply wrapper: call adapter, then HUD update
wrapApply = { arg pathString;
    var p;
    p = pathString.asString;
    log.("apply -> " ++ p);
    ~ct_applyOSCPathToMPB.(p, ~mpb, ~gui);
    hudRender.value;
};

// ---------- publish helpers for your 1-liners ----------
~tok = IdentityDictionary[
    \apply       -> wrapApply,
    \prime       -> primeToday,
    \guardSwitch -> guardSwitch,
    \state       -> stateLine,
    \hudUpdate   -> hudUpdate,
    \hudInstall  -> hudInstall
];

// ---------- sanity + first render ----------
if((~mpb.isNil) or: { ~gui.isNil }) {
    "[RUN] Bring-up not ready (~mpb/~gui). Run StartHere_CleanBoot_OneWindow_BringUp.scd first.".warn;
} {
    if(ensureAdapter.value) {
        hudInstall.value;
        AppClock.sched(0.10, { ~tok.state.(); nil });
    };
};
)

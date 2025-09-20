// Run_Milestone_Today.scd
// v0.2.1
// MD 20250918-21:05 BST

/*
Purpose
- Minimal, reliable milestone driver (no boot logic). Run main block once (sets up helpers + HUD),
  then run the one-liners below, in order, to hear/see the expected changes.

Style
- var-first in every function/closure; lowercase methods; no server.sync;
- server ops live inside adapter/MPB; GUI ops on AppClock; one window only; generated audio only;
- JITLib connect operator remains exactly "<<>"; processors/sinks read from \in.ar(2).
*/

(
// ---------- setup ----------

var log, ensureAdapter, symbolsToString, extractTail, findGuiWindow;
var hudInstall, hudRender, hudUpdate, wrapApply, primeToday, guardSwitch, stateLine;

// small logger
log = { arg s;
    var line;
    line = "[TOKENS] " ++ s;
    line.postln;
};

// pretty chain printing
symbolsToString = { arg syms;
    var arr, joined;
    arr = syms.collect(_.asString);
    joined = arr.join(" \u2192 ");
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

// Ensure adapter is loaded (absolute path, no loadRelative)
ensureAdapter = {
    var scriptDir, fileLower, fileCamel, ok, p, d;
    scriptDir = ~scriptDir ?? {
        p = thisProcess.nowExecutingPath;
        d = if(p.notNil) { PathName(p).pathOnly } { thisProcess.cwd };
        d
    };
    ok = (~ct_applyOSCPathToMPB.notNil);
    if(ok.not) {
        fileLower = (scriptDir +/+ "adapter_commandtree_to_magicpedalboard.scd").standardizePath;
        fileCamel = (scriptDir +/+ "adapter_CommandTree_to_MagicPedalboard.scd").standardizePath;
        if(File.exists(fileLower)) { fileLower.load; ok = true } {
            if(File.exists(fileCamel)) { fileCamel.load; ok = true };
        };
    };
    if(ok) { "[RUN] adapter is available".postln } { "[RUN] adapter missing — please load adapter file".warn };
    ok
};

// HUD: install into existing MagicDisplayGUI (explicit bounds; no caret returns)
hudInstall = {
    AppClock.sched(0, {
        var win, root, r, box, title, lineA, lineB, exists;

        win = findGuiWindow.value;
        if(win.notNil) {
            root = win.view;

            exists = (~procHud.notNil)
                and: { ~procHud[\view].notNil }
                and: { ~procHud[\view].isClosed.not };

            if(exists.not) {
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
            };
        }{
            "[HUD] MagicDisplayGUI window not found yet; run bring-up first".postln;
        };
        nil
    });
};

// HUD: render (safe guards; no caret returns)
hudRender = {
    AppClock.sched(0, {
        var alive, curArr, nextArr, curTail, nextTail, curStr, nextStr, lineA, lineB;

        if(~mpb.notNil) {
            alive = (~procHud.notNil)
                and: { ~procHud[\view].notNil }
                and: { ~procHud[\view].isClosed.not };

            if(alive.not) {
                hudInstall.value;
                AppClock.sched(0.07, { hudRender.value; nil });
            }{
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
            };
        }{
            "[HUD] cannot render (no ~mpb)".postln;
        };
        nil
    });
};

hudUpdate = { hudRender.value };

// guard: ensure NEXT audible before /switch (avoid switching to \ts0)
guardSwitch = {
    var lastTail;
    lastTail = ~mpb.effectiveNext.last;
    if(lastTail == \ts0) {
        log.("guard: NEXT ends with \\ts0 -> /setSource/testmelody");
        ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
    };
    hudRender.value;
};

// state print (what you should see)
stateLine = {
    var line;
    ~mpb.printChains;
    line = "[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying);
    line.postln;
    hudRender.value;
};

// prime (for today's demo)
primeToday = {
    var ignore;
    ignore = nil;
    ~mpb.setSourcesBoth(\testmelody); // both tails end with testmelody
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    stateLine.value;
};

// apply wrapper: call adapter, then HUD update
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
}{
    if(ensureAdapter.value) {
        hudInstall.value;
        AppClock.sched(0.10, { ~tok.state.(); nil });
    };
};
)

// MagicDisplayGUI_ProcessorsHUD_TopLeft.scd
// v0.3.2
// MD 20250919-08:25 BST

/*
Purpose
- Install a compact Processors HUD inside the existing MagicDisplayGUI window.
- Anchored top-left; no FlowLayout; adequate height so the "NEXT" line never truncates.
- Reflows width on update; safe to evaluate multiple times.
- If ~mpb is available, shows CURRENT/NEXT processor tails; otherwise shows placeholders.

Style
- var-first; lowercase; AppClock-only GUI ops; no caret returns in AppClock closures; no server.sync.
*/

(
var findGuiWindow, ensureHud, renderHud, makeRect, summarize, extractTail, clipStr, posCorner;

posCorner = \topLeft;

// helpers
findGuiWindow = {
    var windowsList, targetWindow;
    windowsList = Window.allWindows.select({ arg w;
        var nameStr, isMagic;
        nameStr = w.tryPerform(\name);
        isMagic = nameStr.notNil and: { nameStr.asString.beginsWith("MagicDisplayGUI") };
        isMagic
    });
    targetWindow = windowsList.last;
    targetWindow
};

makeRect = { arg parentRect;
    var margin, minWidth, panelWidth, panelHeight, xPos, yPos;
    margin = 10;
    minWidth = 220;
    panelHeight = 60; // title (16) + line (16) + line (16) + padding
    panelWidth  = (parentRect.width - (margin * 2)).clip(minWidth, 10000);
    xPos = if(posCorner == \topRight) { (parentRect.width - margin - panelWidth) } { margin };
    yPos = margin;
    Rect(xPos, yPos, panelWidth, panelHeight)
};

clipStr = { arg anyString, maxChars = 84;
    var s;
    s = anyString.asString;
    if(s.size > maxChars) { s.copyRange(0, maxChars-3) ++ "…" } { s }
};

extractTail = { arg chainArray;
    var arr;
    arr = chainArray ? [];
    if(arr.size > 0) { arr.copyRange(1, arr.size - 1) } { [] }
};

summarize = { arg syms;
    var namesArr, joined;
    namesArr = syms.collect(_.asString);
    joined = namesArr.join(" -> ");
    clipStr.value(joined, 84)
};

// installer
ensureHud = {
    AppClock.sched(0, {
        var win, rootView, boxView, titleText, lineCurrent, lineNext, rect, exists;
        win = findGuiWindow.value;
        if(win.notNil) {
            rootView = win.view;
            exists = (~procHud.notNil) and: { ~procHud[\view].notNil } and: { ~procHud[\view].isClosed.not };
            if(exists.not) {
                rect = makeRect.value(rootView.bounds);
                boxView = CompositeView(rootView, rect).background_(Color(0.12, 0.12, 0.12, 0.90));
                titleText = StaticText(boxView, Rect(8, 6, rect.width - 16, 16))
                    .string_("Processors")
                    .stringColor_(Color(0.95, 0.95, 0.95));
                lineCurrent = StaticText(boxView, Rect(8, 24, rect.width - 16, 16))
                    .string_("CURRENT: -")
                    .stringColor_(Color(0.90, 0.90, 0.90));
                lineNext = StaticText(boxView, Rect(8, 42, rect.width - 16, 16)) // 42 avoids clipping
                    .string_("NEXT: -")
                    .stringColor_(Color(0.80, 0.80, 0.80));
                ~procHud = IdentityDictionary[
                    \view -> boxView,
                    \lineCurrent -> lineCurrent,
                    \lineNext -> lineNext
                ];
                "[HUD] installed (top-left)".postln;
            };
        }{
            "[HUD] MagicDisplayGUI not found yet".postln;
        };
        nil
    });
};

// renderer
renderHud = {
    AppClock.sched(0, {
        var win, rootView, alive, rect, lineCurrent, lineNext;
        var currentArr, nextArr, currentTail, nextTail, currentStr, nextStr, haveMpb;

        win = findGuiWindow.value;
        if(win.notNil) {
            rootView = win.view;
            alive = (~procHud.notNil) and: { ~procHud[\view].notNil } and: { ~procHud[\view].isClosed.not };
            if(alive.not) {
                ensureHud.value;
                AppClock.sched(0.08, { renderHud.value; nil });
            }{
                rect = makeRect.value(rootView.bounds);
                ~procHud[\view].bounds = rect;

                haveMpb = (~mpb.notNil);
                if(haveMpb) {
                    currentArr = ~mpb.effectiveCurrent;
                    nextArr    = ~mpb.effectiveNext;
                    currentTail= extractTail.value(currentArr);
                    nextTail   = extractTail.value(nextArr);
                    currentStr = summarize.value(currentTail);
                    nextStr    = summarize.value(nextTail);
                }{
                    currentStr = "-";
                    nextStr    = "-";
                };

                lineCurrent = ~procHud[\lineCurrent];
                lineNext    = ~procHud[\lineNext];
                if(lineCurrent.notNil) {
                    lineCurrent.bounds = Rect(8, 24, rect.width - 16, 16);
                    lineCurrent.string = "CURRENT: " ++ currentStr;
                };
                if(lineNext.notNil) {
                    lineNext.bounds = Rect(8, 42, rect.width - 16, 16);
                    lineNext.string = "NEXT: " ++ nextStr;
                };
                ~procHud[\view].front;
            };
        }{
            "[HUD] no MagicDisplayGUI; cannot render".postln;
        };
        nil
    });
};

// public API
~procHud_install  = { ensureHud.value };
~procHud_update   = { renderHud.value };
~procHud_relocate = { arg cornerSymbol;
    var corner;
    corner = cornerSymbol ? \topLeft;
    posCorner = ([\topLeft, \topRight].includes(corner)).if({ corner }, { \topLeft });
    renderHud.value;
};

// install & draw once
~procHud_install.();
AppClock.sched(0.10, { ~procHud_update.(); nil });
)

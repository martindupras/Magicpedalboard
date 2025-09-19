// MagicDisplayGUI_ProcessorsHUD.scd
// v0.2.1
// MD 20250918-21:05 BST

/*
Purpose
- Add a lightweight "Processors HUD" to the existing MagicDisplayGUI window.
- Shows CURRENT and NEXT processor tails (symbols). Updates via ~procHud_update.

Style
- var-first in every function/closure; lowercase names; no server.sync; AppClock for GUI only;
- one window only (install into the existing MagicDisplayGUI* window).
*/

(
var symbolsToString, extractTail, findGuiWindow, clampRect, hudInstall, hudRender;

/********** helpers **********/
symbolsToString = { arg syms;
    var namesArray, joined;
    namesArray = syms.collect(_.asString);
    joined = namesArray.join(" \u2192 "); // arrow
    joined
};

extractTail = { arg chainArray;
    var arr;
    arr = chainArray ? [];
    if(arr.size > 0) { arr.copyRange(1, arr.size - 1) } { [] }
};

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

clampRect = { arg parentRect;
    var x, y, w, h;
    x = 10;
    w = (parentRect.width - 20).max(160);
    h = 46;
    y = (parentRect.height - (h + 10)).max(10);
    Rect(x, y, w, h)
};

/********** installer (explicit bounds; no FlowLayout; no caret returns) **********/
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
                r = clampRect.value(root.bounds);

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

                "[HUD] installed into MagicDisplayGUI".postln;
            };
        }{
            "[HUD] MagicDisplayGUI window not found yet (install will retry on update)".postln;
        };
        nil
    });
};

/********** renderer (safe guards; no caret returns) **********/
hudRender = {
    AppClock.sched(0, {
        var ok, curArr, nextArr, curTail, nextTail, curStr, nextStr, lineA, lineB, alive;

        ok = (~mpb.notNil);
        if(ok) {
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

/********** public API **********/
~procHud_install = { hudInstall.value };
~procHud_update  = { hudRender.value };

// install & draw once
~procHud_install.();
AppClock.sched(0.10, { ~procHud_update.(); nil });
)

// MagicDisplayGUI_ProcessorsHUD.scd
// v0.2.0
// MD 20250918-20:10 BST

/* Purpose
   - Add a lightweight "Processors HUD" to the existing MagicDisplayGUI window.
   - Shows CURRENT and NEXT processor chains (symbols), updates via ~procHud_update.

   Style
   - var-first in every function/closure; lowercase method names; no server.sync;
   - AppClock only for GUI ops; attach to the single existing MagicDisplayGUI window.
*/

(
var findGuiWindow, ensureHud, renderHud, symbolsToString, extractTail, clampRect;

/********** helpers **********/
symbolsToString = { arg syms;
    var arr, joined;
    arr = syms.collect(_.asString);
    joined = arr.join(" \u2192 "); // arrow
    joined
};

extractTail = { arg chainArray;
    var arr;
    arr = chainArray ? [];
    if(arr.size > 0) { arr.copyRange(1, arr.size - 1) } { [] }
};

clampRect = { arg parentRect;
    var x, y, w, h, minW, minH;
    x = 10;
    w = (parentRect.width - 20).max(120);
    h = 46;
    y = (parentRect.height - (h + 10)).max(10);
    Rect(x, y, w, h)
};

findGuiWindow = {
    var wins, target;
    wins = Window.allWindows.select({ arg w;
        var nm, isMagic;
        nm = w.tryPerform(\name);
        isMagic = nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") };
        isMagic
    });
    target = wins.last; // if multiple, take the latest
    target
};

/********** renderer **********/
renderHud = {
    var win, root, ok, currentArr, nextArr, currentTail, nextTail, currentStr, nextStr;
    var lineCurrent, lineNext;

    win = findGuiWindow.value;
    ok = win.notNil and: { ~mpb.notNil };

    if(ok.not) {
        "[HUD] cannot render (no GUI window or ~mpb)".postln;
        ^nil
    };

    // gather data
    currentArr  = ~mpb.effectiveCurrent;
    nextArr     = ~mpb.effectiveNext;
    currentTail = extractTail.value(currentArr);
    nextTail    = extractTail.value(nextArr);

    currentStr = if(currentTail.size > 0) { symbolsToString.value(currentTail) } { "-" };
    nextStr    = if(nextTail.size > 0)    { symbolsToString.value(nextTail) } { "-" };

    if(~procHud.isNil or: { ~procHud[\view].isNil } or: { ~procHud[\view].isClosed }) {
        // try install then render again
        ensureHud.value;
        AppClock.sched(0.05, { renderHud.value; nil });
        ^nil
    };

    lineCurrent = ~procHud[\lineCurrent];
    lineNext    = ~procHud[\lineNext];

    if(lineCurrent.notNil) { lineCurrent.string = "CURRENT: " ++ currentStr };
    if(lineNext.notNil)    { lineNext.string    = "NEXT:    " ++ nextStr };

    nil
};

/********** installer (no FlowLayout; explicit bounds) **********/
ensureHud = {
    AppClock.sched(0, {
        var win, root, box, title, lineA, lineB, r;

        win = findGuiWindow.value;
        if(win.isNil) {
            "[HUD] MagicDisplayGUI window not found yet; will retry on next update".postln;
            ^nil
        };

        root = win.view;

        // if HUD already present and alive, skip
        if(~procHud.notNil and: { ~procHud[\view].notNil } and: { ~procHud[\view].isClosed.not }) {
            ^nil
        };

        r = clampRect.value(root.bounds);

        box = CompositeView(root, r)
            .background_(Color(0.12, 0.12, 0.12, 0.88));

        // title (top-left)
        title = StaticText(box, Rect(8, 6, (r.width - 16).max(80), 16))
            .string_("Processors HUD")
            .stringColor_(Color(0.9,0.9,0.9));

        // lines
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
        nil
    });
};

/********** public API **********/
~procHud_update = {
    var doRender;
    doRender = { renderHud.value };
    AppClock.sched(0.0, { doRender.value; nil });
};

~procHud_install = {
    ensureHud.value;
    AppClock.sched(0.10, { renderHud.value; nil });
};

// install (idempotent) and draw once
~procHud_install.();
)

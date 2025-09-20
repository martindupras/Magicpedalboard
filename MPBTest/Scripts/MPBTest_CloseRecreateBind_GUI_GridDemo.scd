// MPBTest_CloseRecreateBind_GUI_GridDemo.scd
// v0.1.0
// MD 20250920-1919
(
var closeExisting, createGrid, bindAndFill;

closeExisting = {
    AppClock.sched(0.00, {
        var wins;
        wins = Window.allWindows.select({ arg w;
            var nm = w.tryPerform(\name) ? "";
            nm.asString.beginsWith("MagicDisplayGUI")
        });
        wins.do(_.close);
        nil
    });
};

createGrid = {
    AppClock.sched(0.05, {
        ~gui = MagicDisplayGUI_GridDemo.new;
        ~gui.window.front.alwaysOnTop_(true);
        nil
    });
};

bindAndFill = {
    AppClock.sched(0.10, {
        if(~mpb.notNil and: { ~gui.notNil }) {
            ~mpb.setDisplay(~gui);
            ~gui.enableMeters(false);
            ~gui.enableMeters(true);
            ~mpb.printChains;
            ~gui.highlightCurrentColumn(~mpb.effectiveCurrent[0]);
        }{
            "[REBIND] ~mpb or ~gui missing".warn;
        };
        nil
    });
};

closeExisting.value;
createGrid.value;
bindAndFill.value;
)

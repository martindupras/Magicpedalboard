// MPBTest_RebindAndFillGUI.scd
// v0.1.0
// MD 20250920-1919

(
var need;

// 0) Precondition: we want ~mpb and ~gui alive
need = (~mpb.notNil) && (~gui.notNil);
if(need.not) {
    "[REBIND] need ~mpb and ~gui; run MPBTest_BringUp first.".warn;
    ^nil;
};

// 1) If the GUI was created after MPB, bind it now
if(~mpb.display.isNil or: { ~mpb.display !== ~gui }) {
    ~mpb.setDisplay(~gui);
    "[REBIND] bound ~gui to ~mpb".postln;
};

// 2) Make sure it’s in front (and visible)
AppClock.sched(0.02, {
    var w;
    w = ~gui.tryPerform(\window);
    if(w.notNil) { w.front; w.alwaysOnTop_(true) };
    nil
});

// 3) Reattach meters (guards inside GUI)
AppClock.sched(0.04, {
    ~gui.enableMeters(false);
    ~gui.enableMeters(true);
    nil
});

// 4) Fill the chains view now
AppClock.sched(0.06, {
    ~mpb.printChains; // drives showChainsDetailed when a display is bound
    // highlight current column for good measure
    ~gui.highlightCurrentColumn(~mpb.effectiveCurrent[0]);
    nil
});
)

// MPBTest_FreshBootBringUp_Now.scd
// v0.1.1
// MD 20250920-1642

(
var s, startBoot, afterBoot, waitDown, doFreshBoot;

s = Server.default;

afterBoot = {
    AppClock.sched(0.00, {
        ~bring = MPBTest_BringUp.new(true, 2, 0.40, true); // use loud test source & publish tildes
        ~mpb.enforceExclusiveCurrentOptionA(0.1);
        if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false); ~gui.enableMeters(true) };
        nil
    })
};

startBoot = {
    s.doWhenBooted({ afterBoot.value });
    if(s.serverRunning.not) { s.boot };
};

waitDown = {
    if(s.serverRunning.not) { startBoot.value; nil } {
        AppClock.sched(0.05, waitDown)
    }
};

doFreshBoot = {
    if(s.serverRunning) {
        if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false) };
        s.quit;
        AppClock.sched(0.05, waitDown);
    }{
        startBoot.value;
    };
};

doFreshBoot.value;
)

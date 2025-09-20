(
// MPBTest_Run_HealthCheck.scd
// v0.1.2
// MD 20250920-2015

var pass, fail, scen, suite1, suite2, startWhenReady;

pass = 0;
fail = 0;

// Kick bring-up (fresh boot, Grid GUI default, publish tildes)
~bring = MPBTest_BringUp.new(true, 2, 0.40, true, true);

// Poll until bring-up finished and server is running, then start scenarios
startWhenReady = {
    if(
        (~bring.notNil) and: { ~bring.isReady } and: { Server.default.serverRunning }
    ) {
        // Belt-and-braces: keep CURRENT-only invariant and meters attached
        ~mpb.enforceExclusiveCurrentOptionA(0.1);
        if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
            ~gui.enableMeters(false); ~gui.enableMeters(true);
        };

        // Scenario runner (+ default CT path applier if present)
        scen   = MPBTest_Scenario.new(~mpb, ~gui).useDefaultAdapterIfPresent;
        suite1 = MPBTest_AcceptanceSuites.classic(0.12);
        suite2 = MPBTest_AcceptanceSuites.mutatorsBasic(0.12);

        scen.run(suite1);

        AppClock.sched(0.40, {
            MPBTest_Assertions.xorPlaying(false, true).if({ pass = pass + 1 }, { fail = fail + 1 });
            nil
        });

        AppClock.sched(1.40, {
            MPBTest_Assertions.xorPlaying(true, false).if({ pass = pass + 1 }, { fail = fail + 1 });
            nil
        });

        AppClock.sched(2.20, { scen.run(suite2); nil });

        AppClock.sched(3.40, {
            ~mpb.printChains;
            if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
                ~gui.enableMeters(false); ~gui.enableMeters(true);
            };
            ("[HEALTH] PASS=" ++ pass ++ " FAIL=" ++ fail).postln;
            nil
        });

    }{
        AppClock.sched(0.05, startWhenReady);
    };
    nil
};

AppClock.sched(0.00, startWhenReady);
)

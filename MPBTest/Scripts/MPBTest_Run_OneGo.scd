// MPBTest_Run_OneGo.scd
// v0.1.0
// MD 20250920-1608

(
var bring, mpb, gui, scen, steps1, steps2;

bring = MPBTest_BringUp.new(true, 2);
mpb = bring.getPedalboard;
gui = bring.getGui;

scen = MPBTest_Scenario.new(mpb, gui).useDefaultAdapterIfPresent;

steps1 = MPBTest_AcceptanceSuites.classic(0.12);
steps2 = MPBTest_AcceptanceSuites.mutatorsBasic(0.12);

scen.run(steps1);
AppClock.sched(0.40, { MPBTest_Assertions.xorPlaying(false, true);  nil });
AppClock.sched(1.40, { MPBTest_Assertions.xorPlaying(true,  false); nil });

AppClock.sched(2.20, { scen.run(steps2); nil });
)

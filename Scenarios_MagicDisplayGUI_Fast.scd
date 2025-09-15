/* Scenarios_MagicDisplayGUI_Fast.scd
   Purpose: AppClock-driven scenario set (1/2/3). Safe even if internal queue doesn't flush.
   Style: tilde vars, var-first, lowercase, no server.sync, no single-letter locals.
*/

(
// helper: run steps on AppClock with SystemClock pacing
~md_makeFastScenario = {
    |labelString, paceSeconds, stepFuncs|
    var controllerRoutine, totalSteps, stepIndex;

    totalSteps = stepFuncs.size;
    ~mdgTask.notNil.if({ ~mdgTask.stop; ~mdgTask = nil });

    controllerRoutine = Routine({
        stepIndex = 0;
        while({ stepIndex < totalSteps }, {
            AppClock.sched(0, { stepFuncs[stepIndex].value; nil });
            paceSeconds.wait;
            stepIndex = stepIndex + 1;
        });
    });

    ~mdgTask = controllerRoutine.play(SystemClock);
    ~mdgTask
};

// scenario 1 (duplicate of runner’s, kept here so all three live together)
~scenario1v6_fast = {
    var paceSeconds, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };

    paceSeconds = 0.8;
    steps = [
        { "[SC] init".postln; ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { "[SC] add flanger".postln; ~gui.showExpectation("Command: add flanger", 0); ~mpb.add(\flanger); ~refreshGuiFromMpb.() },
        { "[SC] bypass flanger true".postln; ~gui.showExpectation("Command: bypass flanger true", 0); ~mpb.bypass(\flanger, true); ~refreshGuiFromMpb.() },
        { "[SC] add delay".postln; ~gui.showExpectation("Command: add delay", 0); ~mpb.add(\delay); ~refreshGuiFromMpb.() },
        { "[SC] clear NEXT".postln; ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    ~md_makeFastScenario.("scenario1-fast", paceSeconds, steps);
};

// scenario 2
~scenario2v6_fast = {
    var paceSeconds, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };

    paceSeconds = 0.25;
    steps = [
        { "[SC] init".postln; ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { "[SC] add chorus".postln; ~gui.showExpectation("Command: add chorus", 0); ~mpb.add(\chorus); ~refreshGuiFromMpb.() },
        { "[SC] add reverb".postln; ~gui.showExpectation("Command: add reverb", 0); ~mpb.add(\reverb); ~refreshGuiFromMpb.() },
        { "[SC] add tremolo".postln; ~gui.showExpectation("Command: add tremolo", 0); ~mpb.add(\tremolo); ~refreshGuiFromMpb.() },
        { "[SC] removeAt 2".postln; ~gui.showExpectation("Command: removeAt 2", 0); ~mpb.removeAt(2); ~refreshGuiFromMpb.() },
        { "[SC] add phaser".postln; ~gui.showExpectation("Command: add phaser", 0); ~mpb.add(\phaser); ~refreshGuiFromMpb.() },
        { "[SC] clear NEXT".postln; ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    ~md_makeFastScenario.("scenario2-fast", paceSeconds, steps);
};

// scenario 3
~scenario3v6_fast = {
    var paceSeconds, steps;
    if(~mpb.isNil or: { ~gui.isNil }) { "Run ~bootGuiV6.() first.".warn; ^nil };

    paceSeconds = 0.6;
    steps = [
        { "[SC] init".postln; ~gui.showExpectation("Command: init", 0); ~refreshGuiFromMpb.() },
        { "[SC] add bitcrusher".postln; ~gui.showExpectation("Command: add bitcrusher", 0); ~mpb.add(\bitcrusher); ~refreshGuiFromMpb.() },
        { "[SC] bypass bitcrusher false".postln; ~gui.showExpectation("Command: bypass bitcrusher false", 0); ~mpb.bypass(\bitcrusher, false); ~refreshGuiFromMpb.() },
        { "[SC] removeAt 1".postln; ~gui.showExpectation("Command: removeAt 1", 0); ~mpb.removeAt(1); ~refreshGuiFromMpb.() },
        { "[SC] clear NEXT".postln; ~gui.showExpectation("Command: clear NEXT", 0); ~mpb.clearChain; ~refreshGuiFromMpb.() }
    ];
    ~md_makeFastScenario.("scenario3-fast", paceSeconds, steps);
};
)

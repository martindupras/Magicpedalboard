// CTQ_HardStop_All_Runners.scd
// v0.1.1
// MD 2025-09-18 15:18 BST

// Purpose:
// - Stop any leftover Routine/Task and cancel any pending AppClock chain (generation bump).
// Style:
// - var-first; lowercase; no server.sync.

(
var hadRunner, hadTask, oldGen;
hadRunner = (~ctq_runner.notNil) and: { ~ctq_runner.isPlaying };
hadTask   = (~ctq_task.notNil)   and: { ~ctq_task.isPlaying };

if(hadRunner) { ~ctq_runner.stop };
if(hadTask)   { ~ctq_task.stop };

~ctq_runner = nil;
~ctq_task   = nil;

oldGen = ~ctq_gen ? 0;
~ctq_gen = oldGen + 1;

("[TOKENS] HARD STOP — runner=% task=% gen=%"
    .format(hadRunner, hadTask, ~ctq_gen)).postln;
)

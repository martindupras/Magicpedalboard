// Adapter_UIHook_Install.scd
// v0.2.0
// MD 20250918-20:10 BST

/* Purpose
   - Wrap ~ct_applyOSCPathToMPB to call ~procHud_update after each token apply.
   - No behavior change to your adapter's logic.

   Style
   - var-first; lowercase; AppClock for UI calls; no server.sync.
*/

(
var wrap;

if(~ct_applyOSCPathToMPB.isNil) {
    "[UIHOOK] ~ct_applyOSCPathToMPB is nil; load the adapter file first.".warn;
    ^nil
};

if(~ct_applyOSCPathToMPB_orig.isNil) {
    ~ct_applyOSCPathToMPB_orig = ~ct_applyOSCPathToMPB;
};

wrap = { arg pathString, mpb, gui;
    var result;
    result = ~ct_applyOSCPathToMPB_orig.(pathString, mpb, gui);
    if(~procHud_update.notNil) {
        AppClock.sched(0.0, { ~procHud_update.(); nil });
    };
    result
};

~ct_applyOSCPathToMPB = wrap;
"[UIHOOK] adapter UI hook installed".postln;
)

// Patch_StartHere_Milestone_BringUpAndRun_freshBoot_Fix.scd
// v0.1.4a
// MD 20250918-18:02 BST

/* Purpose
   Replace the freshBoot step with a doWhenBooted-aware version that proceeds even if
   the server is already booting. Avoids stalls at "already booting". No server.sync.

   Style
   - var-first in every function/closure; lowercase method names; no server.sync
   - server ops inside Server.default.bind; GUI on AppClock
*/

(
var replaceFreshBoot;

replaceFreshBoot = {
    var serverRef, didInitFlag, doInitTreeFunc, safeInitOnceFunc, startBootFunc;

    serverRef = Server.default;
    didInitFlag = false;

    doInitTreeFunc = {
        var ignore;
        if(didInitFlag) { ^nil };
        didInitFlag = true;
        ignore = nil;
        Server.default.bind({
            serverRef.initTree;
            serverRef.defaultGroup.freeAll;
        });
        MagicDisplay.setMeterChannels(2);
        "[RUN] server tree inited; meter defs set to 2ch".postln;
    };

    safeInitOnceFunc = {
        // Guard against multiple signals (doWhenBooted + polls)
        if(serverRef.serverRunning) { doInitTreeFunc.value };
    };

    // Subscribe once; SC clears the function after it fires
    serverRef.doWhenBooted({ AppClock.sched(0, { safeInitOnceFunc.value; nil }) });

    if(serverRef.serverRunning) {
        "[RUN] fresh boot: quitting current server…".postln;
        serverRef.quit;
        AppClock.sched(0.05, {
            var waitDown;
            waitDown = {
                if(serverRef.serverRunning.not and: { serverRef.booting.not }) {
                    serverRef.boot;
                    nil
                }{
                    AppClock.sched(0.05, waitDown)
                }
            };
            waitDown.value;
            nil
        });
    }{
        // server not running
        if(serverRef.booting) {
            "[RUN] server is already booting; will init when boot completes…".postln;
            // doWhenBooted will trigger doInitTreeFunc
        }{
            "[RUN] fresh boot: starting server…".postln;
            serverRef.boot;
        };
    };
};

freshBoot = replaceFreshBoot; // replace original binding in the script runtime
)

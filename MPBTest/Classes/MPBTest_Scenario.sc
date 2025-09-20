// MPBTest_Scenario.sc
// v0.2.2
// MD 20250920-2015

// Purpose
// - Timed acceptance runner (add/insert/addAt/removeAt/swap/bypass/.../switch/wait)
//   with optional CommandTree path hook via .setPathApplier.
// - Removes caret-returns from AppClock closures to avoid OutOfContextReturnError.
// Style
// - var-first; lowercase; AppClock scheduling; no server.sync.

MPBTest_Scenario : Object {
    classvar < version;
    var < pedalboard, < gui, < logger;
    var pathApplierFunc;

    *initClass { version = "v0.2.2" }

    *new { arg mpb, guiObj = nil; ^super.new.init(mpb, guiObj) }

    init { arg mpb, guiObj;
        var lg;
        pedalboard = mpb;
        gui = guiObj;
        logger = MDMiniLogger.new("MPBTest_Scenario");
        pathApplierFunc = nil;
        ^this
    }

    setPathApplier { arg func;
        pathApplierFunc = func;
        ^this
    }

    useDefaultAdapterIfPresent {
        if(pathApplierFunc.isNil and: { ~ct_applyOSCPathToMPB.notNil }) {
            pathApplierFunc = { arg pathString;
                ~ct_applyOSCPathToMPB.(pathString.asString, pedalboard, gui);
            };
            logger.info("Using ~ct_applyOSCPathToMPB as default path applier.");
        };
        ^this
    }

    run { arg stepsArray;
        var indexCounter, totalCount, runOne;

        this.useDefaultAdapterIfPresent;

        indexCounter = 0;
        totalCount   = stepsArray.size;

        runOne = {
            var stepDict, verb, args, hasMore;

            hasMore = indexCounter < totalCount;

            if(hasMore) {
                stepDict = stepsArray[indexCounter];
                verb = stepDict[\verb];
                args = stepDict[\args] ? [];

                this.applyStep(verb, args);

                indexCounter = indexCounter + 1;

                // Schedule next step tick; explicit \wait steps still add their own delay.
                AppClock.sched(0.20, { runOne.value; nil });
            }{
                // finished; nothing to return from a scheduled closure
                logger.info("scenario complete (" ++ totalCount ++ " steps).");
            };
            nil
        };

        AppClock.sched(0.00, { runOne.value; nil });
        ^this
    }

    applyStep { arg verb, args;
        var v, brief;
        v = verb;
        brief = {
            pedalboard.printChains;
            this.refreshGui;
        };

        switch(v,
            \wait, {
                var delaySec;
                delaySec = (args[0] ? 0.25).asFloat.max(0.0);
                AppClock.sched(delaySec, { nil }); // no return
            },

            \add, {
                var proc;
                proc = args[0];
                pedalboard.add(proc);
                brief.value;
            },

            \insert, { // alias of add
                var proc;
                proc = args[0];
                pedalboard.add(proc);
                brief.value;
            },

            \addAt, {
                var proc, idx;
                proc = args[0];
                idx  = (args[1] ? 1).asInteger;
                pedalboard.addAt(proc, idx);
                brief.value;
            },

            \removeAt, {
                var idx;
                idx = (args[0] ? 1).asInteger;
                pedalboard.removeAt(idx);
                brief.value;
            },

            \swap, {
                var idxA, idxB;
                idxA = (args[0] ? 1).asInteger;
                idxB = (args[1] ? 2).asInteger;
                pedalboard.swap(idxA, idxB);
                brief.value;
            },

            \bypass, { // NEXT chain
                var key, stateSym, state;
                key = args[0];
                stateSym = args[1] ? \on;
                state = (stateSym == \on) or: { stateSym == \true } or: { stateSym == 1 };
                pedalboard.bypass(key, state);
                brief.value;
            },

            \unbypass, {
                var key;
                key = args[0];
                pedalboard.bypass(key, false);
                brief.value;
            },

            \bypassCurrent, {
                var key, state;
                key   = args[0];
                state = (args[1] ? true);
                pedalboard.bypassCurrent(key, state);
                brief.value;
            },

            \bypassAt, {
                var indexParam, stateParam;
                indexParam = (args[0] ? 1).asInteger;
                stateParam = (args[1] ? true);
                pedalboard.bypassAt(indexParam, stateParam);
                brief.value;
            },

            \bypassAtCurrent, {
                var indexParam, stateParam;
                indexParam = (args[0] ? 1).asInteger;
                stateParam = (args[1] ? true);
                pedalboard.bypassAtCurrent(indexParam, stateParam);
                brief.value;
            },

            \setSource, {
                var key;
                key = args[0] ? \testmelody;
                pedalboard.setSource(key);
                brief.value;
            },

            \setSourceCurrent, {
                var key;
                key = args[0] ? \testmelody;
                pedalboard.setSourceCurrent(key);
                brief.value;
            },

            \switch, {
                var fade;
                fade = (args[0] ? 0.12).asFloat.clip(0.08, 0.20);
                if(pedalboard.effectiveNext.last == \ts0) {
                    if(pathApplierFunc.notNil) { pathApplierFunc.value("/setSource/testmelody") } {
                        pedalboard.setSource(\testmelody);
                    };
                };
                pedalboard.switchChain(fade);
                this.refreshGui;
            },

            \ctPath, {
                var path;
                path = args[0].asString;
                if(pathApplierFunc.notNil) { pathApplierFunc.value(path) } {
                    logger.warn("[ctPath] adapter missing; ignored: " ++ path);
                };
                this.refreshGui;
            },

            { logger.warn("Unknown step: " ++ v.asString) }
        );
    }

    refreshGui {
        if(gui.notNil and: { gui.respondsTo(\showChainsDetailed) }) {
            var effC, effN;
            effC = pedalboard.effectiveCurrent;
            effN = pedalboard.effectiveNext;
            gui.highlightCurrentColumn(effC[0]);
            gui.showChainsDetailed(effC, effN, pedalboard.bypassKeysCurrent, pedalboard.bypassKeysNext, effC, effN);
        };
    }
}

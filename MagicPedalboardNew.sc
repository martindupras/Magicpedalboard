/*  MagicPedalboardNew.sc  v0.3.3
    A/B pedalboard chain manager built on Ndefs.
    - Chains are Arrays of Symbols ordered [sink, …, source].
    - Uses JITLib embedding: Ndef(left) <<> Ndef(right).
    - Creates two sinks: \chainA and \chainB, and plays the current chain on init.
    - Most mutators act on the next chain; explicit current-chain bypass helpers are provided.
    - Optional display adaptor (MagicDisplay) receives notifications, including detailed chain views.
    // MD 20250912-1345
*/

MagicPedalboardNew : Object {

    // ───────────────────────────────────────────────────────────────
    // class metadata
    // ───────────────────────────────────────────────────────────────
    classvar < version;

    // ───────────────────────────────────────────────────────────────
    // instance state
    // ───────────────────────────────────────────────────────────────
    var < currentChain;      // read-only pointer
    var < nextChain;         // read-only pointer

    var chainAList;          // [\chainA, ...processors..., source]
    var chainBList;          // [\chainB, ...processors..., source]

    var bypassA;             // IdentityDictionary: key(Symbol) -> Bool
    var bypassB;             // IdentityDictionary: key(Symbol) -> Bool

    var < defaultNumChannels;
    var < defaultSource;

    // optional display adaptor (console now, GUI later)
    var < display;

    *initClass {
        version = "v0.3.2";
        ("MagicPedalboardNew " ++ version).postln;
    }

    *new { |disp = nil|
        ^super.new.init(disp)
    }

    init { |disp|
        var sinkFunc;

        display = disp;

        defaultNumChannels = 2;
        defaultSource = \ts0;

        sinkFunc = {
            var inputSignal;
            inputSignal = \in.ar(defaultNumChannels);
            inputSignal
        };

        Ndef(\chainA, sinkFunc);
        Ndef(\chainB, sinkFunc);

        chainAList = [\chainA, defaultSource];
        chainBList = [\chainB, defaultSource];

        bypassA = IdentityDictionary.new;
        bypassB = IdentityDictionary.new;

        currentChain = chainAList;
        nextChain = chainBList;

        // initial wiring + start
        this.rebuild(currentChain);
        this.rebuild(nextChain);
        Server.default.bind({ Ndef(\chainA).play(numChannels: defaultNumChannels) });

        if(display.notNil) {
            display.showInit(this, version, currentChain, nextChain);
        };

        ^this
    }

    // ───────────────────────────────────────────────────────────────
    // public API
    // ───────────────────────────────────────────────────────────────

    setDisplay { |disp|
        display = disp;
        if(display.notNil) {
            display.showInit(this, version, currentChain, nextChain);
        };
    }

    help {
        var text;
        text = String.new;
        text = text
        ++ "MagicPedalboardNew " ++ version ++ "\n"
        ++ "Chains are Arrays of Symbols ordered [sink, …, source].\n"
        ++ "On init, creates \\chainA and \\chainB and plays current.\n\n"
        ++ "Core methods (operate mostly on the *next* chain):\n"
        ++ "  printChains\n"
        ++ "  playCurrent, stopCurrent, switchChain\n"
        ++ "  add(key), addAt(key, index)\n"
        ++ "  removeAt(index), swap(indexA, indexB)\n"
        ++ "  bypass(key, state=true), bypassAt(index, state=true)\n"
        ++ "  clearChain\n"
        ++ "Current-chain bypass helpers:\n"
        ++ "  bypassCurrent(key, state=true), bypassAtCurrent(index, state=true)\n"
        ++ "Diagnostics/helpers:\n"
        ++ "  effectiveCurrent, effectiveNext, bypassKeysCurrent, bypassKeysNext, reset\n"
        ++ "Source setters:\n"
        ++ "  setSource(key) [next], setSourceCurrent(key) [current]\n";
        text.postln;
    }

    // Detailed printing routed through display if available
    printChains {
        var bypassAKeys, bypassBKeys, effA, effB;

        bypassAKeys = this.bypassKeysForListInternal(chainAList);
        bypassBKeys = this.bypassKeysForListInternal(chainBList);

        effA = this.effectiveListForInternal(chainAList);
        effB = this.effectiveListForInternal(chainBList);

        if(display.notNil and: { display.respondsTo(\showChainsDetailed) }) {
            display.showChainsDetailed(
                chainAList, chainBList,
                bypassAKeys, bypassBKeys,
                effA, effB
            );
        }{
            "— Chains —".postln;
            "MagicPedalboardNew.printChains:".postln;
            ("A: " ++ chainAList ++ (if(chainAList === currentChain) { "  (current)" } { "  (next)" })).postln;
            ("   bypassA: " ++ bypassAKeys).postln;
            ("   effA:    " ++ effA).postln;
            ("B: " ++ chainBList ++ (if(chainBList === currentChain) { "  (current)" } { "  (next)" })).postln;
            ("   bypassB: " ++ bypassBKeys).postln;
            ("   effB:    " ++ effB).postln;
            "".postln;
        };
    }

    playCurrent {
        var sinkKey;
        sinkKey = currentChain[0];
        this.rebuild(currentChain);
        Server.default.bind({ Ndef(sinkKey).play(numChannels: defaultNumChannels) });
        if(display.notNil) { display.showPlay(sinkKey) };
    }

    stopCurrent {
        var sinkKey;
        sinkKey = currentChain[0];
        Server.default.bind({ Ndef(sinkKey).stop });
        if(display.notNil) { display.showStop(sinkKey) };
    }

    switchChain {
        var tempChainRef, oldSinkKey, newSinkKey;

        oldSinkKey = currentChain[0];

        Server.default.bind({
            // stop old current sink
            Ndef(oldSinkKey).stop;

            // swap pointers
            tempChainRef = currentChain;
            currentChain = nextChain;
            nextChain = tempChainRef;

            // rebuild both without nesting binds
            this.rebuildUnbound(nextChain);
            this.rebuildUnbound(currentChain);

            // start new current sink
            newSinkKey = currentChain[0];
            Ndef(newSinkKey).play(numChannels: defaultNumChannels);
        });

        if(display.notNil) {
            display.showSwitch(oldSinkKey, currentChain[0], currentChain, nextChain);
        };
    }

	// added fade version
switchChainWithFade {
    var tempChainRef, oldSinkKey, newSinkKey, fadeTime;
    fadeTime = 0.1; // seconds

    oldSinkKey = currentChain[0];
    newSinkKey = nextChain[0];

    Server.default.bind {
        // fade out old sink
        Ndef(oldSinkKey).fadeTime_(fadeTime);
        Ndef(oldSinkKey).stop;

        // swap chains
        tempChainRef = currentChain;
        currentChain = nextChain;
        nextChain = tempChainRef;

        // rebuild both chains
        this.rebuildUnbound(nextChain);
        this.rebuildUnbound(currentChain);

        // fade in new sink
        Ndef(newSinkKey).fadeTime_(fadeTime);
        Ndef(newSinkKey).play(numChannels: defaultNumChannels);
    };

    if(display.notNil) {
        display.showSwitch(oldSinkKey, currentChain[0], currentChain, nextChain);
    };
}


    // ---- next-chain mutations ------------------------------------------------

    add { | key |
        var insertIndex;
        insertIndex = nextChain.size - 1;
        this.addAt(key, insertIndex);
        if(display.notNil) { display.showMutation(\add, [key], nextChain) };
    }

    addAt { | key, index |
        var indexClamped, newList;
        indexClamped = index.clip(1, nextChain.size - 1);
        newList = nextChain.insert(indexClamped, key);
        this.setNextListInternal(newList);
        this.rebuild(nextChain);
        if(display.notNil) { display.showMutation(\addAt, [key, indexClamped], nextChain) };
    }

    removeAt { | index |
        var sizeNow, lastIndex, newList, removedKey;

        sizeNow = nextChain.size;
        lastIndex = sizeNow - 1;

        if(sizeNow <= 2) {
            if(display.notNil) { display.showError("removeAt refused: need at least [sink, source]") }
            { "refuse to remove: need at least [sink, source]".postln };
        }{
            if((index == 0) or: { index == lastIndex }) {
                if(display.notNil) { display.showError("removeAt refused: cannot remove sink or source") }
                { "refuse to remove sink or source".postln };
            }{
                removedKey = nextChain[index];
                newList = nextChain.copy;
                newList.removeAt(index);
                this.setNextListInternal(newList);
                this.bypassDictForListInternal(nextChain).removeAt(removedKey);
                this.rebuild(nextChain);
                if(display.notNil) { display.showMutation(\removeAt, [index, removedKey], nextChain) };
            }
        }
    }

    swap { | indexAParam, indexBParam |
        var lastIndex, indexA, indexB, newList, tempKey;

        lastIndex = nextChain.size - 1;

        indexA = indexAParam.clip(1, lastIndex - 1);
        indexB = indexBParam.clip(1, lastIndex - 1);

        if(indexA == indexB) {
            // nothing to do
        }{
            newList = nextChain.copy;
            tempKey = newList[indexA];
            newList[indexA] = newList[indexB];
            newList[indexB] = tempKey;
            this.setNextListInternal(newList);
            this.rebuild(nextChain);
            if(display.notNil) { display.showMutation(\swap, [indexA, indexB], nextChain) };
        }
    }

    clearChain {
        var sinkKey, sourceKey, newList;

        if(nextChain.size < 2) { ^this };

        sinkKey = nextChain[0];
        sourceKey = nextChain[nextChain.size - 1];

        newList = [sinkKey, sourceKey];
        this.setNextListInternal(newList);
        this.bypassDictForListInternal(nextChain).clear;
        this.rebuild(nextChain);
        if(display.notNil) { display.showMutation(\clearChain, [], nextChain) };
    }

    bypass { | key, state = true |
        var dict;
        dict = this.bypassDictForListInternal(nextChain);
        dict[key] = state;
        this.rebuild(nextChain);
        if(display.notNil) {
            display.showBypass(\next, key, state, nextChain, this.bypassKeysForListInternal(nextChain));
        };
    }

    bypassAt { | index, state = true |
        var lastIndex, clampedIndex, keyAtIndex;
        lastIndex = nextChain.size - 1;
        clampedIndex = index.clip(1, lastIndex - 1);
        keyAtIndex = nextChain[clampedIndex];
        this.bypass(keyAtIndex, state);
    }

    // ---- current-chain bypass ------------------------------------------------

    bypassCurrent { | key, state = true |
        var dict;
        dict = this.bypassDictForListInternal(currentChain);
        dict[key] = state;
        this.rebuild(currentChain);
        if(display.notNil) {
            display.showBypass(\current, key, state, currentChain, this.bypassKeysForListInternal(currentChain));
        };
    }

    bypassAtCurrent { | index, state = true |
        var lastIndex, clampedIndex, keyAtIndex;
        lastIndex = currentChain.size - 1;
        clampedIndex = index.clip(1, lastIndex - 1);
        keyAtIndex = currentChain[clampedIndex];
        this.bypassCurrent(keyAtIndex, state);
    }

    // ---- source setters (built-in) ------------------------------------------

    setSource { | key |
        var newList, lastIndex;
        lastIndex = nextChain.size - 1;
        newList = nextChain.copy;
        newList[lastIndex] = key;
        this.setNextListInternal(newList);
        this.rebuild(nextChain);
        if(display.notNil) { display.showMutation(\setSource, [key], nextChain) };
    }

    setSourceCurrent { | key |
        var newList, lastIndex;
        lastIndex = currentChain.size - 1;
        newList = currentChain.copy;
        newList[lastIndex] = key;
        if(currentChain === chainAList) {
            chainAList = newList; currentChain = chainAList;
        }{
            chainBList = newList; currentChain = chainBList;
        };
        this.rebuild(currentChain);
        if(display.notNil) { display.showMutation(\setSourceCurrent, [key], currentChain) };
    }

    // ---- diagnostics helpers -------------------------------------------------

    effectiveCurrent { ^this.effectiveListForInternal(currentChain) }
    effectiveNext    { ^this.effectiveListForInternal(nextChain) }
    bypassKeysCurrent { ^this.bypassKeysForListInternal(currentChain) }
    bypassKeysNext    { ^this.bypassKeysForListInternal(nextChain) }

    reset {
        var sinkAKey, sinkBKey;

        sinkAKey = \chainA;
        sinkBKey = \chainB;

        chainAList = [sinkAKey, defaultSource];
        chainBList = [sinkBKey, defaultSource];

        bypassA.clear;
        bypassB.clear;

        currentChain = chainAList;
        nextChain = chainBList;

        Server.default.bind({
            this.rebuildUnbound(nextChain);
            this.rebuildUnbound(currentChain);
            Ndef(sinkBKey).stop;
            Ndef(sinkAKey).play(numChannels: defaultNumChannels);
        });

        if(display.notNil) { display.showReset(currentChain, nextChain) };
    }

    // ───────────────────────────────────────────────────────────────
    // internal helpers (lowercase, no leading underscore)
    // ───────────────────────────────────────────────────────────────

    setNextListInternal { | newList |
        if(nextChain === chainAList) {
            chainAList = newList; nextChain = chainAList;
        }{
            chainBList = newList; nextChain = chainBList;
        }
    }

    bypassDictForListInternal { | listRef |
        ^if(listRef === chainAList) { bypassA } { bypassB }
    }

    bypassKeysForListInternal { | listRef |
        var dict, keysBypassed;

        dict = this.bypassDictForListInternal(listRef);
        keysBypassed = Array.new;

        dict.keysValuesDo { |key, state|
            if(state == true) { keysBypassed = keysBypassed.add(key) };
        };

        ^keysBypassed
    }

    ensureStereoInternal { | key |
        var proxyBus;
        proxyBus = Ndef(key).bus;
        if(proxyBus.isNil or: { proxyBus.rate != \audio } or: { proxyBus.numChannels != defaultNumChannels }) {
            Ndef(key).ar(defaultNumChannels);
        };
    }

    ensureServerTree {
        if(Server.default.serverRunning) {
            Server.default.initTree;
        };
    }

    effectiveListForInternal { | listRef |
        var dict, resultList, lastIndex;

        dict = this.bypassDictForListInternal(listRef);
        resultList = Array.new;
        lastIndex = listRef.size - 1;

        listRef.do { |key, indexPosition|
            var isProcessor, isBypassed;
            isProcessor = (indexPosition > 0) and: (indexPosition < lastIndex);
            isBypassed = isProcessor and: { dict[key] == true };
            if((indexPosition == 0) or: { indexPosition == lastIndex }) {
                resultList = resultList.add(key);
            }{
                if(isBypassed.not) { resultList = resultList.add(key) };
            };
        };

        ^resultList
    }

    // Public rebuild: bundles server ops
    rebuild { | listRef |
        var whichChain;
        whichChain = if(listRef === currentChain) { \current } { \next };

        Server.default.bind({
            this.rebuildUnbound(listRef);
        });

        if(display.notNil) {
            display.showRebuild(whichChain, listRef, this.effectiveListForInternal(listRef));
        };
    }

    // Internal rebuild that assumes we are already inside a server bind
    rebuildUnbound { | listRef |
        var effective, indexCounter, leftKey, rightKey, sinkKey;

        if(listRef.size < 2) { ^this };

        this.ensureServerTree;

        effective = this.effectiveListForInternal(listRef);

        effective.do { |keySymbol|
            this.ensureStereoInternal(keySymbol)
        };

        indexCounter = 0;
        while { indexCounter < (effective.size - 1) } {
            leftKey = effective[indexCounter];
            rightKey = effective[indexCounter + 1];
            Ndef(leftKey) <<> Ndef(rightKey);
            indexCounter = indexCounter + 1;
        };

        sinkKey = effective[0];

        if(listRef === currentChain) {
            Ndef(sinkKey).play(numChannels: defaultNumChannels);
        }{
            Ndef(sinkKey).stop;
        };
    }
}

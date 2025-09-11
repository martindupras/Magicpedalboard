/*  MagicPedalboardNew.sc
    A/B pedalboard chain manager built on Ndefs.
    - Chains are Arrays of Symbols ordered [sink, …, source].
    - Uses JITLib embedding: Ndef(left) <<> Ndef(right).
    - Creates two sinks: \chainA and \chainB, and plays the current chain on init.
    - Most mutators act on the next chain; explicit current-chain bypass helpers are provided.
*/

MagicPedalboardNew : Object {

    // ───────────────────────────────────────────────────────────────
    // class metadata
    // ───────────────────────────────────────────────────────────────
    classvar < version = "v0.1.3";

    // ───────────────────────────────────────────────────────────────
    // instance state
    // ───────────────────────────────────────────────────────────────
    var < currentChain;   // points to either chainAList or chainBList
    var < nextChain;      // points to the other list
    var chainAList;       // [\chainA, ...processors..., source]
    var chainBList;       // [\chainB, ...processors..., source]

    var bypassA;          // IdentityDictionary: key(Symbol) -> Bool (true = bypassed)
    var bypassB;          // IdentityDictionary: key(Symbol) -> Bool (true = bypassed)

    var defaultNumChannels;
    var defaultSource;

    // ───────────────────────────────────────────────────────────────
    // class init
    // ───────────────────────────────────────────────────────────────
    *initClass {
        //version = "v0.1.3";
        ("MagicPedalboardNew " ++ version).postln;
    }

    *new {
        ^super.new.init
    }

    // ───────────────────────────────────────────────────────────────
    // init & sinks
    // ───────────────────────────────────────────────────────────────
    init {
        var sinkFunc;

        defaultNumChannels = 2;
        defaultSource = \ts0; // silent by default; tests set audible sources
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

        this.rebuild(currentChain);
        this.rebuild(nextChain);
        Ndef(\chainA).play(numChannels: defaultNumChannels);

        ^this
    }

    // ───────────────────────────────────────────────────────────────
    // public API
    // ───────────────────────────────────────────────────────────────
    help {
        var helpText;
        helpText = String.new;
        helpText = helpText
        ++ "MagicPedalboardNew " ++ version ++ "\n"
        ++ "Chains are Arrays of Symbols ordered [sink, …, source].\n"
        ++ "On init, creates \\chainA and \\chainB and plays current.\n\n"
        ++ "Core methods (mostly operate on the *next* chain):\n"
        ++ "  printChains\n"
        ++ "  playCurrent, stopCurrent, switchChain\n"
        ++ "  add(key), addAt(key, index)\n"
        ++ "  removeAt(index), swap(indexA, indexB)\n"
        ++ "  bypass(key, state=true), bypassAt(index, state=true)\n"
        ++ "  clearChain\n"
        ++ "Current-chain bypass helpers:\n"
        ++ "  bypassCurrent(key, state=true), bypassAtCurrent(index, state=true)\n";
        helpText.postln;
    }

    printChains {
        var annotateCurrent, annotateNext;
        annotateCurrent = { |listRef| if(listRef === currentChain) { "  (current)" } { "" } };
        annotateNext = { |listRef| if(listRef === nextChain) { "  (next)" } { "" } };

        "MagicPedalboardNew.printChains:".postln;

        ("A: " ++ chainAList ++ annotateCurrent.(chainAList) ++ annotateNext.(chainAList)).postln;
        ("   bypassA: " ++ this.bypassKeysForListInternal(chainAList)).postln;

        ("B: " ++ chainBList ++ annotateCurrent.(chainBList) ++ annotateNext.(chainBList)).postln;
        ("   bypassB: " ++ this.bypassKeysForListInternal(chainBList)).postln;
    }

    playCurrent {
        var sinkKey;
        sinkKey = currentChain[0];
        this.rebuild(currentChain);
        Ndef(sinkKey).play(numChannels: defaultNumChannels);
    }

    stopCurrent {
        var sinkKey;
        sinkKey = currentChain[0];
        Ndef(sinkKey).stop;
    }

    switchChain {
        var tempChainRef, oldSinkKey, newSinkKey;

        oldSinkKey = currentChain[0];
        Ndef(oldSinkKey).stop;

        tempChainRef = currentChain;
        currentChain = nextChain;
        nextChain = tempChainRef;

        this.rebuild(nextChain);
        this.rebuild(currentChain);

        newSinkKey = currentChain[0];
        Ndef(newSinkKey).play(numChannels: defaultNumChannels);
    }

    // ---- next-chain mutations ------------------------------------------------

    add { | key |
        var insertIndex;
        insertIndex = nextChain.size - 1; // just before source
        this.addAt(key, insertIndex);
    }

    addAt { | key, index |
        var indexClamped, newList;
        indexClamped = index.clip(1, nextChain.size - 1); // never before sink
        newList = nextChain.insert(indexClamped, key);    // returns a new Array
        this.setNextListInternal(newList);
        this.rebuild(nextChain);
    }

    removeAt { | index |
        var sizeNow, lastIndex, newList, removedKey;

        sizeNow = nextChain.size;
        lastIndex = sizeNow - 1;

        if(sizeNow <= 2) {
            "refuse to remove: need at least [sink, source]".postln;
        }{
            if((index == 0) or: { index == lastIndex }) {
                "refuse to remove sink or source".postln;
            }{
                removedKey = nextChain[index];
                newList = nextChain.copy;
                newList.removeAt(index);

                this.setNextListInternal(newList);
                this.bypassDictForListInternal(nextChain).removeAt(removedKey);

                this.rebuild(nextChain);
                ("removed: " ++ removedKey).postln;
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
    }

    bypass { | key, state = true |
        var dict;
        dict = this.bypassDictForListInternal(nextChain);
        dict[key] = state;
        this.rebuild(nextChain);
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
    }

    bypassAtCurrent { | index, state = true |
        var lastIndex, clampedIndex, keyAtIndex;
        lastIndex = currentChain.size - 1;
        clampedIndex = index.clip(1, lastIndex - 1);
        keyAtIndex = currentChain[clampedIndex];
        this.bypassCurrent(keyAtIndex, state);
    }

    // ---- optional: set source (handy for tests) ------------------------------

    setSource { | key |
        var newList, lastIndex;
        lastIndex = nextChain.size - 1;
        newList = nextChain.copy;
        newList[lastIndex] = key;
        this.setNextListInternal(newList);
        this.rebuild(nextChain);
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
            Ndef(key).ar(defaultNumChannels);  // pre-arm bus as audio/stereo
        };
    }

    effectiveListForInternal { | listRef |
        var dict, resultList, lastIndex;

        dict = this.bypassDictForListInternal(listRef);
        resultList = Array.new;
        lastIndex = listRef.size - 1;

        listRef.do { |key, index|
            var isProcessor, isBypassed;
            isProcessor = (index > 0) and: (index < lastIndex);
            isBypassed = isProcessor and: { dict[key] == true };

            if((index == 0) or: { index == lastIndex }) {
                resultList = resultList.add(key);            // keep sink & source
            }{
                if(isBypassed.not) {
                    resultList = resultList.add(key);        // keep only non-bypassed processors
                };
            };
        };

        ^resultList
    }

    rebuild { | listRef |
        var effective, index, leftKey, rightKey, sinkKey;

        if(listRef.size < 2) { ^this };

        effective = this.effectiveListForInternal(listRef);

        effective.do { |key| this.ensureStereoInternal(key) };

        index = 0;
        while { index < (effective.size - 1) } {
            leftKey = effective[index];
            rightKey = effective[index + 1];
            Ndef(leftKey) <<> Ndef(rightKey);
            index = index + 1;
        };

        sinkKey = effective[0];

        if(listRef === currentChain) {
            Ndef(sinkKey).play(numChannels: defaultNumChannels);
        }{
            Ndef(sinkKey).stop;
        };
    }
}

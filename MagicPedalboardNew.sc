/*  MagicPedalboardNew.sc
    A/B pedalboard chain manager built on Ndefs.
    - Chains are Arrays of Symbols ordered [sink, …, source].
    - Uses JITLib embedding: Ndef(left) <<> Ndef(right).
    - Creates two sinks: \chainA and \chainB, and plays the current chain on init.
    - Most mutators act on next chain; bypass and bypassAt also provided for current chain.
*/

MagicPedalboardNew : Object {

    // ───────────────────────────────────────────────────────────────
    // class metadata
    // ───────────────────────────────────────────────────────────────
    classvar < version = "v0.0";

    // ───────────────────────────────────────────────────────────────
    // instance state
    // ───────────────────────────────────────────────────────────────
    var < currentChain;   // points to either chainAList or chainBList (read-only getter)
    var < nextChain;      // points to the other list (read-only getter)

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
        version = "0.1.0";
    }

    *new {
        ^super.new.init
    }

    // ───────────────────────────────────────────────────────────────
    // init & sinks
    // ───────────────────────────────────────────────────────────────
    init {
        var sinkFunc;

        // declare all variables first (style)
        defaultNumChannels = 2;
        // choose a sensible silent default; test code will set an audible source
        defaultSource = \ts0;

        // create two sinks that just pass through \in in stereo
        sinkFunc = {
            var inSig;
            inSig = \in.ar(defaultNumChannels);
            inSig
        };

        Ndef(\chainA, sinkFunc);
        Ndef(\chainB, sinkFunc);

        chainAList = [\chainA, defaultSource];
        chainBList = [\chainB, defaultSource];

        bypassA = IdentityDictionary.new;
        bypassB = IdentityDictionary.new;

        // point current/next
        currentChain = chainAList;
        nextChain = chainBList;

        // (re)build both; play current, stop next
        this.rebuild(currentChain);
        this.rebuild(nextChain);
        Ndef(\chainA).play(numChannels: defaultNumChannels);

        ^this
    }

    // ───────────────────────────────────────────────────────────────
    // public API
    // ───────────────────────────────────────────────────────────────

    help {
        var text;
        text = String.new;
        text = text
        ++ "MagicPedalboardNew v" ++ version ++ "\n"
        ++ "Chains are Arrays of Symbols ordered [sink, …, source].\n"
        ++ "On init, creates \\chainA and \\chainB and plays current.\n\n"
        ++ "Core methods (mostly operate on the *next* chain):\n"
        ++ "  printChains\n"
        ++ "  playCurrent, stopCurrent, switchChain\n"
        ++ "  add(key), addAt(key, index)\n"
        ++ "  removeAt(index), swap(i, j)\n"
        ++ "  bypass(key, state=true), bypassAt(index, state=true)\n"
        ++ "  clearChain\n"
        ++ "Current-chain bypass:\n"
        ++ "  bypassCurrent(key, state=true), bypassAtCurrent(index, state=true)\n";
        text.postln;
    }

    printChains {
        var markCurrent, markNext;
        markCurrent = { |list| if(list === currentChain) { "  (current)" } { "" } };
        markNext = { |list| if(list === nextChain) { "  (next)" } { "" } };

        "MagicPedalboardNew.printChains:".postln;

        ("A: " ++ chainAList ++ markCurrent.(chainAList) ++ markNext.(chainAList)).postln;
        ("   bypassA: " ++ this.bypassKeysForList(chainAList)).postln;

        ("B: " ++ chainBList ++ markCurrent.(chainBList) ++ markNext.(chainBList)).postln;
        ("   bypassB: " ++ this.bypassKeysForList(chainBList)).postln;
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
        var tmp, oldSink, newSink;

        // stop current sink, swap pointers, then play new current
        oldSink = currentChain[0];
        Ndef(oldSink).stop;

        tmp = currentChain;
        currentChain = nextChain;
        nextChain = tmp;

        // ensure graphs are rebuilt appropriately
        this.rebuild(nextChain);
        this.rebuild(currentChain);

        newSink = currentChain[0];
        Ndef(newSink).play(numChannels: defaultNumChannels);
    }

    // ---- next-chain mutations ------------------------------------------------

    add { | key |
        var index;
        // insert just before source (right side)
        index = nextChain.size - 1;
        this.addAt(key, index);
    }

    addAt { | key, index |
        var indexClamped, newList;
        indexClamped = index.clip(1, nextChain.size - 1); // never before sink
        newList = nextChain.insert(indexClamped, key);    // returns a new Array
        this.setNextList(newList);
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
                this.setNextList(newList);

                // if it had a bypass flag, drop it
                this.bypassDictForList(nextChain).removeAt(removedKey);

                this.rebuild(nextChain);
                ("removed: " ++ removedKey).postln;
            }
        }
    }

    swap { | i, j |
        var lastIndex, a, b, newList, tempKey;

        lastIndex = nextChain.size - 1;

        // clamp into processor region only (exclude sink=0 and source=last)
        a = i.clip(1, lastIndex - 1);
        b = j.clip(1, lastIndex - 1);

        if(a == b) {
            // nothing to do
        }{
            newList = nextChain.copy;
            tempKey = newList[a];
            newList[a] = newList[b];
            newList[b] = tempKey;

            this.setNextList(newList);
            this.rebuild(nextChain);
        }
    }

    clearChain {
        var sinkKey, sourceKey, newList;

        if(nextChain.size < 2) { ^this };

        sinkKey = nextChain[0];
        sourceKey = nextChain[nextChain.size - 1];

        newList = [sinkKey, sourceKey];
        this.setNextList(newList);

        this.bypassDictForList(nextChain).clear;
        this.rebuild(nextChain);
    }

    bypass { | key, state = true |
        var dict;
        dict = this.bypassDictForList(nextChain);
        dict[key] = state;
        this.rebuild(nextChain);
    }

    bypassAt { | index, state = true |
        var lastIndex, clamped, key;
        lastIndex = nextChain.size - 1;
        clamped = index.clip(1, lastIndex - 1);
        key = nextChain[clamped];
        this.bypass(key, state);
    }

    // ---- current-chain bypass ------------------------------------------------

    bypassCurrent { | key, state = true |
        var dict;
        dict = this.bypassDictForList(currentChain);
        dict[key] = state;
        this.rebuild(currentChain);
    }

    bypassAtCurrent { | index, state = true |
        var lastIndex, clamped, key;
        lastIndex = currentChain.size - 1;
        clamped = index.clip(1, lastIndex - 1);
        key = currentChain[clamped];
        this.bypassCurrent(key, state);
    }

    // ---- optional: set source (handy for tests) ------------------------------

    setSource { | key |
        var newList, lastIndex;
        lastIndex = nextChain.size - 1;
        newList = nextChain.copy;
        newList[lastIndex] = key;
        this.setNextList(newList);
        this.rebuild(nextChain);
    }

    setSourceCurrent { | key |
        var newList, lastIndex;
        lastIndex = currentChain.size - 1;
        newList = currentChain.copy;
        newList[lastIndex] = key;
        if(currentChain === chainAList) { chainAList = newList; currentChain = chainAList; } { chainBList = newList; currentChain = chainBList; };
        this.rebuild(currentChain);
    }

    // ───────────────────────────────────────────────────────────────
    // private helpers
    // ───────────────────────────────────────────────────────────────

    setNextList { | newList |
        if(nextChain === chainAList) {
            chainAList = newList; nextChain = chainAList;
        }{
            chainBList = newList; nextChain = chainBList;
        }
    }

    bypassDictForList { | list |
        ^if(list === chainAList) { bypassA } { bypassB }
    }

    bypassKeysForList { | list |
        var dict;
        dict = this.bypassDictForList(list);
        ^dict.keysValuesCollect { |k, v| if(v) { k } { nil } }.reject(_.isNil)
    }

    ensureStereo { | key |
        var proxyBus;
        proxyBus = Ndef(key).bus;
        if(proxyBus.isNil or: { proxyBus.rate != \audio } or: { proxyBus.numChannels != defaultNumChannels }) {
            Ndef(key).ar(defaultNumChannels);  // pre-arm bus as audio/stereo
        };
    }

    effectiveListFor { | list |
        var dict, result, lastIndex;

        dict = this.bypassDictForList(list);
        result = Array.new;
        lastIndex = list.size - 1;

        list.do { |key, i|
            var isProcessor, isBypassed;
            isProcessor = (i > 0) and: (i < lastIndex);
            isBypassed = isProcessor and: { dict[key] == true };

            if(i == 0 or: { i == lastIndex }) {
                result = result.add(key);            // always keep sink & source
            }{
                if(isBypassed.not) {
                    result = result.add(key);        // keep only non-bypassed processors
                };
            };
        };

        ^result
    }

    rebuild { | list |
        var effective, index, leftKey, rightKey, sinkKey;

        if(list.size < 2) { ^this };

        effective = this.effectiveListFor(list);

        // keep buses consistent
        effective.do { |key| this.ensureStereo(key) };

        // wire: consumer receives producer at \in (default)
        index = 0;
        while { index < (effective.size - 1) } {
            leftKey = effective[index];
            rightKey = effective[index + 1];
            Ndef(leftKey) <<> Ndef(rightKey);
            index = index + 1;
        };

        sinkKey = effective[0];

        // play only if this is the current chain; otherwise stop its sink
        if(list === currentChain) {
            Ndef(sinkKey).play(numChannels: defaultNumChannels);
        }{
            Ndef(sinkKey).stop;
        };
    }
}



/*
I'm trying to rewrite some code I have into some a supercollider class.

sigChainOperations_v0.2.1.scd.txtI have started a class definition but I'm having some issues, so I'd like to see what your solution would be.

I would like the class to initiate two Ndefs (\chainA and \chainB) that will be the ones that we play. We should have variables currentChain and nextChain that point to which is current and which is next. On init we should play the current chain. We should have methods for printChains, playCurrent, stopCurrent, switchChain (make next current and current becomes next); add, addAt, removeAt, swap, bypass, bypassAt, clearChain. Most of those should apply to the next chain. We should also have bypass and bypassAt for the current chain. Respect all the supercollider rules (var before statements, variables start with lowercase), descriptive variable names, space after accessor (e.g.  var < currentChain;) a help method, classvar version. Name the class MagicPedalboardNew. Please also give me some test code. Check all supercollider syntax for correctness. Ask me if anything needs clarification.
*/

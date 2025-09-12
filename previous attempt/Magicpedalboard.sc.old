MagicPedalboard : Object {
    classvar version = "v0.2.3";

    var < chainA;
    var < chainB;
    var < currentChain;
    var < nextChain;

    *new {
        ^super.new.init
    }

    init {
        chainA = [\out, \ts2];
        chainB = [\out, \ts3];
        currentChain = chainA;
        nextChain = chainB;
        this.rebuild;
        this.playCurrent;
        this.printChains;
    }

    switchChain {
        var temp;
        this.stopCurrent;
        temp = currentChain;
        currentChain = nextChain;
        nextChain = temp;
        this.rebuild;
        this.playCurrent;
        this.printChains;
    }

    clearChain {
        nextChain = [\out, \ts2];
        this.rebuild;
        this.printChains;
    }

    ensureStereo { | key |
        var bus;
        bus = Ndef(key).bus;
        if(bus.isNil or: { bus.rate != \audio } or: { bus.numChannels != 2 }) {
            Ndef(key).ar(2);
        };
    }

    rebuild {
        var index, leftKey, rightKey;
        if(currentChain.size < 2) {
            "need at least [sink, source]".postln;
        } {
            currentChain.do { | key | this.ensureStereo(key) };
            index = 0;
            while { index < (currentChain.size - 1) } {
                leftKey = currentChain[index];
                rightKey = currentChain[index + 1];
                Ndef(leftKey) <<> Ndef(rightKey);
                index = index + 1;
            };
            ("chain rebuilt: " ++ currentChain).postln;
        };
    }

    rebuildExplicit {
        var index, leftKey, rightKey;
        if(currentChain.size < 2) {
            "need at least [sink, source]".postln;
        } {
            currentChain.do { | key | this.ensureStereo(key) };
            index = 0;
            while { index < (currentChain.size - 1) } {
                leftKey = currentChain[index];
                rightKey = currentChain[index + 1];
                Ndef(leftKey).set(\in, Ndef(rightKey));
                index = index + 1;
            };
            ("chain rebuilt (explicit): " ++ currentChain).postln;
        };
    }

    playCurrent {
        Ndef(currentChain[0]).play(numChannels: 2);
    }

    stopCurrent {
        Ndef(currentChain[0]).stop;
    }

    add { | key |
        nextChain = nextChain.insert(nextChain.size - 1, key);
        this.rebuild;
        this.printChains;
    }

    addAt { | key, index |
        var clamped;
        clamped = index.clip(0, nextChain.size);
        nextChain = nextChain.insert(clamped, key);
        this.rebuild;
        this.printChains;
    }

    removeAt { | index |
        var clamped;
        if(nextChain.size <= 2) {
            "refuse to remove: need at least [sink, source]".postln;
        } {
            clamped = index.clip(0, nextChain.size - 1);
            nextChain = nextChain.removeAt(clamped);
            this.rebuild;
            this.printChains;
        };
    }

    swap { | i, j |
        var temp, ia, ib;
        if(i == j) { ^this };
        ia = i.clip(0, nextChain.size - 1);
        ib = j.clip(0, nextChain.size - 1);
        temp = nextChain[ia];
        nextChain[ia] = nextChain[ib];
        nextChain[ib] = temp;
        this.rebuild;
        this.printChains;
    }

    bypass {
        if(currentChain.size > 2) {
            this.removeAt(currentChain.size - 2);
        };
        this.printChains;
    }

    bypassAt { | index |
        this.removeAt(index);
        this.printChains;
    }

    printChains {
        var labelA, labelB;
        labelA = if(currentChain === chainA) { "Current Chain: Chain A" } { "Next Chain: Chain A" };
        labelB = if(currentChain === chainB) { "Current Chain: Chain B" } { "Next Chain: Chain B" };
        labelA.postln;
        chainA.postln;
        labelB.postln;
        chainB.postln;
    }

    help {
        "MagicPedalboard: dual-chain manager for Ndef signal routing.\n" ++
        "Methods:\n" ++
        "  switchChain - swap current and next chains\n" ++
        "  clearChain - reset next chain to [\\out, \\ts2]\n" ++
        "  add(key) - insert before output\n" ++
        "  addAt(key, index) - insert at index\n" ++
        "  removeAt(index) - remove node\n" ++
        "  swap(i, j) - swap two nodes\n" ++
        "  bypass - remove last processor\n" ++
        "  bypassAt(index) - remove processor at index\n" ++
        "  playCurrent / stopCurrent - control playback of current chain\n" ++
        "  rebuildExplicit - use .set(\\in, ...) instead of <<>\n"
        .postln;
    }
}

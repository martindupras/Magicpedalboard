/* MagicProcessorLibrary.sc
   Holds a registry of processor/source functions and can ensure Ndefs exist.
   MD 20250913
*/
MagicProcessorLibrary : Object {
    var <defs;           // IdentityDictionary: Symbol -> Function
    var <defaultNumChannels;

    *new { ^super.new.init }

    init {
        var empty;
        defaultNumChannels = 2;
        empty = IdentityDictionary.new;
        defs = empty;
        ^this
    }

    register { arg key, func;
        defs[key] = func;
        ^this
    }

    has { arg key;
        ^defs.includesKey(key)
    }

    get { arg key;
        ^defs[key]
    }

    keys { ^defs.keys }

    // Create or update an Ndef for key
    ensure { arg key, chans;
        var func, numCh, canRun;
        func = defs[key];
        if(func.isNil) { ^this }; // silently ignore if not registered
        numCh = chans ? defaultNumChannels;
        canRun = Server.default.serverRunning;
        if(canRun) {
            Server.default.bind({
                Ndef(key, func);
                Ndef(key).ar(numCh);
            });
        };
        ^this
    }

    // Ensure many keys at once
    ensureMany { arg keyArray, chans;
        keyArray.do({ arg key; this.ensure(key, chans) });
        ^this
    }

    // Convenience: ensure whatever appears in a chain array
    ensureFromChain { arg chainArray, chans;
        var lastIndex, idx;
        if(chainArray.isNil or: { chainArray.size < 2 }) { ^this };
        lastIndex = chainArray.size - 1;
        idx = 0;
        while({ idx <= lastIndex }, {
            this.ensure(chainArray[idx], chans);
            idx = idx + 1;
        });
        ^this
    }
}

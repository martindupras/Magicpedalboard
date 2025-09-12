/* MagicDisplay.sc  v0.1.0
   Console display adaptor for MagicPedalboardNew.
   Prints structured messages now; later you can subclass with a real GUI.
*/

MagicDisplay : Object {

    classvar < version;

    var < logLevel;  // 0 = silent, 1 = normal, 2 = verbose

    *initClass {
        version = "v0.1.0";
        ("MagicDisplay " ++ version).postln;
    }

    *new { |level = 1|
        ^super.new.init(level)
    }

    init { |level|
        var initialLevel;
        initialLevel = level ? 1;
        logLevel = initialLevel;
        ^this
    }

    help {
        var text;
        text = "MagicDisplay " ++ version
        ++ "\nMethods:\n"
        ++ "  showInit(pedalboard, versionString, current, next)\n"
        ++ "  showRebuild(which, fullChain, effective)\n"
        ++ "  showPlay(sink), showStop(sink), showSwitch(oldSink, newSink, current, next)\n"
        ++ "  showMutation(action, args, nextChain)\n"
        ++ "  showBypass(which, key, state, chain, bypassKeys)\n"
        ++ "  showReset(current, next), showChains(current, next, bypassA, bypassB)\n"
        ++ "  showError(message)\n";
        text.postln;
    }

    showInit { |pedalboard, versionString, current, next|
        if(logLevel > 0) { ("[MPB:init] " ++ versionString ++ "  current=" ++ current ++ "  next=" ++ next).postln };
    }

    showRebuild { |which, fullChain, effective|
        if(logLevel > 0) { ("[MPB:rebuild:" ++ which ++ "] full=" ++ fullChain ++ "  effective=" ++ effective).postln };
    }

    showPlay { |sinkKey|
        if(logLevel > 0) { ("[MPB:play] sink=" ++ sinkKey).postln };
    }

    showStop { |sinkKey|
        if(logLevel > 0) { ("[MPB:stop] sink=" ++ sinkKey).postln };
    }

    showSwitch { |oldSink, newSink, current, next|
        if(logLevel > 0) {
            ("[MPB:switch] " ++ oldSink ++ " → " ++ newSink
                ++ "  current=" ++ current ++ "  next=" ++ next).postln;
        };
    }

    showMutation { |action, args, nextChain|
        if(logLevel > 0) { ("[MPB:mutate] " ++ action ++ " " ++ args ++ "  next=" ++ nextChain).postln };
    }

    showBypass { |which, key, state, chain, bypassKeys|
        if(logLevel > 0) {
            ("[MPB:bypass:" ++ which ++ "] " ++ key ++ " -> " ++ state
                ++ "  chain=" ++ chain ++ "  activeBypass=" ++ bypassKeys).postln;
        };
    }

    showReset { |current, next|
        if(logLevel > 0) { ("[MPB:reset] current=" ++ current ++ "  next=" ++ next).postln };
    }

    showChains { |current, next, bypassAKeys, bypassBKeys|
        if(logLevel > 0) {
            "MagicPedalboardNew.printChains:".postln;
            ("A: " ++ current ++ "   bypassA: " ++ bypassAKeys).postln;
            ("B: " ++ next    ++ "   bypassB: " ++ bypassBKeys).postln;
        };
    }

    showError { |message|
        ("[MPB:error] " ++ message).warn;
    }
}

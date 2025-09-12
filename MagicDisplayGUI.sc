/* MagicDisplayGUI.sc v0.1.0
 GUI display adaptor for MagicPedalboardNew.
 Two columns: CURRENT (left) / NEXT (right), with bypass badges and effective list.
 Uses AppClock to render; safe to call from MPB notifications.
 // MD 20250912-1451
*/
MagicDisplayGUI : MagicDisplay {
    classvar < versionGUI;
    var < window;
    var leftListView, rightListView;
    var leftHeader, rightHeader;
    var leftEffective, rightEffective;

    *initClass {
        var text;
        versionGUI = "v0.1.0";
        text = "MagicDisplayGUI " ++ versionGUI;
        text.postln;
    }

    *new { arg level = 1;
        var instance;
        instance = super.new(level);
        ^instance.initGui;
    }

    initGui {
        var windowRect, listRectLeft, listRectRight, effRectLeft, effRectRight, headerWidth;
        windowRect = Rect(100, 100, 720, 360);
        headerWidth = 340;
        listRectLeft = Rect(10, 50, 340, 220);
        listRectRight = Rect(370, 50, 340, 220);
        effRectLeft = Rect(10, 280, 340, 20);
        effRectRight = Rect(370, 280, 340, 20);

        AppClock.sched(0, {
            window = Window("MagicDisplayGUI – CURRENT / NEXT", windowRect).front.alwaysOnTop_(true);

            leftHeader = StaticText(window, Rect(10, 10, headerWidth, 28)).string_("CURRENT");
            rightHeader = StaticText(window, Rect(370, 10, headerWidth, 28)).string_("NEXT");

            leftListView = ListView(window, listRectLeft).items_([]);
            rightListView = ListView(window, listRectRight).items_([]);

            leftEffective = StaticText(window, effRectLeft).string_("eff: —");
            rightEffective = StaticText(window, effRectRight).string_("eff: —");
            nil
        });
        ^this
    }

    // Format one chain block for display
    formatListForGui { arg listRef, bypassKeys, effectiveList;
        var items, lastIndex, indexCounter;
        items = Array.new;
        lastIndex = listRef.size - 1;

        items = items.add("sink : " ++ listRef[0]);

        if(listRef.size > 2) {
            items = items.add("procs:");
            indexCounter = 1;
            listRef.copyRange(1, lastIndex - 1).do { arg procKey;
                var isBypassed, badge, lineText;
                isBypassed = bypassKeys.includes(procKey);
                badge = if(isBypassed) { "[BYP]" } { "[ON]" };
                lineText = ("  [" ++ indexCounter ++ "] " ++ procKey ++ " " ++ badge);
                items = items.add(lineText);
                indexCounter = indexCounter + 1;
            };
        }{
            items = items.add("procs: (none)");
        };

        items = items.add("src  : " ++ listRef[lastIndex]);
        items = items.add("eff  : " ++ effectiveList.join(" -> "));
        ^items
    }

    // Display hooks (run on AppClock)
    showInit { arg pedalboard, versionString, current, next;
        var text;
        text = "[MPB:init] " ++ versionString;
        AppClock.sched(0, {
            if(window.notNil) { window.name = "MagicDisplayGUI – " ++ versionString };
            text.postln;
            nil
        });
    }

    showRebuild { arg which, fullChain, effective;
        var infoText;
        infoText = "[MPB:rebuild:" ++ which ++ "] full=" ++ fullChain ++ " effective=" ++ effective;
        AppClock.sched(0, { infoText.postln; nil });
    }

    showPlay { arg sinkKey;
        var text;
        text = "[MPB:play] sink=" ++ sinkKey;
        AppClock.sched(0, { text.postln; nil });
    }

    showStop { arg sinkKey;
        var text;
        text = "[MPB:stop] sink=" ++ sinkKey;
        AppClock.sched(0, { text.postln; nil });
    }

    showSwitch { arg oldSink, newSink, current, next;
        var text;
        text = "[MPB:switch] " ++ oldSink ++ " → " ++ newSink;
        AppClock.sched(0, {
            var currentItems, nextItems, effCurrent, effNext, bypassAKeys, bypassBKeys;
            bypassAKeys = IdentityDictionary.new; // not used directly here
            bypassBKeys = IdentityDictionary.new;
            // The pedalboard will also call showChainsDetailed; this is light feedback.
            if(window.notNil) { window.name = "MagicDisplayGUI – switched: " ++ oldSink ++ " → " ++ newSink };
            text.postln;
            nil
        });
    }

    showMutation { arg action, args, nextChain;
        var text;
        text = "[MPB:mutate] " ++ action ++ " " ++ args ++ " next=" ++ nextChain;
        AppClock.sched(0, { text.postln; nil });
    }

    showBypass { arg which, key, state, chain, bypassKeys;
        var text;
        text = "[MPB:bypass:" ++ which ++ "] " ++ key ++ " -> " ++ state ++ " active=" ++ bypassKeys;
        AppClock.sched(0, { text.postln; nil });
    }

    showReset { arg current, next;
        var text;
        text = "[MPB:reset] current=" ++ current ++ " next=" ++ next;
        AppClock.sched(0, { text.postln; nil });
    }

    // Main detailed view updater (called by pedalboard.printChains)
    showChainsDetailed { arg current, next, bypassAKeys, bypassBKeys, effCurrent, effNext;
        var currentItems, nextItems, effCurrentText, effNextText;
        currentItems = this.formatListForGui(current, bypassAKeys, effCurrent);
        nextItems = this.formatListForGui(next, bypassBKeys, effNext);
        effCurrentText = "eff: " ++ effCurrent.join(" -> ");
        effNextText = "eff: " ++ effNext.join(" -> ");

        AppClock.sched(0, {
            if(leftHeader.notNil) { leftHeader.string = "CURRENT (sink=" ++ current[0] ++ ")" };
            if(rightHeader.notNil) { rightHeader.string = "NEXT (sink=" ++ next[0] ++ ")" };

            if(leftListView.notNil) { leftListView.items = currentItems };
            if(rightListView.notNil) { rightListView.items = nextItems };

            if(leftEffective.notNil) { leftEffective.string = effCurrentText };
            if(rightEffective.notNil) { rightEffective.string = effNextText };
            nil
        });
    }

    showError { arg message;
        var text;
        text = "[MPB:error] " ++ message;
        AppClock.sched(0, { text.warn; nil });
    }
}

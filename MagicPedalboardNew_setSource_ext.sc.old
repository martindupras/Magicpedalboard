/* MagicPedalboardNew_setSource_ext.sc
   Adds setSource to MagicPedalboardNew if your loaded class lacks it.
   Remove this once your main class includes setSource.
*/

+ MagicPedalboardNew {
    setSource { | key |
        var newList, lastIndex;
        lastIndex = nextChain.size - 1;
        newList = nextChain.copy;
        newList[lastIndex] = key;

        this.setNextListInternal(newList); // uses the class’ internal helper
        this.rebuild(nextChain);
    }
}

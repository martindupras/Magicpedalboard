/* MagicPedalboardNew_setSourceCurrent_ext.sc
   Adds setSourceCurrent to MagicPedalboardNew, for environments where the class
   was loaded without it. Remove this file once your main class includes the method.
*/

+ MagicPedalboardNew {
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
}

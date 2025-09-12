// Test_MagicPedalboardNew_v0_3_1_Sanity_NoGUI.scd
// MD 20250912-1345

(
s.waitForBoot({
    var say, countdown, show, preflight, setCurrent, setNext, board, displayAdaptor;

    say = { |txt| txt.asString.postln };
    countdown = { |n = 3| n.do { |k| ((n - k).asString ++ "...").postln; 1.wait }; "Now.".postln; };

    preflight = {
        // safe cleanup
        Ndef.all.keysValuesDo { |key, proxy| if(proxy.isPlaying) { proxy.stop }; proxy.clear };
        if(ProxySpace.respondsTo(\all)) { ProxySpace.all.valuesDo { |ps| if(ps.notNil) { ps.clear } } };
        s.initTree; s.defaultGroup.freeAll;
    };

    show = { "— Chains (detailed) —".postln; board.printChains; "".postln; };

    setCurrent = { |key| if(board.respondsTo(\setSourceCurrent)) { board.setSourceCurrent(key) } };
    setNext    = { |key| if(board.respondsTo(\setSource))        { board.setSource(key)        } };

    preflight.();

    displayAdaptor = MagicDisplay.new(1);
    board = MagicPedalboardNew.new(displayAdaptor);
    board.reset;

    // silent baseline
    setCurrent.(\ts0); setNext.(\ts0);
    board.clearChain; board.switchChain; board.clearChain; board.switchChain;
    Ndef(\chainA).play(numChannels: 2); Ndef(\chainB).stop;

    say.("A1: silent"); show.(); 2.wait;

    say.("B1: CURRENT->Dust"); setCurrent.(\tsDust); show.(); 2.wait;

    say.("C1: NEXT Saw+Trem -> switch");
    setNext.(\tsSaw); board.add(\tremolo); show.();
    countdown.(3); board.switchChain; show.(); 2.wait;

    say.("D1: bypass tremolo"); board.bypassCurrent(\tremolo, true); show.(); 1.wait;
    say.("D2: un-bypass tremolo"); board.bypassCurrent(\tremolo, false); show.(); 2.wait;

    say.("E1: NEXT add atten@1, lofi@2, swap -> switch");
    board.addAt(\atten, 1); board.addAt(\lofi, 2); board.swap(1, 2); show.();
    countdown.(2); board.switchChain; show.(); 2.wait;

    say.("F1: NEXT removeAt(1), clear");
    board.removeAt(1); show.(); board.clearChain; show.(); 1.wait;

    say.("G1: NEXT->ts0, switch");
    setNext.(\ts0); countdown.(2); board.switchChain; show.(); 2.wait;

    say.("Done. Stopping."); board.stopCurrent;
});
)

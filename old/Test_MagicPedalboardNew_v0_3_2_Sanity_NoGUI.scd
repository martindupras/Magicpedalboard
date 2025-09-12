// Test_MagicPedalboardNew_v0_3_2_Sanity_NoGUI.scd
// MD 20250912-1412
(
s.waitForBoot {
    var say, countdown, show, preflight, setCurrent, setNext, board, displayAdaptor;

    say = { |text| text.asString.postln };
    countdown = { |n = 3|
        var k;
        k = n;
        while { k > 0 } {
            (k.asString ++ "...").postln;
            1.wait;
            k = k - 1;
        };
        "Now.".postln;
    };
    preflight = {
        Ndef.all.keysValuesDo { |keySymbol, nodeProxy|
            if(nodeProxy.isPlaying) { nodeProxy.stop };
            nodeProxy.clear;
        };
        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo { |serverKey, proxySpace|
                if(proxySpace.notNil) { proxySpace.clear };
            };
        };
        s.initTree;
        s.defaultGroup.freeAll;
    };
    show = {
        "— Chains (detailed) —".postln;
        board.printChains;
        "".postln;
    };
    setCurrent = { |key|
        if(board.respondsTo(\setSourceCurrent)) {
            board.setSourceCurrent(key)
        } { "ERROR: setSourceCurrent missing".warn };
    };
    setNext = { |key|
        if(board.respondsTo(\setSource)) {
            board.setSource(key)
        } { "ERROR: setSource missing".warn };
    };

    // go
    preflight.();

    Ndef(\ts0, { Silent.ar(2) });
    Ndef(\tsDust, { Dust.ar(2000) ! 2 });
    Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });
    Ndef(\tremolo, {
        var inputSignal;
        inputSignal = \in.ar(2);
        inputSignal * SinOsc.kr(4).range(0.1, 1)
    });
    Ndef(\lofi, {
        var inputSignal;
        inputSignal = \in.ar(2);
        Decimator.ar(inputSignal, 4000, 4)
    });
    Ndef(\atten, {
        var inputSignal;
        inputSignal = \in.ar(2) * 0.25;
        inputSignal
    });

    displayAdaptor = MagicDisplay.new(1);
    board = MagicPedalboardNew.new(displayAdaptor);
    board.reset;

    setCurrent.(\ts0);
    setNext.(\ts0);
    board.clearChain;
    board.switchChainWithFade;
    board.clearChain;
    board.switchChainWithFade;
    Ndef(\chainA).play(numChannels: 2);
    Ndef(\chainB).stop;

    say.("A1: silent"); show.(); 2.wait;

    say.("B1: CURRENT→Dust"); setCurrent.(\tsDust); show.(); 2.wait;

    say.("C1: NEXT Saw+Trem → switch");
    setNext.(\tsSaw); board.add(\tremolo); show.();
    countdown.(3); board.switchChainWithFade; show.(); 2.wait;

    say.("D1: bypass tremolo"); board.bypassCurrent(\tremolo, true); show.(); 1.wait;
    say.("D2: un-bypass tremolo"); board.bypassCurrent(\tremolo, false); show.(); 2.wait;

    say.("E1: NEXT add atten@1, lofi@2, swap → switch");
    board.addAt(\atten, 1); board.addAt(\lofi, 2); board.swap(1, 2); show.();
    countdown.(2); board.switchChainWithFade; show.(); 2.wait;

    say.("F1: NEXT removeAt(1), clear");
    board.removeAt(1); show.(); board.clearChain; show.(); 1.wait;

    say.("G1: NEXT→ts0, switch");
    setNext.(\ts0); countdown.(2); board.switchChainWithFade; show.(); 2.wait;

    say.("Done. Stopping."); board.stopCurrent;
});
)

// Switch_VerifyCurrentAudible_OptionA.scd
// v0.1
// MD 20250917-1320
//
// Purpose: After switching, ensure CURRENT sink is audibly playing and NEXT is ended,
//          without altering any sink sources. Non-intrusive.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, enforce;

log = { arg s; ("[SWCHK] " ++ s).postln };

enforce = {
    var cur = ~mpb.currentChain[0], nxt = ~mpb.nextChain[0];
    Server.default.bind({
        // Make CURRENT audible
        Ndef(cur).mold(2, \audio);
        if(Ndef(cur).isPlaying.not) { Ndef(cur).play(numChannels: 2) };

        // Make NEXT cleanly inactive (flag false), keep stereo shape
        Ndef(nxt).end;
        Ndef(nxt).mold(2, \audio);
    });
    AppClock.sched(0.25, {
        var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
        ("[SWCHK] [PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

enforce.value;
)

// MPBTest_Assertions.sc
// v0.1.0
// MD 20250920-1540
//
// Purpose
// - Centralized assertions used across scenarios (A XOR B, single \delay in list, NEXT audible tail...)
// Style
// - var-first; lowercase; no server.sync; no single-letter locals.

MPBTest_Assertions : Object {
    *xorPlaying { arg expectA = true, expectB = false;
        var a, b, ok;
        a = Ndef(\chainA).isPlaying;
        b = Ndef(\chainB).isPlaying;
        ok = (a == expectA) and: { b == expectB };
        ("[ASSERT] XOR A="++a++" B="++b++" expect("++expectA++","++expectB++") -> "++
            (ok.if({"PASS"},{"FAIL"}))).postln;
        ^ok
    }

    *countKey { arg list, key;
        var count = 0;
        list.do({ arg k; if(k == key) { count = count + 1 } });
        ^count
    }

    *exactlyOne { arg list, key, label="count";
        var n, pass;
        n = this.countKey(list, key);
        pass = (n == 1);
        ("[ASSERT] "++label++" '"++key.asString++"' = "++n++" -> "++
            (pass.if({"PASS"},{"FAIL"}))).postln;
        ^pass
    }

    *nextTailNotTs0 { arg mpb;
        var last, ok;
        last = mpb.effectiveNext.last;
        ok = (last != \ts0);
        ("[ASSERT] NEXT tail != \\ts0 -> "++(ok.if({"PASS"},{"FAIL"}))).postln;
        ^ok
    }
}

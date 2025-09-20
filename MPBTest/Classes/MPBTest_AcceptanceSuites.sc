// MPBTest_AcceptanceSuites.sc
// v0.1.1
// MD 20250920-1608

// Purpose
// - Ready-made, extensible step lists for acceptance.
// Style
// - var-first; lowercase; data-only class methods.

MPBTest_AcceptanceSuites : Object {
    *classic { arg fade = 0.12;
        ^[
            (verb:\add,           args:[\delay]),
            (verb:\switch,        args:[fade]),
            (verb:\bypassCurrent, args:[\delay, true]),
            (verb:\bypassCurrent, args:[\delay, false]),
            (verb:\switch,        args:[fade])
        ]
    }

    *mutatorsBasic { arg fade = 0.12;
        ^[
            (verb:\insert,   args:[\chorus]),
            (verb:\addAt,    args:[\reverb, 1]),
            (verb:\swap,     args:[1, 2]),
            (verb:\removeAt, args:[2]),
            (verb:\switch,   args:[fade])
        ]
    }

    *bypassNextCycle {
        ^[
            (verb:\add,    args:[\delay]),
            (verb:\bypass, args:[\delay, \on]),
            (verb:\bypass, args:[\delay, \off]),
            (verb:\switch, args:[0.12])
        ]
    }
}

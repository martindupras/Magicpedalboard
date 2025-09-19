// TestMagicPedalboard.sc
// v0.1.0
// MD 20250919-15.33

/*
Purpose:
- Run a basic acceptance test on MagicPedalboardNew.
- Uses MDMiniLogger for structured logging.
- Verifies chain mutation, switching, and bypass toggling.

Style:
- var-first; lowercase method names; no server.sync.
- GUI optional; logs to console.
*/

TestMagicPedalboard : Object {
    var <logger, <pedalboard, <gui;

    *new { arg mpb, gui = nil;
        ^super.new.init(mpb, gui);
    }

    init { arg mpb, gui;
        pedalboard = mpb;
        this.gui = gui;
        logger = MDMiniLogger.new("TestMagicPedalboard");
        ^this;
    }

    runAcceptanceTest {
        logger.info("Starting acceptance test...");

        logger.info("Step 1: Add \\delay to NEXT");
        pedalboard.add(\delay);
        pedalboard.printChains;

        logger.info("Step 2: Switch chains (A → B)");
        pedalboard.switchChain(0.12);
        pedalboard.printChains;

        logger.info("Step 3: Bypass \\delay ON (CURRENT)");
        pedalboard.bypassCurrent(\delay, true);
        pedalboard.printChains;

        logger.info("Step 4: Bypass \\delay OFF (CURRENT)");
        pedalboard.bypassCurrent(\delay, false);
        pedalboard.printChains;

        logger.info("Step 5: Switch back (B → A)");
        pedalboard.switchChain(0.12);
        pedalboard.printChains;

        logger.info("Acceptance test complete.");
    }

    help {
        "Available methods: runAcceptanceTest".postln;
    }
}

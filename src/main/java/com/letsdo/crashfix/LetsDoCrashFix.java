package com.letsdo.crashfix;

import net.neoforged.fml.common.Mod;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * [Let's Do] Crash Fix
 *
 * A drop-in patch mod for NeoForge 1.21.1 that fixes the Create schematic
 * printing conflict with [Let's Do] mods (Vinery, Meadow, Bakery,
 * BloomingNature, WilderNature, Brewery, ...).
 *
 * <p>Many [Let's Do] block entities override {@code setChanged()} and
 * blindly cast their {@code level} to {@code ServerLevel} to notify
 * tracking players. Create's schematic printer and schematicannon load
 * schematics into a fake {@code SchematicLevel} (from catnip), which is
 * not a {@code ServerLevel}, so the cast throws
 * {@link ClassCastException} and schematic loading/printing fails.
 *
 * <p>It does NOT modify any other mod's files. The actual fix lives in
 * {@link com.letsdo.crashfix.mixin.LetsDoStorageBlockEntityMixin}.
 */
@Mod(LetsDoCrashFix.MOD_ID)
public final class LetsDoCrashFix {

    public static final String MOD_ID = "letsdo_crashfix";
    private static final Logger LOGGER = LogManager.getLogger(MOD_ID);

    public LetsDoCrashFix() {
        LOGGER.info("[Let's Do] Crash Fix: Create schematic conflict patch loaded.");
    }
}
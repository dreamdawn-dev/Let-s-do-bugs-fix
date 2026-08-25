package com.letsdo.crashfix;

import net.minecraftforge.fml.common.Mod;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * [Let's Do] Crash Fix
 *
 * A drop-in patch mod for Forge 1.20.1 that only fixes the crash caused by
 * multiple [Let's Do] mods (Meadow, BloomingNature, Vinery, ...) registering
 * flammable blocks in parallel during Forge's FMLCommonSetupEvent.
 *
 * It does NOT modify any other mod's files. The actual fix lives in
 * {@link com.letsdo.crashfix.mixin.FireBlockFlammableMixin}, which serializes
 * writes to the vanilla FireBlock flammable maps.
 */
@Mod(LetsDoCrashFix.MOD_ID)
public final class LetsDoCrashFix {

    public static final String MOD_ID = "letsdo_crashfix";
    private static final Logger LOGGER = LogManager.getLogger(MOD_ID);

    public LetsDoCrashFix() {
        LOGGER.info("[Let's Do] Crash Fix: flammable registration is now serialized via FireBlock mixin.");
    }
}

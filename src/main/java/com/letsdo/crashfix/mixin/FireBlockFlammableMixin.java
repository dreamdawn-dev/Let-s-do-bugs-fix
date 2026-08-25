package com.letsdo.crashfix.mixin;

import it.unimi.dsi.fastutil.objects.Object2IntMap;
import net.minecraft.world.level.block.FireBlock;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

/**
 * Fixes the race condition on {@link FireBlock}'s flammable maps.
 *
 * <p>Minecraft's {@code FireBlock} keeps two non-thread-safe fastutil
 * {@code Object2IntMap}s for ignite/burn odds. Several [Let's Do] mods write
 * to those maps concurrently from their {@code FMLCommonSetupEvent} handlers,
 * which corrupts the hash map (key/value array length mismatch) and crashes
 * with {@code ArrayIndexOutOfBoundsException} inside {@code rehash()}.
 *
 * <p>This mixin redirects both {@code Object2IntMap.put} calls inside the
 * vanilla {@code registerFlammable} method ({@code m_53444_}) so that every
 * write is serialized on a single lock. The mods themselves are untouched.
 */
@Mixin(FireBlock.class)
public abstract class FireBlockFlammableMixin {

    private static final Object FLAMMABLE_LOCK = new Object();

    @Redirect(
            method = "m_53444_",
            at = @At(value = "INVOKE",
                    target = "Lit/unimi/dsi/fastutil/objects/Object2IntMap;put(Ljava/lang/Object;I)I")
    )
    @SuppressWarnings({"rawtypes", "unchecked"})
    private int letsdocrashfix$lockedPut(Object2IntMap map, Object key, int value) {
        synchronized (FLAMMABLE_LOCK) {
            return map.put(key, value);
        }
    }
}

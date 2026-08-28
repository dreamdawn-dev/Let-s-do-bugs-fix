package com.letsdo.crashfix.mixin;

import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Fixes the Create mod conflict affecting the whole [Let's Do] family.
 *
 * <p>Many [Let's Do] block entities override {@code setChanged()}
 * and blindly cast their {@code level} to {@link ServerLevel} to notify
 * tracking players. Create's schematic printer and schematicannon load
 * schematics into a fake {@code SchematicLevel} (from catnip), which is
 * not a {@link ServerLevel}, so the cast throws
 * {@link ClassCastException} and schematic loading/printing fails.
 *
 * <p>For such fake levels we simply skip the whole override; the vanilla
 * setChanged logic is irrelevant on a throwaway schematic level.
 *
 * <p>Fully qualified class literals are used because several targets share
 * the same simple name ({@code StorageBlockEntity}).
 *
 * <p>Farm &amp; Charm is excluded because it already uses a safe
 * {@code instanceof ServerLevel} pattern match in its override.
 */
@Mixin(value = {
        net.satisfy.vinery.core.block.entity.StorageBlockEntity.class,
        net.satisfy.meadow.core.block.entity.StorageBlockEntity.class,
        net.satisfy.bakery.core.block.entity.StorageBlockEntity.class,
        net.satisfy.bloomingnature.core.block.entity.StorageBlockEntity.class,
        net.satisfy.brewery.core.block.entity.StorageBlockEntity.class
        // WilderNature has no 1.21.1 NeoForge release yet. When it does,
        // add its StorageBlockEntity target here -- it almost certainly
        // shares the same blind (ServerLevel) cast pattern:
        // net.satisfy.wildernature.core.block.entity.StorageBlockEntity.class,
})
public abstract class LetsDoStorageBlockEntityMixin {

    @Inject(method = "setChanged", at = @At("HEAD"), cancellable = true)
    private void letsdocrashfix$skipNonServerLevels(CallbackInfo ci) {
        Level level = ((BlockEntity) (Object) this).getLevel();
        if (level != null && !level.isClientSide() && !(level instanceof ServerLevel)) {
            ci.cancel();
        }
    }
}
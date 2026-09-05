package com.letsdo.crashfix.mixin;

import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * 修复影响整个 [Let's Do] 系列模组的 Create 冲突。
 *
 * <p>[Let's Do] 系列多个方块实体重写了 {@code setChanged()}，
 * 并将其 {@code level} 盲目强转为 {@link ServerLevel} 以通知追踪玩家。
 * Create 的蓝图打印机和蓝图大炮将蓝图加载到假的 {@code SchematicLevel}
 *（来自 catnip）中，而该对象并非 {@link ServerLevel}，因此强转抛出
 * {@link ClassCastException}，导致蓝图加载/打印失败。
 *
 * <p>对于此类假世界，我们直接跳过整个重写逻辑；原版 setChanged 的行为
 * 在这种临时的蓝图世界中无关紧要。
 *
 * <p>由于多个目标类共享相同的简单名称（{@code StorageBlockEntity}），
 * 此处使用了完全限定类名。
 *
 * <p>Farm &amp; Charm 已被排除，因为其重写中已使用安全的
 * {@code instanceof ServerLevel} 模式匹配。
 */
@Mixin(value = {
        net.satisfy.vinery.core.block.entity.StorageBlockEntity.class,
        net.satisfy.meadow.core.block.entity.StorageBlockEntity.class,
        net.satisfy.bakery.core.block.entity.StorageBlockEntity.class,
        net.satisfy.bloomingnature.core.block.entity.StorageBlockEntity.class,
        net.satisfy.brewery.core.block.entity.StorageBlockEntity.class
        // WilderNature 尚未发布 1.21.1 NeoForge 版本，届时请在此处添加其
        // StorageBlockEntity 目标——它几乎肯定也使用了相同的盲目
        // (ServerLevel) 强转模式：
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
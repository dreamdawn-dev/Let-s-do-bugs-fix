package com.letsdo.crashfix.mixin;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.satisfy.farm_and_charm.platform.PlatformHelper;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
import vectorwing.farmersdelight.common.block.RichSoilFarmlandBlock;

/**
 * Makes Farm & Charm's water sprinkler keep Farmer's Delight Rich Soil
 * Farmland hydrated, just like it hydrates Farm & Charm's own fertilized
 * farmland.
 *
 * <p>
 * {@link RichSoilFarmlandBlock#isNearWater} checks whether the farmland
 * has a water source nearby. This mixin extends that check to also recognize
 * Farm & Charm's {@code water_sprinkler} block as a valid water source.
 *
 * <p>
 * If Farmer's Delight or Farm & Charm is not installed, Mixin will
 * silently skip this patch.
 */
@Mixin(RichSoilFarmlandBlock.class)
public abstract class RichSoilFarmlandSprinklerMixin {

  private static Block sprinklerBlock;

  private static Block getSprinklerBlock() {
    if (sprinklerBlock == null) {
      sprinklerBlock = (Block) BuiltInRegistries.f_256975_.m_7745_(
          new ResourceLocation("farm_and_charm:water_sprinkler"));
    }
    return sprinklerBlock;
  }

  @Inject(method = "isNearWater", at = @At("HEAD"), cancellable = true, remap = false)
  private static void letsdocrashfix$hydrateNearSprinkler(
      LevelReader level, BlockPos pos,
      CallbackInfoReturnable<Boolean> cir) {
    Block sprinkler = getSprinklerBlock();
    if (sprinkler == null) {
      return;
    }
    int range = PlatformHelper.getWaterSprinklerRange();
    for (BlockPos candidate : BlockPos.m_121940_(
        pos.m_7918_(-range, -1, -range),
        pos.m_7918_(range, 1, range))) {
      BlockState state = level.m_8055_(candidate);
      if (state.m_60713_(sprinkler)) {
        cir.setReturnValue(true);
        return;
      }
    }
  }
}
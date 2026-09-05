package com.letsdo.crashfix;

import net.neoforged.fml.common.Mod;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * [Let's Do] Crash Fix
 *
 * 一个 NeoForge 1.21.1 的即插即用补丁模组，修复 Create 蓝图打印与
 * [Let's Do] 系列模组（Vinery、Meadow、Bakery、BloomingNature、
 * WilderNature、Brewery 等）的冲突。
 *
 * <p>[Let's Do] 系列多个方块实体重写了 {@code setChanged()}，
 * 并将其 {@code level} 盲目强转为 {@code ServerLevel} 以通知追踪玩家。
 * Create 的蓝图打印机和蓝图大炮将蓝图加载到假的 {@code SchematicLevel}
 *（来自 catnip）中，而该对象并非 {@code ServerLevel}，因此强转抛出
 * {@link ClassCastException}，导致蓝图加载/打印失败。
 *
 * <p>本模组不会修改任何其他模组的文件。实际修复逻辑位于
 * {@link com.letsdo.crashfix.mixin.LetsDoStorageBlockEntityMixin}。
 */
@Mod(LetsDoCrashFix.MOD_ID)
public final class LetsDoCrashFix {

    public static final String MOD_ID = "letsdo_crashfix";
    private static final Logger LOGGER = LogManager.getLogger(MOD_ID);

    public LetsDoCrashFix() {
        LOGGER.info("[Let's Do] Crash Fix: Create schematic conflict patch loaded.");
    }
}
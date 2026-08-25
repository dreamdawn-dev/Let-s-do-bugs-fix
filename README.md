# [Let's Do] Crash Fix

Forge 1.20.1 独立补丁模组，包含三类修复：

1. 多个 [Let's Do] 模组（Meadow、BloomingNature、Vinery 等）在
   `FMLCommonSetupEvent` 并行阶段同时向原版 `FireBlock` 的可燃方块表写入
   导致的启动崩溃：

`java.lang.ArrayIndexOutOfBoundsException: Index 1024 out of bounds for length 513`

2. Create 的蓝图打印机/蓝图大炮在加载含 Vinery 储酒架方块实体
   （`StorageBlockEntity`）的蓝图时崩溃：

`java.lang.ClassCastException: SchematicLevel cannot be cast to ServerLevel`

3. Farmer's Delight 的沃土耕地（Rich Soil Farmland）不识别 Farm & Charm
   洒水器（Water Sprinkler）为水源，导致沃土无法在洒水器附近保持湿润并
   退化为普通泥土。

## 原理

原版 `FireBlock` 内部用两个非线程安全的 fastutil 哈希表保存方块的可燃
概率。多个 Let's Do 模组各自在自己的 `FlammableBlockRegistry.init()` 里
并发调用 `FireBlock.registerFlammable`（SRG 名 `m_53444_`），两张表在
rehash 时被同时改写，key/value 数组长度不一致，直接越界崩溃。

Vinery 的 `StorageBlockEntity.setChanged()` 会把 level 强转为
`ServerLevel`，而 Create 的蓝图系统使用假的 `SchematicLevel`，强转直接
抛异常，导致蓝图无法加载。

Farmer's Delight 的 `RichSoilFarmlandBlock.isNearWater()` 只检查原版水
方块，而 Farm & Charm 的洒水器（`water_sprinkler`）理应被当作水源，但
未被识别，导致沃土在洒水器附近退化。

本模组通过 vanilla-only 的 Mixin：
- 把 `FireBlock.m_53444_` 里的两次 `Object2IntMap.put` 重定向到一把全局锁上，
  把所有注册写入串行化；
- 对 Vinery / Meadow / BloomingNature / Brewery / Farm & Charm / Bakery /
  doapi 里共 13 个方块实体的 `setChanged()` 在非 `ServerLevel` 的假世界里
  直接跳过；
- 对 Farmer's Delight 的 `RichSoilFarmlandBlock.isNearWater()` 注入额外检查，
  使 Farm & Charm 的 `water_sprinkler` 方块也被识别为有效水源。

**不修改任何原模组的文件，也不改动任何游戏数据。**

## 使用

把 `dist/letsdo-crashfix-1.0.3-mc1.20.1-forge.jar` 放进
`mods` 目录即可（无需其它前置模组）。

启动日志中看到：

`[Let's Do] Crash Fix: flammable registration is now serialized via FireBlock mixin.`

即代表补丁已生效。
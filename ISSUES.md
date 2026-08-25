# 问题记录：Create 蓝图系统与 [Let's Do] 系列模组的 SchematicLevel 强转冲突

记录日期：2026-08-14

## 现象

服务端日志反复出现：

```
[Server thread/ERROR] [com.simibubi.create.Create/]: Failed to load Schematic for Printing
java.lang.ClassCastException: class net.createmod.catnip.levelWrappers.SchematicLevel
cannot be cast to class net.minecraft.server.level.ServerLevel
```

触发场景：
- 使用 Create 蓝图打印机（Schematic Printer）加载含相关方块实体的蓝图；
- 使用蓝图大炮（Schematicannon）打印含相关方块实体的蓝图；
- 蓝图大炮未卸载时会**每 tick 重复报错**，蓝图无法打印。

不会导致游戏崩溃退出，但蓝图功能不可用，日志刷屏。

日志证据（versions/test/logs/latest.log）：
- 18:08:41  `vinery.StorageBlockEntity.m_6596_` + SchematicPlacePacket
- 18:09:44  `vinery.StorageBlockEntity.m_6596_` + Schematicannon
- 18:15:53  `meadow.StorageBlockEntity.m_6596_` + Schematicannon

## 根因

Let's Do 系列多个模组的方块实体在重写 `BlockEntity.setChanged()`（SRG
`m_6596_`）时，把 `level` **无条件强转成 `ServerLevel`**，然后给追踪玩家发
更新包（`GeneralUtil.tracking((ServerLevel) level, pos)`）。

Create 的蓝图系统加载/放置蓝图时使用的是假世界 `SchematicLevel`
（`net.createmod.catnip.levelWrappers.SchematicLevel`，`isClientSide() == false`
但不是 `ServerLevel`），于是 `checkcast ServerLevel` 抛
`ClassCastException`；Create 捕获后放弃整张蓝图的加载。

## 受影响类（字节码扫描结果，2026-08-14）

以下类的 `m_6596_` 方法体内存在 `checkcast ServerLevel`（均为同一段复制代码）：

| 模组 jar | 类 |
|---|---|
| letsdo-vinery 1.4.41 | `net.satisfy.vinery.core.block.entity.StorageBlockEntity`（日志实锤） |
| | `net.satisfy.vinery.core.block.entity.FlowerPotBlockEntity` |
| letsdo-meadow 1.3.25 | `net.satisfy.meadow.core.block.entity.StorageBlockEntity`（日志实锤） |
| | `net.satisfy.meadow.core.block.entity.CheeseRackBlockEntity` |
| letsdo-bloomingnature 1.0.12 | `net.satisfy.bloomingnature.core.block.entity.StorageBlockEntity` |
| | `net.satisfy.bloomingnature.core.block.entity.FlowerPotBigBlockEntity` |
| letsdo-brewery 2.0.6 | `net.satisfy.brewery.core.block.entity.StorageBlockEntity` |
| | `net.satisfy.brewery.core.block.entity.BeerMugBlockEntity` |
| letsdo-farm_and_charm 1.0.14 | `net.satisfy.farm_and_charm.core.block.entity.StorageBlockEntity` |
| letsdo-bakery 2.0.6 | `net.satisfy.bakery.core.block.entity.StorageBlockEntity`（主实例 21:44:44 实锤） |
| letsdo-API (doapi) 1.2.15 | `de.cristelknight.doapi.common.block.entity.StorageBlockEntity` |
| | `de.cristelknight.doapi.common.block.entity.FlowerPotBlockEntity` |
| | `de.cristelknight.doapi.common.block.entity.FlowerBoxBlockEntity` |

已排除（仅引用 ServerLevel，但不在 `m_6596_` 内强转）：
- `farm_and_charm.StoveBlockEntity`
- FTB Quests `QuestBarrierBlockEntity` / `StageBarrierBlockEntity`（强转前有
  `instanceof ServerLevel` 保护，不会崩）
- 其它模组（地牢进行中、Waystones、FastItemFrames 等）的 ServerLevel 强转
  都在 tick 等其它方法里，蓝图加载路径不触发

## 修复方案

在补丁模组（letsdo-crashfix）中新增一个多目标 Mixin，对上述所有类的
`m_6596_` 在方法开头做守卫：当 `level != null && !level.isClientSide() &&
!(level instanceof ServerLevel)` 时直接跳过（假的 SchematicLevel 上无需发
更新包）。正常 ServerLevel / 客户端世界行为完全不变。

状态：
- 守卫 Mixin 已扩展为多目标，覆盖上表全部 12 个类；
- 1.0.2 补充 `bakery.StorageBlockEntity`（1.0.1 扫描漏掉的同类代码），
  现共 13 个类；
- 已与 FireBlock 并发注册修复合并进同一补丁模组（1.0.1）；
- 编译 classpath 已加入各模组 jar；
- 打包与实测验证中。

## 备注

- 这是 Create 与 Let's Do 的兼容问题，责任在 Let's Do 侧（不应盲转
  ServerLevel）；Create 行为是标准流程。
- doapi 是共享 API，其 3 个类修复后可覆盖其他复用 doapi 方块实体的模组。
- 与之前的 FireBlock 并发注册崩溃（已修复并验证）相互独立。

# [Let's Do] Crash Fix

NeoForge 1.21.1 独立补丁模组，修复 Create 蓝图系统与 [Let's Do] 系列
模组的方块实体冲突。

## 问题

Create 的蓝图打印机/蓝图大炮在加载含 [Let's Do] 方块实体（如储物架
`StorageBlockEntity`）的蓝图时崩溃：

`java.lang.ClassCastException: SchematicLevel cannot be cast to ServerLevel`

## 原理

[Let's Do] 多个模组的 `StorageBlockEntity.setChanged()` 会把 level
强转为 `ServerLevel`，而 Create 的蓝图系统使用假的 `SchematicLevel`
（来自 catnip），强转直接抛异常，导致蓝图无法加载。

Farm & Charm 1.1.23+ 已自行修复（使用 `instanceof ServerLevel` 模式
匹配），其他模组（Vinery、Meadow、Bakery、BloomingNature、WilderNature、
Brewery）仍有此问题。

本模组通过 vanilla-only 的 Mixin 对这些类的 `setChanged()` 注入守卫：
当 `level` 不是 `ServerLevel` 时直接跳过。

**不修改任何原模组的文件，也不改动任何游戏数据。**

## 使用

把 `dist/letsdo-crashfix-2.0.0-mc1.21.1-neoforge.jar` 放进
`mods` 目录即可（无需其它前置模组）。

启动日志中看到：

`[Let's Do] Crash Fix: Create schematic conflict patch loaded.`

即代表补丁已生效。
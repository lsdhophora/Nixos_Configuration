---
name: ascii-art
description: 把图语言（Mermaid / DOT / PlantUML 等）和 Markdown 表格转成 ASCII/Unicode 文本图的技能。需要输出 ASCII 图时使用本技能，一律用 mermaid-ascii CLI 转换，禁止手工画图、手工对齐、手工算宽度。
---

# 图语言 → ASCII 技能（全靠 CLI 转换）

## 核心规则

1. **遇到图语言转 ASCII 的问题全靠 CLI**。用户给出图语言源码（Mermaid、DOT、PlantUML 等）或 Markdown 表格时，禁止手画盒子、禁止手工算宽度、禁止目视对齐。一律把源码交给 `mermaid-ascii` CLI 转换。
2. 输出必须用代码块（```` ``` ````）包裹，代码块内不混入 Markdown 装饰（`**`、`_` 等）。
3. CLI 输出即最终稿：**原样粘贴，不得手工改动**。若 `mermaid-ascii` 未在 PATH，提示用户先执行 `nixos-rebuild switch --flake /home/lophophora/.config/nixos#flowerpot`，不要手工画。
4. CLI 输出无需再跑任何对齐工具——布局由 elkjs 自动计算，CJK 与符号宽度由 CLI 内部处理（见「宽度模型」）。

## 转换流程（必须按顺序）

1. **拿图语言源码**：Mermaid（`graph`/`flowchart`、`sequenceDiagram`、`classDiagram`、`erDiagram`、`stateDiagram(-v2)`）直接可用；DOT / PlantUML / 自定义 DSL 先做机械语法翻译成 Mermaid（只换语法关键字，不改结构、不改语义）。
2. **跑 CLI**：把源码喂给 `mermaid-ascii`（文件或 stdin）。
3. **誊清**：把 stdout 原样粘贴进代码块（mermaid 模式的结尾空行可去掉）。

## 工具命令

### mermaid-ascii（图语言 / 表格 → ASCII）

```bash
mermaid-ascii [选项] [FILE|-]      # Mermaid → ASCII 盒图（省略 FILE 或传 - 读 stdin）
mermaid-ascii table [FILE|-]       # Markdown 表格 → ASCII 盒表
```

常用选项：

- `-a, --ascii`：纯 ASCII 输出（不用 Unicode 框线）
- `-m, --markdown`：从输入中提取所有 ` ```mermaid ` 代码块，逐一渲染
- `-x N`：节点横向间距（默认 5）；`-y N`：纵向间距（默认 5）；`-b N`：盒内边距（默认 1）
- `-c MODE`：颜色 none|auto|ansi16|ansi256|truecolor（默认 none；输出进代码块时保持 none，不要加颜色）

## 宽度模型（CLI 已内置，无需手工处理）

终端显示宽度按「格」计，与 `String#length` 不同：

| 字符类别 | 格数 | 示例 |
|---|---|---|
| ASCII / 半角 | 1 | `A` `1` `%` `+` `<` `>` `~` |
| CJK / 全角 | 2 | `中文` `（）` `：` `。` |
| 符号区（编辑器字体全宽） | 2 | `→ ↔ ↓`（U+2190-21FF）、`► ◇ ▼ ★ ✓`（U+25A0-27BF）、`①②`（U+2460-24FF）、`—`（U+2014/15）、`… ‰ ∑ ∞ ⬤` |
| 盒线 / 数学符号 | 1 | `┌ ─ ┐ │`（U+2500-257F）、`± × ÷ ≤ ≥ ≠ ≈ √` |

> 说明：编辑器字体（Iosevka）把箭头/几何/符号区渲染为 2 格，而盒线与数学符号保持 1 格；CLI 按此模型计算列宽，保证 Iosevka / 终端下边框对齐。

## 样式规范（CLI 自动生成，禁止手工写）

- 流程图：Unicode 框线盒 `┌ ─ ┐ │ └ ┘` + 箭头 `▼` `▶` + 菱形判定 `◇`
- 表格：ASCII `+ - |` 盒线，表头居中
- 时序图：参与者盒 + 实线/虚线箭头

### 禁止

- 表情符号、全角空格、制表符缩进
- 手工绘制盒子/箭头/表格线（哪怕看起来对齐了）——必须过 CLI

## 常见错误与对策

| 现象 | 原因 | 对策 |
|---|---|---|
| CLI 报 render failed | Mermaid 语法不被支持 | 先查语法；DOT/PlantUML 要先机械翻译成 `graph`；仍失败则如实告知用户，不手画 |
| 输出带颜色转义码 | 开了颜色模式 | 去掉 `-c`（保持默认 none）重跑 |
| 盒子太挤 / 箭头重叠 | 节点间距太小 | 加大 `-x`/`-y` 重跑 |
| 图太大撑爆屏幕 | 节点太多 | 压缩 `-x`/`-y` 间距；或拆成多个子图 |
| 含 →/▼/◇ 的行凸出边框 | 编辑器字体（Iosevka）把符号区按 2 格渲染 | 已内置：CLI 将符号区（U+2190-21FF、U+25A0-27BF 等）按 2 格计算；无需手工处理 |

## 输出前检查清单

- [ ] 图是否由 `mermaid-ascii` CLI 生成，未手工改动？
- [ ] 粘贴的是 CLI stdout 原文（可去掉结尾空行）？
- [ ] 代码块内无 Markdown 装饰、无全角空格、无表情符号、无颜色转义码？
- [ ] `mermaid-ascii` 在 PATH 吗？（不在则提示 rebuild，不手画）

## 正确示例（CLI 实测输出）

### Mermaid → ASCII 盒图

源码：

```
graph TD
  A[用户请求] --> B[LLM 层]
  A --> C[策略层]
  B --> D{风险判定}
  C --> D
  D -->|通过| E[放行]
  D -->|拒绝| F[拦截]
```

CLI 输出（`mermaid-ascii -`，原样粘贴）：

```
┌──────────┐               
│          │               
│ 用户请求 │               
│          │               
└──────────┘               
      │                    
      │                    
      ├───────────────┐    
      │               │    
      ▼               ▼    
┌──────────┐     ┌────────┐
│          │     │        │
│  LLM 层  │     │ 策略层 │
│          │     │        │
└─────┬────┘     └────┬───┘
      │               │    
      │               │    
      ├───────────────┘    
      │                    
      ▼                    
◇──────────◇               
│          │               
│ 风险判定 ├──────────┐    
│          │          │    
◇─────┬────◇        拒绝   
      │               │    
    通过              │    
      │               │    
      │               │    
      ▼               ▼    
┌──────────┐     ┌────────┐
│          │     │        │
│   放行   │     │  拦截  │
│          │     │        │
└──────────┘     └────────┘
```

### Markdown 表格 → ASCII 盒表

源码：

```
| 项目 | 值 |
|------|----|
| 名称 | Alice |
| 地址 | 东京 |
```

CLI 输出（`mermaid-ascii table -`，原样粘贴）：

```
+------+-------+
| 项目 |  值   |
| 名称 | Alice |
| 地址 | 东京  |
+------+-------+
```

### 纯 ASCII 模式（`-a`）

源码：

```
graph LR
  A[输入] --> B[处理]
  B --> C[输出]
```

CLI 输出（`mermaid-ascii -a -`，原样粘贴）：

```
+------+     +------+     +------+
|      |     |      |     |      |
| 输入 |---->| 处理 |---->| 输出 |
|      |     |      |     |      |
+------+     +------+     +------+
```

### DOT → Mermaid 机械翻译（`digraph` → `graph TD`）

DOT 源码：

```
digraph flow {
  A -> B;
  B -> C;
  A -> C;
}
```

机械翻译成 Mermaid：

```
graph TD
  A --> B
  B --> C
  A --> C
```

再跑 `mermaid-ascii -`。

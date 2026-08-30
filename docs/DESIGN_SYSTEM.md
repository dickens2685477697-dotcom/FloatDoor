# Float Door 设计系统

> 版本：1.0  
> 适用范围：macOS 14+ 的刘海面板、素材列表、空状态、拖放反馈、弹窗与后续 Prompt 功能  
> 视觉基准：`Design/References/glass-icon-master.png`

## 1. 设计方向

设计关键词是 **暗色空间、烟熏玻璃、柔和浮雕、蓝色行动焦点**。界面应像悬浮在桌面上方的一块安静工具面板：内容图标由半透明深灰玻璃构成，轮廓克制、光线来自左上方；只有当前可执行的主要动作使用清晰的电光蓝。视觉表达服务于快速拖入、辨认和拖出，不做高饱和装饰。

参考图中的关键特征：

- 背景接近炭黑而非纯黑，中心区域略亮，边缘自然压暗。
- 图标有体积感但没有写实纹理；依靠半透明填充、顶部高光、底部暗边和短距离阴影形成层次。
- 玻璃图标内部符号使用冷灰蓝；主操作圆钮使用饱和蓝，成为唯一强焦点。
- 形状圆润、边缘柔化，整体低对比；文字比图形更清晰，保证信息优先。

### 1.1 原则

1. **内容优先**：文件名、类型与保存范围的辨识度高于装饰效果。
2. **玻璃有层级**：背景、容器、卡片、图标底座不能使用同一透明度。
3. **蓝色有语义**：蓝色只表示主操作、选中、拖放命中和键盘焦点。
4. **轮廓一致**：同一尺寸图标使用相同画布、安全区、圆角与光源方向。
5. **状态不只靠颜色**：选中、错误、过期和禁用同时使用形状、描边、文案或透明度表达。

## 2. 设计 Token

实现时应由 `DesignTokens` 或同等集中类型提供，不在 View 内散落新的 RGB、透明度、圆角或阴影数值。以下值是语义基准；在不同显示器上应优先保证文字对比度。

### 2.1 色彩

| Token | 建议值 | 用途 |
| --- | --- | --- |
| `canvas` | `#16191E` | 面板外观的暗色基底 |
| `canvasRaised` | `#1D2128` | 中心提亮、浮层背景 |
| `surfaceGlass` | `#FFFFFF` / 6% | 大区域玻璃填充 |
| `surfaceGlassRaised` | `#FFFFFF` / 9% | 卡片、分段选择器、按钮底 |
| `surfaceGlassPressed` | `#FFFFFF` / 13% | 按下或选中状态 |
| `borderSubtle` | `#FFFFFF` / 10% | 默认容器边线 |
| `borderRaised` | `#FFFFFF` / 16% | 图标底座与交互控件边线 |
| `highlightTop` | `#FFFFFF` / 18% | 左上或顶部内高光 |
| `shadowAmbient` | `#000000` / 34% | 容器环境阴影 |
| `textPrimary` | `#F4F6FA` / 96% | 标题、文件名 |
| `textSecondary` | `#E4E8EF` / 62% | 描述、摘要 |
| `textTertiary` | `#D4D9E2` / 42% | 时间、辅助信息 |
| `iconNeutral` | `#9AA8BC` | 普通图标内部符号 |
| `iconNeutralMuted` | `#718096` | 次要或静止图标 |
| `accent` | `#409EFF` | 主操作、选中、拖放命中 |
| `accentStrong` | `#2F84EA` | 按下态和渐变下沿 |
| `success` | `#55CFA2` | 成功反馈 |
| `warning` | `#F2A64A` | 即将过期、注意 |
| `danger` | `#FF656E` | 删除、导入失败、已过期 |

禁止用青、粉、橙、紫分别给文本、链接、图片、文件做常驻大面积底色。内容类型通过轮廓图形辨别，最多在内部符号使用不超过 20% 的轻微语义色混合。这样可避免当前 `PortalItemCard.iconTint` 所造成的彩虹化视觉。

### 2.2 材质与光影

玻璃层从外到内由四层构成：

1. `ultraThinMaterial` 或等价系统材质；
2. 炭黑覆盖层，展开态约 84–90%；收起动画结束后表面完全透明；
3. 从左上到右下的白色 4% → 透明 → 黑色 18% 渐变；
4. 1 pt 内描边，上侧可见度高于下侧。

图标底座使用同一光源：左上高光，右下暗边。标准阴影为 `y: 4, blur: 10, black 28%`；悬浮态可调整为 `y: 6, blur: 14, black 32%`。不要使用纯白发光、长距离投影或多个彩色阴影。Reduce Transparency 开启时用 `canvasRaised` 的不透明填充替代材质，同时保留描边。

### 2.3 圆角、间距与描边

- 基础间距单位：4 pt；常用间距为 4、8、12、16、20、24 pt。
- 小图标底座：8 pt 圆角；标准图标底座：10 pt；卡片：12 pt；内容区：16 pt；展开面板：42 pt。
- 默认描边：1 pt；拖放命中或键盘焦点：1.5 pt。
- 圆形主操作按钮保持正圆；其余底座使用 continuous rounded rectangle。

### 2.4 字体

使用系统字体，不将文字转为路径。标题优先 rounded design，与当前界面语言保持一致。

| 层级 | 字号 / 字重 | 用途 |
| --- | --- | --- |
| Display | 17 / Bold Rounded | “Float Door”等模块标题 |
| Title | 13–14 / Semibold | 空状态、分区与文件名 |
| Body | 11–12 / Medium | 操作、说明 |
| Caption | 9–10 / Medium | 时间、计数、辅助信息 |

中文正文不得低于 10 pt。文字不要叠加模糊或发光。

## 3. SVG 图标规范

### 3.1 文件与目录

源文件统一放在 `Design/Icons/`，按用途拆分：

```text
Design/
├── References/                 # 视觉参考，不参与编译
├── Icons/
│   ├── Source/                 # 可编辑的 SVG 主文件
│   ├── Optimized/              # 清理后的发布 SVG
│   └── Preview/                # 对照预览图或 contact sheet
└── README.md                   # 资产命名、生成来源与维护说明
```

命名格式为 `portal-{concept}-{variant}.svg`，全小写 kebab-case，例如 `portal-text-glass.svg`、`portal-drop-active.svg`。同一概念的状态只在确有结构变化时另建 SVG；仅颜色、透明度或缩放变化应由组件状态控制。

### 3.2 画布与几何

- 新增的 image-backed reference SVG 使用 `viewBox="0 0 222 222"`，对应参考图中的单个网格 tile；代码 fallback glyph 仍使用 24×24 逻辑网格。
- 默认安全区 2 pt，核心图形控制在 20 × 20；视觉重心居中，必要时允许光学偏移不超过 0.5 pt。
- 标准内部线宽 1.75 pt，最小不得低于 1.5 pt；端点和连接使用 `round`。
- 底座圆角为 5 pt（24 pt 画布）；圆角必须统一，禁止逐图随意调整。
- 参考图直用模式的构建源可使用 `<image>` 裁切，发布 SVG 必须把同一 PNG 以 data URI 内嵌；禁止重新生成另一张图、嵌入外部网络地址或改变源图内容；代码 fallback 仍只使用矢量 path。
- 装饰 path 应尽量合并、减少节点；同组图标的路径精度保持一致。

### 3.3 SVG 内部结构

本轮用户明确要求直接使用附图，因此 `glass-icons.svg` 的 symbol 是“图像裁切层”，不是手工重绘层。每个 symbol 的偏移坐标对应 4×4 网格：列起点约为 98、378、658、938，行起点约为 125、397、669、941。源 PNG 已以 data URI 嵌入，symbol 可独立分发。

每个资产建议按以下语义层组织并保留稳定 `id`：

1. `source-image`：用户提供的 reference tile，保留原始阴影、辉光和材质；
2. `plate`：source tile 自带的烟熏玻璃底座；
3. `plate-highlight`：左上/顶部高光；
4. `glyph`：冷灰蓝主体符号；
5. `glyph-highlight`：极弱的顶部提亮，可选；
6. `border`：1 pt 半透明内描边。

SVG 色值应引用固定调色板，不产生每个图标独有的随机灰蓝。渐变方向统一从 `(0,0)` 到 `(1,1)`。为保证 SwiftUI 模板着色，发布资产应同时保留：

- `glass` 多色版：包含材质层，用于 32 pt 及以上的空状态、内容类型和品牌展示；
- `template` 单色版：只保留 glyph，用于 12–20 pt 的工具栏、菜单和内联操作。

小尺寸强行保留完整玻璃效果会糊成一团，因此 20 pt 以下的运行时 fallback 使用 template 路径；本轮 reference SVG 为了直接复用附图，明确保留 image-backed tile，不再将其伪装为真矢量。

### 3.4 当前项目图标映射

| 语义 | 当前 SF Symbol | 目标资产 / 用法 |
| --- | --- | --- |
| 应用入口 | `door.left.hand.open` | `portal-door-glass` / `portal-door-template` |
| 一次性区域 | `clock.arrow.circlepath` | `portal-temporary-template` |
| 长期素材 | `archivebox`, `shippingbox.fill` | `portal-archive-template` / `portal-archive-glass` |
| 文本 | `text.alignleft` | `portal-text-glass` |
| 链接 | `link` | `portal-link-glass` |
| 图片 | `photo` | `portal-image-glass` |
| 文件 | `doc` | `portal-file-glass` |
| 空状态 / 接收槽 | `tray` | `portal-tray-glass` |
| 拖放命中 | `tray.and.arrow.down.fill`, `arrow.down.to.line.compact` | `portal-drop-active`；箭头可在代码中独立着色 |
| Prompt | `text.quote`, `text.badge.plus` | `portal-prompt-glass` / `portal-prompt-add-template` |
| 收起、更多、关闭、时间、加号 | `chevron.up`, `ellipsis`, `xmark`, `clock`, `plus` | 自有 `PortalGlyphShape` template 路径 |
| 成功、信息、错误 | `checkmark.circle.fill`, `info.circle.fill`, `exclamationmark.triangle.fill` | 自有语义 template 路径；由状态 token 着色 |

结构性内容图标与系统操作符号都通过 `PortalGlyph` 语义层和自有矢量路径呈现；交互语义、辅助功能标签和小尺寸清晰度仍遵循 macOS 习惯。AppKit 菜单栏另用单色 template 路径，不能直接放置彩色玻璃底座。

## 4. 图标组件

图标调用必须通过统一组件，不在业务 View 中重复拼装背景、描边和阴影。建议组件 API 包含：

- `name`：语义图标枚举，不允许任意字符串散落；
- `size`：`inline(16)`、`control(24/28)`、`card(42)`、`hero(72)`；
- `style`：`template`、`glass`、`accentAction`；
- `state`：`normal`、`hovered`、`pressed`、`selected`、`dropTarget`、`disabled`、`destructive`；
- `accessibilityLabel`：纯装饰图标应隐藏，独立图标按钮必须提供标签。

尺寸规则：

| 级别 | 容器 | glyph | 场景 |
| --- | ---: | ---: | --- |
| Inline | 无 / 20 | 12–16 | 文字旁、元数据、菜单 |
| Control | 28 | 12–16 | 收起、更多、关闭、卡片操作 |
| Card | 42 | 18–22 | 文本、链接、图片、文件 |
| Section | 48 | 22–24 | Prompt 占位与小型空状态 |
| Hero | 72–96 | 36–48 | 主空状态插图 |

组件必须用 `.resizable().scaledToFit()` 或等价方式保持比例，不拉伸 path。图标按钮的可点击区域至少 28 × 28 pt；关键操作建议 32 × 32 pt。

## 5. 组件规范

### 5.1 面板

展开面板保留 `NotchShape` 与 42 pt 底部圆角。背景使用 `canvas` + 系统材质 + 微弱纵向渐变；避免把 `Color.black.opacity(0.90)` 再叠加到无法感知材质的程度。出现时面板以固定速度淡入；收起时完整面板以顶部中心为锚点连续缩小，并以相同时长匀速淡出。动画结束后只保留透明的刘海悬停与拖放命中区。

### 5.2 分段选择器

未选项只显示 `textSecondary` 与 template 图标；选中项使用 `surfaceGlassPressed`、`borderRaised` 和主文字。拖入目标在外侧叠加 accent 1.5 pt 描边，不能只改变背景色。

### 5.3 素材卡片

卡片使用 `surfaceGlassRaised`、12 pt 圆角和 1 pt 描边。内容类型使用 42 pt `glass` 图标；真实图片缩略图保持原图，不套灰蓝色滤镜，但使用同一圆角、边框与阴影。卡片操作使用 template 图标，默认低对比，hover 后提升。

### 5.4 空状态与拖放层

空状态采用 72–96 pt 组合插图：接收槽为烟熏玻璃，文本、图片、链接卡片可略有角度但不超过 ±12°，蓝色向下箭头作为主要行动提示。默认态蓝色只占整体视觉面积约 10–15%。

拖放命中时：背景增加 accent 12–15% 覆盖，边缘使用 1.5 pt accent 描边；中心箭头从灰蓝切换为 accent，并显示明确“松开放入……”文案。虚线只能用于实际 drop target，不用于普通卡片。

### 5.5 按钮、通知与弹窗

- 主按钮：accent 渐变、白色 glyph/文字；按下态整体亮度降低约 8%，不额外发光。
- 次按钮：玻璃底 + template 图标；hover 提升填充和描边。
- 危险按钮：仅在确认或悬浮时显式使用 danger，默认不常驻大红底。
- 通知：保留 success / warning / danger / information 语义色，图标风格仍为 template。
- `NewMaterialSheet` 与 `RenameItemSheet` 应使用同一深色材质、输入框、圆角和按钮 token，不使用与主面板割裂的系统默认浅色外观。

## 6. 状态矩阵

| 状态 | 填充 | 描边 | 图标 / 文字 | 动效 |
| --- | --- | --- | --- | --- |
| Normal | 基准玻璃 | 10–16% 白 | neutral / secondary | 无 |
| Hover | 填充 +3% 白 | +4% 白 | 提升至 primary | 120 ms ease-out |
| Pressed | 填充 +5% 白 | 保持 | 亮度 -8% | 缩放至 0.97，80 ms |
| Selected | 13–15% 白 | 16% 白 | primary；必要时 accent 标记 | 160 ms ease-out |
| Drop target | accent 12–15% | accent 80–90% | accent + 明确文案 | 箭头位移 3 pt，循环一次或轻脉冲 |
| Disabled | 4% 白 | 6% 白 | 35–40% opacity | 无 |
| Destructive | 默认玻璃 | hover 时 danger 35% | danger | 120 ms |
| Expired | 默认玻璃 | danger 22% | 时间与状态标记 danger | 无 |

## 7. 动效

动效只解释层级和操作结果：

- 面板展开：现有 spring `response 0.42 / damping 0.86` 可保留；收起 220 ms。
- hover：120 ms ease-out；按下：80 ms；选中切换：160–200 ms。
- 拖入：箭头向下 3 pt 并回位，总时长 360 ms；避免无限弹跳。
- 新增卡片：透明度 0 → 1、向上 6 pt → 0，200 ms。
- 删除：淡出并缩至 0.96，160 ms；列表随后重排。
- `accessibilityReduceMotion` 开启时取消位移、缩放、弹簧与循环，只保留不超过 120 ms 的透明度变化。

## 8. 无障碍

- 正文与背景对比度至少 4.5:1；大字和关键图形至少 3:1。半透明 token 应以实际合成后的颜色验收。
- 图标按钮必须有中文 `accessibilityLabel` 和必要的 `accessibilityHint`；图标与可见文字表达相同时隐藏图标的辅助功能节点。
- 颜色不是唯一状态信号：拖放命中需描边和文案；过期需时间或“已过期”文本；选中需背景或标记。
- 支持 Reduce Motion、Increase Contrast、Reduce Transparency。Increase Contrast 下描边提升到 1.5 pt，次要文字不低于 70% 不透明度。
- 24 pt 以下图标在 1× 与 2× 下都要检查；不可依赖细于 1.5 pt 的线或低于 20% 的 glyph 对比。
- 保持完整键盘导航与可见焦点环；菜单和标准语义操作继续使用 macOS 熟悉的 SF Symbols。

## 9. 实施边界

本轮改造集中在 Presentation 与设计资产层，不改变 `Domain`、`Application`、拖放识别或持久化规则。建议依序完成：

1. 建立 token、图标枚举和统一图标组件；
2. 导入、清理并预览 SVG 资产；
3. 替换空状态与内容类型图标；
4. 收口工具栏、卡片操作、通知和 Sheet；
5. 做状态、无障碍和视觉回归验收。

使用 SVG 时应通过 Asset Catalog 或可靠的矢量加载路径接入 SwiftUI；不得在 View 中解析不受信任的 SVG 文本。设计源文件与 App 编译资产应分离，发布资产发生变化时同步更新预览和资产清单。

## 10. 验收清单

### 视觉

- [ ] 展开、收起、空列表、有内容、Prompt 占位和 Sheet 均使用同一暗色玻璃语言。
- [ ] 所有结构性内容图标已替换为统一 SVG / 代码镜像路径，系统操作符号全部通过 template 组件呈现。
- [ ] 图标的光源、圆角、线宽、安全区和灰蓝色一致，无随机彩色底座。
- [ ] 蓝色只出现在主操作、选中、拖放命中或焦点状态。
- [ ] 真实图片缩略图不被玻璃图标风格覆盖。
- [ ] 1× / 2×、深色桌面与浅色桌面背景下无脏边、裁切、锯齿或透明度断层。

### 交互

- [ ] Normal、Hover、Pressed、Selected、Drop target、Disabled、Destructive 状态均可辨认。
- [ ] 一次性、长期、透明刘海命中区和 Prompt 区域的拖入反馈明确且不会误报成功。
- [ ] 图标替换不改变点击、菜单、拖入、拖出、重命名和删除行为。
- [ ] 面板动画连续，无图标尺寸跳变或材质闪烁。

### 无障碍与工程

- [ ] VoiceOver 能准确读出所有独立图标按钮；装饰图标不会重复朗读。
- [ ] Reduce Motion、Reduce Transparency、Increase Contrast 下仍可使用。
- [ ] 文本与关键图形达到对比要求，状态不只依靠颜色。
- [ ] reference SVG 均直接使用用户提供的图像 tile，图像以内嵌 data URI 携带且无网络外链；代码 fallback glyph 保持真矢量、无字体依赖。
- [ ] 业务 View 中不存在新增的魔法颜色、圆角、阴影或任意图标字符串。
- [ ] `swift build` 与 `swift test` 通过，现有领域与持久化行为不受影响。

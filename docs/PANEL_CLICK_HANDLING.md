# 刘海面板点击与拖拽事件处理故障复盘

## 背景

Float Door 以 accessory 应用运行，主界面是置于状态栏层级的无边框 `NSPanel`。SwiftUI 内容由 `NSHostingController` 承载，并嵌入负责悬停、拖放和窗口尺寸的 `TrackingContainerView`。

这种窗口与普通应用主窗口不同：用户点击面板时，Xcode、浏览器等其他应用通常仍在前台。按钮必须能接收 first mouse，且不能在 `mouseDown` 和 `mouseUp` 之间激活或重排窗口。

## 故障现象

长期区域的“新建素材”和“重命名”按钮正常显示，也存在辅助功能 Button 节点，但真实鼠标点击不执行 action。业务 action 本身没有故障：通过辅助功能直接执行 action 时，新建和重命名 sheet 均能正常出现。

因此排查必须区分两条链路：

```text
显示与辅助功能树存在
        ≠
真实鼠标事件完成 mouseDown → tracking → mouseUp → action
```

## 根因

本次故障由多层事件处理叠加造成。

### 1. SwiftUI 覆盖层没有形成可靠命中目标

早期方案将可视 `Button` 设置为 `.allowsHitTesting(false)`，再覆盖一个 `NSViewRepresentable`。该修饰符会使相关组合视图失去命中资格，实际点击仍只到达 `NSHostingView`。

把覆盖层从 `ZStack` 改成 overlay 只能修正尺寸，不能解决命中被禁用的问题。

### 2. `NSButton.isTransparent` 被误当成“只隐藏绘制”

第二版原生命中方案使用空标题 `NSButton`，同时设置 `isTransparent = true`。该属性不适合作为可交互热区的隐藏方式，会破坏正常按钮 tracking/action 行为。

不可见但可交互的按钮应保持正常启用，仅使用以下方式隐藏视觉：

- 空标题；
- `isBordered = false`；
- `focusRingType = .none`；
- 不设置 `isTransparent = true`。

### 3. 点击过程中激活或重排窗口

诊断阶段曾在本地鼠标事件监视器的 `mouseDown` 中调用 `makeKeyAndOrderFront`。这会在原生按钮完成 tracking 前改变窗口状态，导致本轮点击无法形成完整 action。

面板必须保持 `.nonactivatingPanel` 和 `becomesKeyOnlyIfNeeded = true`。只有确定要展示编辑 sheet 时，才由 `beginModalInteraction()` 激活应用并提升窗口层级。

### 4. 测试覆盖层级错误

最初测试只证明了隔离的按钮组件能够调用闭包，没有包含真实 `NSPanel`、`NSHostingView`、窗口激活策略和顶层视图顺序，产生了“测试通过但实际失败”的假阳性。

## 最终方案

视觉仍由 SwiftUI 绘制；关键头部操作的鼠标命中由 `TrackingContainerView` 最上层的原生 `NSButton` 负责。

```text
NotchPanel
└─ TrackingContainerView
   ├─ NSHostingView<PortalRootView>     # SwiftUI 视觉与辅助功能
   ├─ NSButton：素材新建               # 原生点击热区
   ├─ NSButton：素材重命名
   ├─ NSButton：自定义区域新建
   └─ NSButton：自定义区域重命名
```

实现约束：

- 原生按钮必须在 hosting view 之后加入，保证位于最上层。
- `FirstMouseHotspotButton` 必须返回 `acceptsFirstMouse = true`。
- 热区只在 720 × 432 的展开状态显示，收起状态必须隐藏。
- 回调通过 `installActionHotspots(...)` 注入，不让容器直接持有业务状态。
- 新建和区域重命名统一交给 `NotchPanelController` 以原生 attached sheet 呈现。
- SwiftUI 按钮继续负责视觉和辅助功能语义，同时作为键盘/辅助功能回退。

当前面板尺寸固定，AppKit 使用左下角坐标系。若修改面板尺寸、pane 间距或头部布局，必须同步更新 `TrackingContainerView.layout()` 中的四个热区，并更新点击测试坐标。

## 回归测试要求

`PortalControlHitTestingTests` 必须至少验证：

1. `NotchPanel` 包含 `.nonactivatingPanel`。
2. `becomesKeyOnlyIfNeeded` 为 `true`。
3. 展开尺寸下四个操作坐标均命中真实 `NSButton`。
4. 四个按钮均接受 first mouse。
5. 四个按钮在真实 `NotchPanel` 中依次执行对应回调，且顺序正确。

自动测试之外，涉及窗口、布局或按钮事件的修改还必须进行运行时冒烟测试：

1. 保持 Xcode 或浏览器在前台。
2. 展开 Float Door 并切换到“长期”。
3. 分别点击两个“新建素材”和两个“重命名”。
4. 确认首次点击即出现正确 sheet。
5. 关闭 sheet 后确认面板层级和自动收起行为正常。

## 排查顺序

以后遇到“按钮可见但无响应”，按以下顺序检查：

1. 通过辅助功能 action 判断业务回调和 sheet 是否正常。
2. 在 `NSPanel` 的 `contentView.hitTest(_:)` 检查真实命中对象。
3. 确认命中对象是原生热点按钮，而不是仅到达 `NSHostingView`。
4. 检查按钮是否被隐藏、禁用或设置了 `isTransparent = true`。
5. 检查 `mouseDown` 期间是否调用了 `activate`、`makeKeyAndOrderFront` 或窗口动画。
6. 检查热区坐标是否随布局变化而失配。

不要用“编译通过”或隔离组件测试代替完整面板验证。

## 顶部“长期”切换按钮偶发多次点击（2026-08-28）

状态：已定位并归档；本次未修改生产代码。

### 现象与范围

面板已经展开、当前停留在“一次性”区域时，点击顶部右半侧“长期”切换按钮并不总能切换。用户经常需要连续点击多次，直到某一次点击才生效。

本节只讨论鼠标点击切换页面，不讨论把文件拖到“长期”标签时的悬停切页；后者由下文的 AppKit 拖拽命中链路负责。

### 诊断结论

根因是顶部范围切换按钮没有接入面板现有的 first-mouse 原生热区方案。

`PortalRootView.scopeButton(...)` 使用纯 SwiftUI `Button`。在真实展开面板中检查“长期”标签中心点 `(520, 335)`，命中结果和 first-mouse 能力如下：

```text
hitTest → NSHostingView<PortalRootView>
acceptsFirstMouse(for:) → false
```

`NotchPanel` 同时使用 `.nonactivatingPanel` 和 `becomesKeyOnlyIfNeeded = true`。面板由悬停展开时，还会执行应用激活、key window 切换和 0.2 秒淡入。点击落在应用或面板尚未完成 active/key 交接的时间窗内时，AppKit 会把本轮点击用于窗口状态处理，SwiftUI `Button` 收不到完整的 `mouseDown → mouseUp → action`。窗口状态稳定后再点击，action 才会执行，所以表现为偶发且需要多次点击，而不是持续完全失效。first-mouse 能力缺失已经由真实命中测试确认；具体失败点击落在 active/key 交接的哪一帧，是根据窗口代码和 active 状态下的对照测试推定，后续修复验收时应增加窗口状态日志复核。

现有的四个长期页头部操作和卡片按钮之所以更稳定，是因为它们最终命中 `FirstMouseHotspotButton`、`FirstMouseCardActionButton` 或 `FirstMouseCardMenuButton`，这些原生控件都显式返回 `acceptsFirstMouse = true`。顶部“一次性 / 长期”两个范围按钮没有对应原生热区，形成了实现缺口。

### 证据链

1. “长期”按钮中心坐标可以命中真实面板内部，排除按钮矩形偏移或点击区域过小。
2. 真实命中对象是整个 `NSHostingView<PortalRootView>`，不是接受 first mouse 的 `NSButton`。
3. 该命中对象的 `acceptsFirstMouse(for:)` 明确为 `false`。
4. 在面板已经是 key/active 时，向同一坐标发送一次完整鼠标事件即可把 `activeSection` 从 `.temporary` 切换为 `.permanent`，证明 `selectSection` 和状态更新逻辑正常。
5. 现有 `PortalControlHitTestingTests` 的 10 个用例全部通过，但只覆盖页头原生热区、卡片操作和拖拽经过 `.permanentTab`；没有鼠标点击顶部范围按钮的用例。这解释了为什么回归测试未能发现问题。

### 修复建议

沿用已经验证过的 AppKit 顶层热区架构，不改变 SwiftUI 视觉层：

1. 在 `TrackingContainerView` 增加“一次性”和“长期”两个 `FirstMouseHotspotButton`。
2. 两个按钮必须在 `NSHostingView` 之后加入，并在展开尺寸下覆盖 scope switcher 的两个内部按钮矩形；收起时隐藏。
3. 点击回调由 `NotchPanelController` 注入，最终调用与 SwiftUI 按钮相同的 section 切换入口，避免维护两套状态逻辑。
4. 保留 SwiftUI `Button` 的视觉、键盘和辅助功能语义；原生热区只负责可靠的真实鼠标路由。
5. 不要将热区设置为 `isTransparent = true`，继续使用空标题、无边框和无 focus ring 隐藏视觉。

### 必须补充的回归测试

1. 在真实展开 `NotchPanel` 中，两个标签中心点都命中 `FirstMouseHotspotButton`。
2. 两个标签热区的 `acceptsFirstMouse(for:)` 均为 `true`。
3. 从非 key 窗口场景发送第一组 `mouseDown / mouseUp`，一次性标签和长期标签都只执行一次对应回调。
4. 分别验证 `.temporary → .permanent` 和 `.permanent → .temporary`，防止只修右侧按钮。
5. 收起尺寸下两个标签热区隐藏，不能遮挡刘海悬停或拖放入口。
6. 保留现有 `.permanentTab` 拖拽坐标测试，确认新增点击热区不改变拖拽切页行为。

运行时冒烟测试要在其他应用位于前台的情况下执行：悬停展开面板后，立即单击“长期”，再单击“一次性”，两次都必须首击切换；等待面板完全淡入后重复一次，结果应一致。

## 拖拽切区与自定义区域故障复盘

### 故障现象

拖拽文件进入已展开的面板后，存在两个看似独立的问题：

1. 从“一次性”页面拖到顶部“长期”按钮时，页面不切换到长期视图。
2. 长期视图右侧的自定义区域（例如“个人简历”）无法像左侧素材区域一样接收拖放。

这两个区域的 UI、目标枚举和导入 scope 都已经存在，因此继续修改 SwiftUI 的高亮层、`onDrop` 修饰符或导入逻辑无法稳定解决问题。它们共同依赖外层 `TrackingContainerView` 对拖拽位置的原生命中判断，真正的故障发生在坐标转换阶段。

### 拖拽事件链路

展开状态下，外层 AppKit 容器负责跨应用拖拽会话，SwiftUI 负责显示当前页面与目标高亮：

```text
NSDraggingInfo.draggingLocation（窗口坐标）
        ↓
TrackingContainerView.destination(atWindowPoint:)
        ↓
PortalDropDestination
        ├─ permanentTab → 切换 primarySection 到长期
        ├─ permanentArea → 导入 StorageScope.permanent
        └─ customArea    → 导入 StorageScope.custom
```

`draggingEntered` 和 `draggingUpdated` 持续发布悬停目标；悬停目标是 tab 时，`NotchPanelController.setDragHoveredDestination` 立即同步 `activeSection`，`PortalRootView` 再切换可见内容。`prepareForDragOperation` 和 `performDragOperation` 必须复用同一个目标计算函数，确保“显示为可放置”和“松手后实际导入”的判定一致。

### 根因：把窗口坐标再次当成屏幕坐标转换

`NSDraggingInfo.draggingLocation` 已经位于拖拽目标窗口的 base coordinate system。旧实现把该值传给 `destination(atScreenPoint:)`，又调用了一次：

```swift
let windowPoint = window.convertPoint(fromScreen: draggingLocation)
```

面板位于屏幕顶部中央，窗口原点通常不是 `(0, 0)`。上述转换会再次减去窗口原点，使本应位于 720 × 432 面板内部的点变成负数或大幅偏移。顶部“长期”按钮和右侧自定义区域因此都无法命中。

部分区域偶尔仍能通过 SwiftUI 自身的 `onDrop` 接收内容，容易让排查方向误以为只有某一个区域的修饰符失效。SwiftUI 子视图能够处理一次拖放，并不能证明外层 AppKit 拖拽桥接正常。

### 坐标使用规则

| 输入 | 坐标空间 | 正确处理 |
| --- | --- | --- |
| `NSDraggingInfo.draggingLocation` | 目标窗口坐标 | `convert(windowPoint, from: nil)` 转为容器局部坐标 |
| `NSEvent.mouseLocation` | 屏幕坐标 | 可直接与 `NSScreen.frame` 比较 |
| SwiftUI 布局尺寸 | 顶部起算 | 命中 AppKit 视图时换算为左下角原点 |

不要根据变量名猜测坐标空间。任何新增的拖拽、鼠标或窗口 API 都应先查清其坐标定义，再集中到一个有明确参数名的转换入口。

### 修复原则

目标计算统一为 `destination(atWindowPoint:)`：

```swift
func destination(atWindowPoint windowPoint: NSPoint) -> PortalDropDestination? {
    guard bounds.width >= 700, bounds.height >= 400,
          window != nil else { return nil }

    let localPoint = convert(windowPoint, from: nil)
    // 使用 localPoint 判断 tab、素材区域和自定义区域。
}
```

以下三个阶段必须传入未经屏幕转换的 `sender.draggingLocation`：

- 悬停更新：决定切换页面和显示目标高亮；
- `prepareForDragOperation`：决定当前位置能否接收；
- `performDragOperation`：决定最终导入哪个 scope。

真正使用屏幕坐标的刘海附近唤醒逻辑仍使用 `NSEvent.mouseLocation`，不能为了“统一”而改成窗口坐标。

### 回归测试策略

`PortalControlHitTestingTests` 使用非零窗口原点 `(900, 500)` 创建真实 `NotchPanel`。这个条件非常重要：如果测试窗口恰好位于屏幕原点，即使错误地重复做屏幕到窗口转换，测试也可能继续通过。

拖拽命中测试至少覆盖：

1. 一次性页面下，顶部长期按钮坐标返回 `.permanentTab`。
2. 长期页面下，左侧素材区域返回 `.permanentArea`。
3. 同一页面下，右侧自定义区域返回 `.customArea`。
4. 素材区域和自定义区域使用同一窗口坐标入口，不为某个区域增加特殊旁路。

运行时冒烟测试仍不可省略：从 Finder 拖动真实文件，在“一次性”页面悬停“长期”，确认视图切换；继续移动到左右两个区域，确认高亮正确，并分别松手验证内容进入对应 scope。

### 拖拽问题排查顺序

以后遇到“某个区域不能拖入”或“悬停不切页”，按以下顺序检查：

1. 记录 `draggingLocation`、窗口 frame、转换后的 local point 和最终 destination。
2. 确认当前回调参数究竟是屏幕、窗口还是局部坐标。
3. 确认 `draggingEntered`、`draggingUpdated`、prepare 和 perform 使用同一命中函数。
4. 确认 tab 悬停后 `activeSection` 已同步到 `TrackingContainerView`。
5. 确认 `.customArea` 最终映射到 `.custom`，而不是 `.permanent`。
6. 用非零窗口原点的真实 `NSPanel` 补回归测试。
7. 最后再检查 SwiftUI `onDrop`、覆盖层和导入 provider，避免从表现层开始盲目修改。

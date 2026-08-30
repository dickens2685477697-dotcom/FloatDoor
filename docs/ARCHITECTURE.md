# Float Door 架构说明

## 目标

当前代码按依赖方向拆为四层，核心规则不依赖 AppKit/SwiftUI，平台输入输出通过适配器接入。后续增加 Prompt、浏览器投递或新的存储实现时，应优先新增独立功能模块，而不是继续扩大 `PortalStore` 或 `PortalRootView`。

```text
App（组装与生命周期）
  └─ Presentation（窗口与 SwiftUI）
       └─ Infrastructure（拖放、剪贴板、分享、磁盘）
            └─ Application（状态与用例）
                 └─ Domain（模型与纯规则）
```

实际依赖不要求每一层都依赖相邻层：`Presentation` 可以直接调用 `Application`；`Application` 只通过 `PortalRepository` 协议访问持久化。

## 目录职责

- `App/`：应用入口和依赖组装。只处理生命周期、菜单命令和模块连接。
- `Domain/`：`PortalItem`、保存策略、文件导入结果及构造规则。不引用 UI 框架。
- `Application/`：`PortalStore` 和通知状态；`Ports/` 定义外部能力协议。
- `Infrastructure/Import/`：把系统拖放与剪贴板转换成应用层导入命令。
- `Infrastructure/Persistence/`：JSON 元数据与本地文件副本。
- `Infrastructure/Sharing/`：把领域对象转换为系统拖出表示。
- `Presentation/Panel/`：刘海面板生命周期和 AppKit 容器。
- `Presentation/Portal/`：主界面、卡片、可复用组件和弹窗。
- `Presentation/Settings/`：设置窗口。

## 扩展约定

### 新增一种内容类型

1. 在 `PortalItemType` 增加类型和展示元数据。
2. 在 `PortalItemFactory` 增加统一构造规则。
3. 在对应输入适配器中识别系统数据，调用 `PortalStore` 的应用命令。
4. 在 `PortalItemProviderFactory` 增加拖出表示。
5. 为持久化往返和应用命令补测试。

### 新增 Prompt 功能

建议新建 `Domain/Prompt`、`Application/PromptStore`、`Infrastructure/PromptPersistence` 与 `Presentation/Prompt`，不要把 Prompt 草稿状态并入 `PortalStore`。Portal 与 Prompt 之间通过明确命令传递附件或文本。

### 更换存储实现

实现 `PortalRepository` 并在 `AppDelegate` 这个组装入口注入即可。`PortalStoreArchitectureTests` 展示了无磁盘仓储的注入方式。

## 依赖规则

- `Domain` 不导入 AppKit 或 SwiftUI。
- `Application` 不直接读取剪贴板、构造 `NSItemProvider` 或打开窗口。
- 平台 API 只放在 `Infrastructure` / `Presentation`。
- View 只负责界面状态和用户意图，不直接写 JSON 或复制文件。
- 跨功能共享优先通过小协议或值类型，避免全局单例。

## 刘海面板事件边界

刘海面板是 accessory 应用中的 nonactivating `NSPanel`，不能按普通 SwiftUI 主窗口处理 first mouse。关键头部操作由 `TrackingContainerView` 顶层原生按钮负责命中，SwiftUI 负责视觉和辅助功能语义；新建与区域重命名由 `NotchPanelController` 统一呈现原生 attached sheet。

不得在 `mouseDown` 事件监视器中激活或重排面板，也不得使用 `NSButton.isTransparent = true` 创建可点击热区。面板尺寸或头部布局变更时，必须同步更新原生热点和 `PortalControlHitTestingTests`。完整原因、实现约束与排查顺序见 [刘海面板点击与拖拽事件处理故障复盘](PANEL_CLICK_HANDLING.md)。

拖拽命中由 `TrackingContainerView` 统一计算。`NSDraggingInfo.draggingLocation` 是窗口坐标，只能转换为容器局部坐标，禁止再次执行 screen-to-window 转换；只有基于 `NSEvent.mouseLocation` 的刘海附近唤醒逻辑使用屏幕坐标。顶部 tab、长期素材区和自定义区域必须复用同一个目标计算入口，并使用非零窗口原点的测试防止坐标转换假阳性。

# Float Door 发布与版本规划

## 发布模型

- 当前内部仓库保留源码、测试、设计和宣传材料，并保持私有。
- 对外产品仓库只包含产品源码、测试、产品文档和发布文件，不包含宣传与作品集材料。
- 产品源码和二进制采用 PolyForm Noncommercial License 1.0.0，允许非商业使用、修改和分发，不授予商业使用权。
- 核心应用以签名、公证后的 Universal DMG 发布，支持 Apple Silicon 与 Intel Mac。
- 用户数据固定保存在 `~/Library/Application Support/FloatDoor`，升级只替换 `/Applications` 中的应用。

## 版本规则

采用语义化版本 `主版本.次版本.修订版本`：

- 修订版本，例如 `1.0.1`：错误修复，不改变数据库格式和扩展接口。
- 次版本，例如 `1.1.0`：向后兼容的新功能；允许新增可迁移的数据字段。
- 主版本，例如 `2.0.0`：可能包含不兼容变化，必须提供数据迁移和回退说明。
- 每次构建另有递增的 `CFBundleVersion`，同一个公开版本不得复用构建号。

## 路线图

### v1.0.0 — 首个正式版

- 首个非商业源码可用版本。
- Universal DMG，最低支持 macOS 14。
- 固定 Bundle ID：`com.floatdoor.app`。
- 保持现有 Application Support 数据目录。
- GitHub Releases 手动下载更新。

### v1.1.0 — 数据安全与升级体验

- 数据库增加显式 `schemaVersion`。
- 升级前自动备份元数据。
- 增加数据导出、恢复和“打开数据目录”。
- 可选接入应用内更新检查，但仍由用户确认下载安装。

### v1.2.0 — 扩展与贡献框架

- 发布稳定的 Extension SDK、接口说明和示例扩展。
- 扩展通过稳定的清单、配置和受限接口工作，不依赖内部实现细节。
- SDK 与示例代码默认采用 PolyForm Noncommercial License 1.0.0。
- 扩展接口遵循兼容性和权限声明规则。

### v2.0.0 — 仅在需要破坏性变化时使用

- 发布前提供旧数据迁移、备份和回退工具。
- 至少保留一个大版本周期的旧数据读取能力。

## 正式发布门槛

1. `swift test` 全部通过。
2. Release 二进制同时包含 `arm64` 与 `x86_64`。
3. App 使用 Developer ID Application 签名并启用 Hardened Runtime。
4. DMG 通过 Apple notarization，并成功 staple。
5. 在干净账户验证首次安装。
6. 使用已有数据验证覆盖安装，确认数据库和缓存文件保留。
7. 上传 DMG 与 SHA-256，并发布对应 Git tag 和 Release notes。

## 数据兼容约束

- 不修改 `Application Support/FloatDoor` 的目录名。
- 不修改正式 Bundle ID。
- 不把用户数据写进 `.app` 或 DMG。
- 数据结构变化必须先备份再迁移，并有自动化测试。
- 如果未来启用 App Sandbox，必须先实现旧目录到 Container 的一次性迁移。

# 书库统一为 Book 模型

将现有的"最近文件列表"（`recentFileURLs: [URL]`）升级为统一的 `Book` 数据模型，使书架同时承载本地书与网络书源在线书，不保留双轨入口。

**Considered Options**

- 方案 A：废弃 `recentFileURLs`，书架完全基于 `Book` 模型。本地书首次打开时静默注册为 `Book(origin: .local(fileURL))`，在线书为 `Book(origin: .online(sourceId, bookUrl))`。
- 方案 B：保留"最近文件"作为轻量快捷入口（只记路径），另建"书库"作为正式管理入口（含在线书、分类、进度）。两者并存。

**Decision**

采用方案 A。理由：当前书架本就是单轨的最近文件列表，升级为 `Book` 模型是自然演进，不引入双轨心智负担。ADR-0005 已定"侧栏只承载阅读辅助信息"，双轨会让书架入口变重。

**Consequences**

- **数据模型**：新增 `Book` 结构体，含 `id / title / author / origin / lastChapterIndex / lastScrollOffset / addedAt / lastReadAt`。`BookOrigin` 为枚举（`.local(URL)` / `.online(sourceId, bookUrl)`）。
- **持久化升级**：`UserDefaults` 不再够用（需存大量书 + 章节缓存索引），升级到 SwiftData（macOS 14+ 原生，与 SwiftUI 集成好）。`ReaderPersistenceStore` 中与 `recentFiles` / `lastFile` / `chapterIndex` / `scrollOffset` 相关的逻辑迁移到 `Book` 实体的属性。
- **迁移**：已有用户的 `recentFileURLs` 数据需一次性迁移为 `Book(origin: .local)` 记录，避免丢历史。
- **书架视图**：`BookShelfView` 及三种布局（desk/spines/drawer）的数据源从 `[URL]` 改为 `[Book]`，卡片可展示标题、作者、进度等信息，不再只靠文件名。
- **兼容**：本地书打开流程保持"打开即读"体验，注册 Book 在后台静默完成，用户无感。

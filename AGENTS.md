# 项目说明

## Agent skills

### Issue tracker

本仓库使用本地 Markdown 文件记录需求、PRD 和任务，路径位于 `.scratch/`；外部 PR 不作为 triage 入口。详见 `docs/agents/issue-tracker.md`。

### Triage labels

本仓库使用中文 triage 标签：`待评估`、`等待补充信息`、`可交给Agent`、`需人工处理`、`不处理`。详见 `docs/agents/triage-labels.md`。

### Domain docs

本仓库使用单上下文领域文档布局。详见 `docs/agents/domain.md`。

## UI 风格约束

后续所有 UI 设计与实现都必须遵守木简自身的 UI 风格，避免混入 macOS 原生默认控件外观。

- 优先复用项目内已有的木简设计系统组件与样式，例如自绘按钮、分段控件、滑杆、开关、浮层、圆角、描边、阴影和主题色。
- 新增按钮、表单控件、设置项、浮层、书架控件、阅读控件时，必须先检查 `Sources/NovelReaderApp/Views/DesignSystem.swift` 和已有视图中的本地组件，不直接使用裸 `Button`、`Picker`、`Slider`、`Toggle` 的系统默认样式。
- 如果必须使用系统控件承载行为，也要用木简风格包裹或自定义样式，使视觉上保持一致。
- 阅读界面保持极简，避免解释性文案、说明段落和长期可见的多余控件；必要提示应短、轻、可关闭或只在交互时出现。
- 小窗体验优先：控件尺寸稳定、文字不挤压、不换出奇怪竖排、不出现系统胶囊按钮感。

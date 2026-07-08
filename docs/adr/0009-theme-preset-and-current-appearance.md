# 主题系统：当前外观与主题模板分离

将主题从固定枚举升级为"模板 + 当前外观"双层体系。主题模板是全套外观预设（颜色+字体+字号+行距），当前外观是用户正在用的独立设置。选主题时把模板抄进当前外观，之后独立调字号/颜色不影响模板。

**Considered Options**

- 方案 A：主题只管 3 个颜色，字号/行距/字体独立在 ReadingSettings。
- 方案 B（方式 i）：主题是全量外观唯一来源，字号/行距滑块变成编辑主题的一部分，预置主题只读。
- 方案 B（方式 ii，本方案）：主题模板 + 当前外观分离。

**Decision**

采用方案 B 方式 ii。理由：用户既想要主题"全套打包"，又想保留字号/行距滑块独立调节、预置主题直接选用。分离双层体系让两者同时成立。

**Consequences**

- **ReadingTheme 从枚举改结构体**：`{ id, name, paperColor, inkColor, accentColor, fontFamily, fontSize, lineHeight, isBuiltIn }`。预置 3 套（纸白/护眼/夜读）`isBuiltIn=true` 不可删。这是破坏性改动，所有 `switch theme` 的地方改为访问结构体字段。
- **ReadingSettings 保留 fontSize/lineHeight/fontFamily/颜色**：这是"当前外观"，滑块直接改它。
- **选主题 = 抄模板**：`readingSettings.apply(themePreset)`，把模板的所有字段灌进当前外观。之后独立调字号只改 ReadingSettings，不影响模板。
- **存为新主题**：用户把当前搭配存成新 `ThemePreset(isBuiltIn: false)`，可编辑可删除。
- **颜色输入**：编辑自定义主题时，支持手动输入色号（`#RRGGBB` / `rgb()`）和 macOS 原生取色器（`NSColorPanel`）两种方式。
- **UI 风格约束**：主题编辑面板（色号输入框、取色器触发、字体选择器、主题列表）必须遵守 AGENTS.md 的 UI 风格约束——复用木简自绘组件，不直接用裸 `Button/Picker/Slider/Toggle` 系统默认样式。
- **持久化**：自定义主题模板存入 SwiftData（与 ADR-0008 的 Book 模型同一数据库）。

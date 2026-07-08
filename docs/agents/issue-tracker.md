# Issue tracker：本地 Markdown

本仓库的需求、PRD 和任务都以 Markdown 文件形式存放在 `.scratch/` 目录中。

## 约定

- 每个功能或阶段使用一个目录：`.scratch/<功能标识>/`
- PRD 文件固定为：`.scratch/<功能标识>/PRD.md`
- 实现任务放在：`.scratch/<功能标识>/issues/<编号>-<任务标识>.md`
- 任务编号从 `01` 开始递增
- 每个任务文件顶部附近使用 `Status:` 记录 triage 状态，具体状态见 `docs/agents/triage-labels.md`
- 讨论记录追加到任务文件底部的 `## Comments` 小节

## 当技能要求“发布到 issue tracker”

在 `.scratch/<功能标识>/` 下创建对应 Markdown 文件；如果目录不存在，先创建目录。

## 当技能要求“读取相关 ticket”

读取用户提供的本地 Markdown 路径。用户通常会直接给出文件路径、功能目录或任务编号。

## Wayfinder 约定

`/wayfinder` 使用一个地图文件和多个子任务文件来拆解较大的探索工作。

- 地图文件：`.scratch/<工作标识>/map.md`
- 子任务文件：`.scratch/<工作标识>/issues/<编号>-<任务标识>.md`
- 子任务文件顶部使用 `Type:` 记录类型，可选值包括 `research`、`prototype`、`grilling`、`task`
- 子任务文件顶部使用 `Status:` 记录状态，可选值包括 `claimed`、`resolved`
- 如果任务被其它任务阻塞，在顶部使用 `Blocked by: <编号>, <编号>` 记录依赖
- 认领任务时，将 `Status:` 更新为 `claimed`
- 完成任务时，将 `Status:` 更新为 `resolved`，并在 `## Answer` 小节写入结论，同时把关键结论追加到地图文件

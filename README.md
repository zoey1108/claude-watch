# Claude一点通 · Apple Watch

点一下屏幕，换一条 Claude 小技巧或新闻；每天定时推送技巧，有新闻时主动提醒。

## 怎么用

| 操作 | 效果 |
|---|---|
| 轻点屏幕 | 换下一张（未读新闻优先，其次随机技巧） |
| 转数码表冠 | 翻看刚才看过的卡片 |
| 长按 | 收藏 / 取消收藏 |
| 左上 ☆ | 收藏夹 |
| 右上 ⚙︎ | 每日技巧条数（0–3）、新闻提醒开关、手动检查新闻 |
| 表盘小组件 | 每 2 小时换一条技巧，点一下打开 App |
| 新闻卡片 | 抬起 iPhone 可通过「接力」打开原文 |

## 结构

```
watch/      手表 App（SwiftUI，watchOS 10+，独立运行不需要 iPhone App）
  App/        主程序：牌堆、通知、后台刷新、界面
  Shared/     卡片模型 + 内置技巧库 tips.json（90 条，App 和小组件共用）
  Widget/     表盘 / 智能叠放小组件
  project.yml 用 xcodegen 生成 Xcode 工程
server/     新闻抓取脚本（Node）
docs/       GitHub Pages 发布目录，cards.json 就是手表读取的新闻源
.github/workflows/news.yml  每 3 小时自动跑一次
```

### 推送是怎么实现的

- **每日技巧**：手表本地定时通知，提前排好 7 天，每次打开 App 自动续排。不需要网络。
- **新闻**：GitHub Actions 每 3 小时抓 Anthropic 官网新闻和 Claude Code 更新日志，用 Claude 改写成中文短卡片，写进 `docs/cards.json`；手表大约每小时在后台拉一次，发现新条目就弹本地通知。整个流程不用自己的服务器，也不需要 APNs 推送证书。

## 改内容

- 技巧：直接编辑 `watch/Shared/tips.json`（标题 ≤14 字，正文 ≤50 字，手表一屏才放得下）
- 新闻改写风格：`server/update-news.mjs` 里的 `SYSTEM`
- 新闻源地址：`watch/App/Config.swift` 的 `newsURL`
- 想指定模型，在仓库 Settings → Variables 里加 `CLAUDE_MODEL`（API 模式默认 `claude-opus-5-5`）

## 构建

```bash
cd watch && xcodegen generate && open ClaudeTap.xcodeproj
```

在 Xcode 里选 ClaudeTap scheme 和你的手表，按运行即可。

## 新闻后端上线（一次性）

1. 推到 GitHub 仓库 `zoey1108/claude-watch`
2. 仓库 Settings → Secrets and variables → Actions，二选一添加：
   - `CLAUDE_CODE_OAUTH_TOKEN`：用 Claude Pro/Max 订阅，不额外付费。本机运行 `npx @anthropic-ai/claude-code setup-token` 生成
   - `ANTHROPIC_API_KEY`：按量付费的 API Key
   都不加也能跑，但新闻会是英文原标题
3. Settings → Pages：Source 选 `main` 分支的 `/docs` 目录
4. Actions → 「更新 Claude 新闻」→ Run workflow，手动跑第一次

本地试跑（不调用 Claude）：`cd server && npm install && npm run dry`

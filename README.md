# AI 一点通 · Apple Watch

抬手点一下屏幕，看一条 AI 使用技巧。90 条中文技巧全部内置，完全离线，不收集任何数据。

## 怎么用

| 操作 | 效果 |
|---|---|
| 轻点屏幕 | 换下一条（一轮看完前不重复） |
| 转数码表冠 | 翻看刚才看过的卡片 |
| 长按 | 收藏 / 取消收藏，会弹出提示 |
| 左上 ☆ | 收藏夹 |
| 右上 ⚙︎ | 每日技巧提醒条数（0–3 条，9:30 / 13:00 / 20:30） |
| 表盘小组件 | 每 2 小时换一条技巧，点一下打开 App |

## 结构

```
watch/        Xcode 工程（xcodegen 生成，改 project.yml 后运行 xcodegen generate）
  App/          手表主程序：牌堆、本地通知、界面
  Shared/       卡片模型 + 技巧库 tips.json（App 和小组件共用）
  Widget/       表盘 / 智能叠放小组件
appstore/     上架资料：文案、审核备注、截图、ICP 豁免申请
docs/         GitHub Pages：技术支持页、隐私政策
server/       （已停用）早期的新闻抓取脚本，对应 workflow 已禁用
```

工程里有三个 target：
- `ClaudeTap`：iOS 外壳（com.zoey1108.claudetap），仅用于上架，用户看不到
- `ClaudeTapWatch`：手表 App（…​.watchkitapp）
- `ClaudeTapWidget`：小组件（…​.watchkitapp.widget）

## 改技巧

编辑 `watch/Shared/tips.json`。标题 ≤14 字，正文 ≤50 字，手表一屏才放得下。

## 开发调试

```bash
cd watch && xcodegen generate && open ClaudeTap.xcodeproj
```

选 `ClaudeTapWatch` scheme 和手表，点运行。

## 发版

1. 改 `project.yml` 里的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`，运行 `xcodegen generate`
2. 打包：`xcodebuild -project ClaudeTap.xcodeproj -scheme ClaudeTap -destination 'generic/platform=iOS' -configuration Release -archivePath build/AIYiDianTong.xcarchive -allowProvisioningUpdates archive`
3. `open build/AIYiDianTong.xcarchive` → Organizer 里 Distribute App → App Store Connect → Upload

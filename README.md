# MoneyMate · 离线优先的个人记账 App（iOS）

一个**数据全部留在本机**的记账 App：SwiftUI 编写，只用 Apple 官方框架，无第三方依赖、无账号、无广告、无埋点。目标是把"记账"这件事做到两步以内，并且不把财务数据交给任何服务器。

> 同系列还有 Flutter/Android 版本（同一套功能设计），仓库内暂未包含。

## 功能

**记账**
- 金额 / 收支 / 分类（可自定义，支持隐藏与图标）/ 商户 / 备注 / 标签 / 日期时间 / 多币种（6 种，录入时锁定汇率）/ 地点（自动定位 + 地图选点）
- 周期账单（每天 / 每周 / 每月）自动补录
- 收据、发票照片附件（本地保存，长边压缩到 1600）
- 撤销删除、复记（再记一笔）、商户 → 分类记忆、快捷模板

**账户与资产**
- 多账户：现金 / 储蓄卡 / 信用卡 / 电子钱包 / 投资 / 借出 / 借入；初始余额、卡号后四位、信用额度
- 信用卡：账单日、还款日、本期账单、额度使用率、免息期提示、多卡还款顺序
- 账户间转账、信用卡还款、余额对账（差额自动记「余额调整」）
- 净资产页：总资产 / 总负债 / 近 6 个月净值曲线

**分析**
- 支出趋势、分类占比、月度柱线、分类排行、预算进度
- 消费日历热力图、异常消费（对比近 3 个月）、现金流预测、订阅识别、同比、储蓄率
- 月度账单长图（可分享）、连续记账打卡、最贵一笔

**多账本 / 旅行账本**
- 任意创建账本，切换后全局统计只看该账本；删除账本会把账目并回「日常」，不丢数据
- 旅行账本可记起止日期

**提醒（全部本地通知）**
- 每日记账提醒、超预算提醒、信用卡还款日前 3 天 / 当天、账单日临近
- 可设大额消费阈值提醒

**数据与隐私**
- 全本地存储；iCloud 同步为可选（走你自己的 iCloud，键值存储）
- FaceID / 隐私锁、隐私模式（金额模糊，切后台自动盖住）
- 每次改动自动备份到 `Documents/Backups`（保留 7 份，可回滚）；JSON 导入导出；CSV 导出（带 BOM，Excel 直接打开）
- 共享账本：导出「共享包」给对方合并，按 uid 去重、以最后修改为准

**系统集成**
- 桌面小组件（含锁屏圆形/矩形/单行）、交互式「记一笔」按钮
- Siri / 快捷指令：记一笔、查本月支出
- 深链：`moneymate://add?amount=32&merchant=星巴克&category=餐饮`
- 相机拍小票自动填金额/商户、扫码带商户、剪贴板识别、分享/选中文字导入
- 高级搜索语法：`餐饮 >100 本月`、`标签:出差`、`100-500`、`近7天`；筛选可保存
- 操作日志（记录每次新增/修改/删除）

## 构建

需要 Xcode 26+（部署目标 iOS 26.0）与 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MoneyMate.xcodeproj -scheme MoneyMate -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

仓库自带 GitHub Actions 工作流（`.github/workflows/build-ipa.yml`）：推到 `main` 就自动构建未签名 IPA；若配置了证书相关 Secrets，则产出已签名 IPA。

**签名与安装**：未签名 IPA 需要自行签名后安装（免费 Apple ID 也可）。

**可选能力**（不配置也能正常使用）：
- App Groups `group.com.moneymate.app`：让桌面/锁屏小组件读到账本数据、支持交互式「记一笔」
- iCloud → Key-value storage：多设备同步

## 目录结构

```
MoneyMate/
  App/            入口
  Models/         数据模型与仓储（MoneyStore / Finance / SmartMemory）
  Services/       通知、导出、附件、共享账本、iCloud、小组件桥
  Shared/         App 与 Widget 共用
  Views/          全部界面（首页 / 明细 / 资产 / 统计 / 我的 + 各类卡片）
  AppIntents/     Siri / 快捷指令
MoneyMateWidget/  桌面与锁屏小组件
```

## 许可证

[MoneyMate 源码可见许可 v1.0](LICENSE) —— **源码公开、可自由阅读/学习/自用/修改，但禁止任何形式的商业使用与倒卖**（销售、收费分发、应用商店变现、并入闭源商业产品等）。

这不是 OSI 认可的开源许可，而是"源码可见（source-available）"许可：商业权利保留。需要商业授权请联系作者。

本项目未打包任何第三方库，全部使用 Apple 官方框架。

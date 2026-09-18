# MoneyMate · 记账，但数据只属于你

[![Build iOS IPA](https://github.com/zxl1828/money-mate-ios/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/zxl1828/money-mate-ios/actions/workflows/build-ipa.yml)
![Platform](https://img.shields.io/badge/iOS-26%2B-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License](https://img.shields.io/badge/license-source--available%20(non--commercial)-orange)

一个**完全离线**的 iOS 记账 App：不注册账号、不联网也能用、没有广告和埋点，你的每一笔账都只存在你自己的手机里。

用 SwiftUI 写成，只用 Apple 官方框架，**没有任何第三方依赖**。

> 如果你在找"记账软件里哪个不偷数据"——这个就是冲这个目标做的。

---

## 为什么值得一用

- **不需要账号**：打开就能记，没有注册、没有登录、没有手机号。
- **离线可用**：飞行模式下写账、看报表、拍小票识别全部正常，核心功能不依赖任何服务器。
- **没有广告**：不弹窗、不推荐理财产品、不做"记账换积分"。
- **数据你说了算**：随时导出 JSON / CSV，自带版本历史可以回滚到某个时间点。
- **顺手**：快捷模板点一下记一笔、复记一笔旧账、拍小票自动填金额、复制账单文本自动识别、Siri 一句话记账。

## 功能一览

**记账**
- 金额、收支、分类、商户、备注、标签、日期时间、多币种（6 种，录入时锁定汇率）、地点（自动定位 / 地图选点）
- 周期账单（每天 / 每周 / 每月）自动补录，收据与发票照片附件
- 快捷模板、复记（再记一笔）、撤销删除、商户 → 分类记忆
- 高级搜索：`餐饮 >100 本月`、`标签:出差`、`100-500`、`近7天`，常用条件可存成筛选
- 一笔账拆多分类；AA 分摊（把别人该给的那部分自动记成应收）

**账户与资产**
- 多账户：现金 / 储蓄卡 / 信用卡 / 电子钱包 / 投资 / 借出 / 借入，可设初始余额、卡号后四位、信用额度
- 信用卡：账单日、还款日、本期账单、额度使用率、免息期提示、多卡还款顺序
- 账户间转账、信用卡还款、余额对账（差额自动记成「余额调整」）
- 净资产页：总资产 / 总负债 / 近 6 个月净值曲线
- 借还台账：借出借入单独统计，一键结清

**分析与回顾**
- 支出趋势、分类占比、月度对比、分类排行、预算进度
- 消费日历热力图、异常消费提醒、现金流预测、订阅识别、同比、储蓄率
- 月度账单长图（可分享给家人）、连续记账天数、最贵一笔
- 目标储蓄（旅行基金之类，进度看得见）、分期付款管理、预算结转（上月没用完的额度滚到本月）

**多账本 / 旅行账本**
- 想分就分：建成"家庭""生意""2026 云南"都行，切换后统计只看当前账本
- 删除账本不会删账——会把它并回「日常」

**提醒**（全部是手机本地通知，不经过服务器）
- 每日记账提醒、超预算提醒、信用卡还款日前 3 天与当天、账单日临近、大额消费提醒

**隐私与数据安全**
- FaceID / 密码锁、隐私模式（金额模糊，切后台自动盖住）、防截屏（Android 版）
- 每次改动自动备份到本地（保留最近 7 份），可一键回滚
- 导出 JSON 备份 / 导入恢复 / 导出 CSV（带 BOM，Excel 双击就能打开）
- 共享账本：把账本导出成"共享包"发给对方合并，同一条以最后修改为准、不会重复入账

**与系统集成**
- 桌面小组件 + 锁屏小组件，小组件上直接点「记一笔」
- Siri / 快捷指令：记一笔、查本月支出
- 深链 `moneymate://add?amount=32&merchant=星巴克`，可以被其他自动化工具调用
- 拍小票自动识别金额商户、扫码带出商户、剪贴板识别、从其他 App 分享文本或图片进来

## 隐私：它是怎么做到"不偷数据"的

1. 全本地存储，没有自家服务器，也没有第三方分析 SDK。
2. 相机、相册、定位、通知权限都是**用的时候才申请**，拒绝授权也能正常记账。
3. 识别文字用的是 Apple 的 Vision，**在手机本地完成**，图片不上传。
4. iCloud 同步是可选项：开启后走你自己的 iCloud 空间，作者看不到。
5. 唯一的联网行为是拉取汇率（可选），失败就用离线汇率。

## 安装与使用

**普通用户**

仓库的 [Actions](https://github.com/zxl1828/money-mate-ios/actions) 每次提交都会自动构建一个**未签名 IPA**，下载后用你自己的方式签名安装即可（免费 Apple ID 也可以）。作者不提供已签名安装包，请勿从第三方渠道下载改过的版本。

**开发者自己构建**

需要 macOS + Xcode 26 或更新版本，以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MoneyMate.xcodeproj -scheme MoneyMate -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

想用 Xcode 直接跑：`xcodegen generate` 之后打开 `MoneyMate.xcodeproj`，选择你的开发者账号即可。

**可选能力**（不配置也能正常用）

| 能力 | 作用 | 不配置会怎样 |
|---|---|---|
| App Groups `group.com.moneymate.app` | 让小组件读到账本数据、支持小组件上「记一笔」 | 小组件显示引导，点按钮无反应 |
| iCloud → Key-value storage | 同账号多设备同步 | 只能靠 JSON 导入导出换设备 |

## 项目结构

```
MoneyMate/
  App/            入口
  Models/         数据模型与仓储（MoneyStore / Finance / SmartMemory）
  Services/       通知、导出、附件、共享账本、iCloud、小组件桥
  Shared/         App 与 Widget 共用
  Views/          全部界面（首页 / 明细 / 资产 / 统计 / 我的 + 各类卡片）
  AppIntents/     Siri 与快捷指令
MoneyMateWidget/  桌面与锁屏小组件
```

## 常见问题

**换手机会丢数据吗？**
不会。设置里可以导出 JSON 备份，新手机导入即可；开启 iCloud 同步也能自动带过去。App 每次改动还会在本地留 7 份自动备份。

**为什么不做银行自动同步？**
那需要把账号密码或授权交给第三方服务，和这个项目的目标冲突。这里的替代方案是：复制账单文本自动识别、拍小票识别、分享截图进来识别、导入微信/支付宝月度账单。

**支持 iPad / Apple Watch 吗？**
目前是 iPhone 优先（界面按竖屏设计）。iPad 可以装，但布局未针对大屏优化。Watch 版本还没有。

**为什么许可证不是 MIT？**
作者希望代码公开可读可用，但不希望被人拿去倒卖或包装成付费产品。详见下方许可证说明。

## 参与贡献

欢迎提交 Issue 反馈问题、提 PR 改进功能。提 PR 即表示你同意代码以本项目的许可证发布（非商业源码可见）。

由于项目遵循"零第三方依赖"和"纯本地"两条原则，以下类型的 PR 通常不会被合并：
- 引入第三方 SDK / 统计 / 广告
- 需要把用户数据上传到服务器的功能

## 许可证与商业授权

本项目使用 [MoneyMate 源码可见许可 v1.0](LICENSE)：

- ✅ 允许：个人学习、研究、自用、修改、分享（保留版权与许可声明）
- ❌ 禁止：销售、倒卖、租赁、收费分发、上架应用市场变现、去版权后改名发布、并入闭源商业产品

这不是 OSI 认可的开源许可，而是 **source-available**：源码公开，**商业权利保留**。需要商业授权请通过 Issues 联系作者。

## 免责声明

本软件用于个人记账。请自行做好数据备份；因误删、设备损坏等造成的数据丢失，作者不承担责任。

---

### English summary

**MoneyMate** is a fully offline personal finance app for iOS, written in SwiftUI with zero third-party dependencies. No account, no ads, no tracking — your data stays on your phone. Features include multi-account and credit-card tracking, net-worth charts, receipts OCR, local notifications, widgets, Siri shortcuts, multi-ledger (incl. trip ledger), backups with version history, and CSV/JSON export.

License: **source-available, non-commercial** — free to read, learn, use and modify; selling, reselling or paid distribution is not allowed without written permission.

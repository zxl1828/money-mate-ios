# MoneyMate — iOS 26 Liquid Glass

仅使用 Apple 官方 SwiftUI API，部署目标 **iOS 26.0+**，无 OCR、无第三方依赖。

核心实现：
- `glassEffect` 修饰符（`.regular` / `.clear` + `.tint` / `.interactive()`）
- `GlassEffectContainer` 合并多个玻璃形状，靠近自然融合
- `@Namespace` + `glassEffectID` 做形状间平滑过渡
- `glassEffectUnion` 做联合效果（底部导航、快捷操作）
- `.glassProminent` 按钮样式
- 明亮渐变背景 + 高通透玻璃，能清晰看到背景内容

## 你本地怎么跑（需要 Mac）

```bash
brew install xcodegen
xcodegen generate
open MoneyMate.xcodeproj
# 选 iPhone（iOS 26 模拟器）后 Run
```

## GitHub Actions 云端自动出 IPA（不需要 Mac）

1. 把整个 `MoneyMate_iOS` 目录推到你的 GitHub 仓库（`flutter` 等方式均可）。
2. 默认不填任何密钥：push 到 `main` 或手动触发 `workflow_dispatch`，Actions 会在 `macos-15` 上编译并把 **`MoneyMate-unsigned.ipa`** 作为构件上传，在 Actions 页面右侧 `Artifacts` 下载。
3. 需要安装到**真机**：在 GitHub 仓库 Settings → Secrets and variables → Actions 里添加：
   - `TEAM_ID`：Apple Developer Team ID
   - `EXPORT_METHOD`：`development` / `ad-hoc` / `app-store`
   - `CERT_P12_B64`：发布/开发证书 `.p12` 的 base64
   - `CERT_P12_PASSWORD`：`.p12` 密码
   - `PROVISION_PROFILE_B64`：包含你设备 UDID 的 `.mobileprovision` 的 base64
   再触发一次，就会输出 **`MoneyMate-signed.ipa`**。

### 一键脚本（推荐）

在你自己的电脑上（Windows PowerShell）：

```powershell
cd "MoneyMate_iOS"
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

首次运行会让你在浏览器登录一次 GitHub（`gh auth login`），之后脚本会自动：建私有仓库 → push → 等 Actions 编译 → 下载 IPA 到 `./release`。想推到已有仓库，就传 `-RepoUrl "https://github.com/你的用户名/仓库名.git"`。

## 签名说明（重要）

未签名的 `.ipa` 在未越狱的 iPhone 上**装不了**。要装真机，必须用上面 5 个密钥做签名；默认 GitHub 免费账号的签名证书和 Profile 都需要在 Apple Developer（或免费个人团队）里申请。

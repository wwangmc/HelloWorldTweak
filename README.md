# HelloWorld

Theos / Logos 插件，注入 SpringBoard，在重启（respring）完成后弹出 `Hello World` 弹窗。包含 GitHub Actions 云端编译配置。

包名：`com.example.helloworld`。目标进程：`SpringBoard`，注入范围见 `HelloWorld.plist`。

## 功能实现

`Tweak.xm` 的流程：

1. `%ctor` 在注入时注册 `UIApplicationDidFinishLaunchingNotification` 观察者，并记录 `[HelloWorld] Loaded` 日志。
2. 同时 `%hook SpringBoard` 的 `-applicationDidFinishLaunching:`，作为更贴近本进程时序的第二个触发入口。
3. 任一入口触发后延时 1 秒，取 `UIApplication` 的 key window，从 `rootViewController` 逐层取到最上层视图控制器。
4. 用 `UIAlertController` 弹出标题 `Hello World` 的弹窗，只有一个 `OK` 按钮。
5. 如果启动瞬间视图控制器还拿不到，按 1 秒间隔重试最多 8 次；另外在注入后 5 秒再兜底尝试一次（注入晚于启动通知时生效）。
6. `gHelloAlertShown` 保证单次 SpringBoard 生命周期内只弹一次，两个入口不会重复弹。

注意：弹窗是模态的，会盖在 SpringBoard 上直到点击 `OK`；这是预期行为，用于验证插件已生效。若在个别系统版本上 SpringBoard 的 root view controller 拒绝弹出，可把 `HelloTopViewController()` 换成自己创建的透明 `UIWindow` 来承载弹窗。

## 在 Windows 上使用 GitHub Actions 编译

1. 将生成项目放在 GitHub 仓库根目录，提交所有文件（包括 `.github/workflows/build.yml`）。
2. 默认向 `main` / `master` 推送或提交 PR 时触发编译；其他分支需修改 workflow 的 branches。
3. 也可在默认分支包含 workflow 后，从 **Actions → Build Theos packages → Run workflow** 手动触发。
4. 在成功运行的 **Artifacts** 下载 `HelloWorld-<模式>`，解压 ZIP 获取 `.deb`。构建日志为 `build-log-<模式>`，保留 14 天。

CI 启用的模式：rootfull, rootless, roothide。完整的模式参数对应如下：

| 模式 | make 参数 | 默认架构 | 最低部署目标 |
| --- | --- | --- | --- |
| rootfull（rootful） | `TYPE=0` | arm64 | iOS 13.0 |
| rootless | `TYPE=1` | arm64、arm64e | iOS 14.0 |
| RootHide | `TYPE=2` | arm64、arm64e | iOS 14.0 |

部署目标仅表示编译下限，实际可用性取决于越狱、注入器、设备和功能所用 API。
当前工具链不能生成适用于 iOS 12–13 的旧 arm64e ABI；rootfull 的 arm64 包不承诺支持这些系统上向 arm64e 系统进程注入。
workflow 只编译打包并上传 Artifacts。本项目尚未在 Actions 或 macOS 上实际构建验证，请以 CI 结果为准。

下载到 `.deb` 后，在 iOS 上用 Filza / Sileo / `dpkg -i` 安装对应模式的包，然后 respring 即可看到弹窗。安装模式必须与设备越狱形态匹配（rootless 设备装 `TYPE=1` 的包，RootHide 设备装 `TYPE=2` 的包）。

## 本地编译

在已安装 Xcode、RootHide Theos、GNU make、ldid、xz 和补丁版 iPhoneOS16.5 SDK 的 macOS 上：

```sh
export THEOS=/path/to/theos
gmake TYPE=1 clean
gmake TYPE=1 FINALPACKAGE=1 package
```

切换模式时先 clean，并保持两条命令的 TYPE 相同；默认本地 TYPE 为 `1`。
本地 Theos 环境需支持 `THEOS_PACKAGE_SCHEME=roothide` 才能打包 RootHide。

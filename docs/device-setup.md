# PICO 4 真机配置记录

最近检查日期：2026-11-16（Asia/Shanghai）；早期环境与实验室记录保留在后文。

## 2026-11-16：0.4.0 工程化重构

拆分纯规则、会话、输入适配、XR Rig、批量显示、关卡 / 外观资源、教程执行与本地存档。经典关卡保持已验收的内部视角和持续输入控制。训练关卡和 sunset 外观作为实际可加载的配置样例。源代码路径迁移到 `src/`、`content/` 与分层 `scenes/`；下方历史路径保留为当时记录。

本地验证：固定版本 gdformat / gdlint 和模块依赖检查通过；规则、输入映射、会话、内容 / 存档、场景集成共 376 项检查及独立手部回归通过。场景测试覆盖松手冻结、恢复、失焦、换关卡、换皮、非立方网格、六面墙接触，以及 512 节蛇仍为四个渲染节点。桌面实际画面已检查，HUD 和内部视角正常。另将 Git 暂存树导出到空目录，只恢复锁定校验和的厂商插件，未复制 `.godot` 或本机资源缓存；全部导入、测试和启动检查再次通过。

`./tools/dev.sh build` 通过，APK 为 `0.4.0 / versionCode 7`，SHA-256 `d634459e0c7fd503117d560b6bf29e19b55b322d88448512fbe666bedef33bec`；签名、版本、ARM64、PICO loader、权限、手部声明及测试 / 工具资源排除检查通过。导出先生成候选 APK，校验成功才替换正式产物。

CPU 压力对比见 `docs/performance.md`。这是桌面 headless CPU 数据，未测设备 GPU、温度和长期帧率。

用户连接 PICO 4 后，0.4.0 已覆盖安装并启动；应用查询确认 `versionName: 0.4.0`、`versionCode: 7`、`running: true`、PID `9098`。23:34:33 的日志确认 Godot 4.4.1、Pico OpenXR 3.0.1、Adreno 650 / OpenGL ES 3.2 初始化并进入房间场景；23:34:37 双手均为 `TRACKED`、`valid_joints=26`、`tips_tracked=true`，追踪来源保留运行时原值 `unknown`。23:34:43 应用失去焦点后双手进入 `PAUSED`。本次 Godot 采样未见脚本错误。

用户明确选择“先不试玩，稍后再试”。因此本轮真机证据限于安装、启动和追踪日志；0.4.0 的立体画面、摇杆手感、暂停恢复和完整游戏流程尚待用户复测，不将此前 0.3.x 的确认当作新版验收，也不宣称完成持续性能测试。

本轮沿用当前宿主会话的 CLI 环境验证，没有安装 / 更新 CLI、模拟器或 Kotlin SDK。OpenXR Vendors 从同一 4.3.1 官方包按锁文件 SHA 恢复，未升级版本。证据：`builds/check-engineering.log`、`builds/check-clean-checkout.log`、`builds/validation.log`、`builds/test-results.xml`、`builds/lint-final.log`、`builds/build-engineering.log`、`builds/apk-verification.json`、`builds/performance.json`、`builds/snake-game-preview.png`、`builds/pico-engineering-installed.json`、`builds/pico-engineering-runtime.log`。

## 2026-11-15：0.3.3 持续输入才移动

按用户要求取消自动行进：所有当前方向输入回中 / 松开时，移动时钟和蛇身插值立即冻结；重新保持有效输入后从停下的位置继续。右杆保留头部水平朝向映射，左杆仍以前推 / 后拉控制上下且优先于右杆；左杆释放后只有右杆仍激活才继续水平移动。右手 A/B 和键盘 WASD/方向键、Q/E 改为持续状态输入，释放即停。开始 / 暂停 / 重开仍为点按命令。倒计时结束后无方向输入会保持静止；无效掉头输入也停止，不继续沿旧方向跑。

移动输入统一进入 `snake_game.gd::_apply_move_intent()`：有效方向允许移动，`Vector3i.ZERO` 立即停止并清空待执行方向。暂停、重开和失焦清除输入；恢复时需先回中 / 释放再激活。键盘分别处理按下和抬起，避免失去 key-up 后卡住。移动仍基于网格，半格处停止后继续完成当前格间插值，转弯在格点执行。碰撞结束后的短撞击反馈仍正常播放。

未来姿态、捏合、声音游戏模式也必须使用上述持续状态约定；本轮只修改已存在的游戏方向输入，没有把输入实验室的诊断开关或捏合计数改成游戏关卡。

验证：`./tools/dev.sh check` 通过 39 项游戏、126 项转向、103 项墙面、31 项持续输入检查及手部回归。新检查覆盖倒计时后静止、半格松手冻结、再次输入继续、回中转头不移动、反向停止、左右杆切换、A/B 保持与释放、键盘 key-up、失焦清理、恢复回中，以及边界静止不会自动撞墙。以上为合成输入。APK 导出、签名、ARM64、PICO loader 和权限检查通过；覆盖安装返回 `Success`，应用查询确认 `0.3.3 / versionCode 6`、`running: true`，PID `8019`。日志确认 Pico OpenXR 3.0.1 初始化，当前采样未见脚本错误。23:05 实玩日志已记录多次水平 / 上下有效输入及回中后的零输入状态，且有食物增长事件；用户随后在头显复测并反馈“符合预期，松开就停”，本轮摇杆持续输入与回中立即停止的真机复测通过。键盘与 A/B 的按住 / 释放逻辑通过自动检查，未单独取得用户逐项硬件验收。

证据：`builds/check-hold.log`、`builds/build-hold.log`、`builds/pico-hold-installed.json`、`builds/pico-hold-runtime.log`、`builds/hold-verification.json`。沿用同一宿主会话已完成的环境 doctor，工具与工作区未变化。

## 2026-11-15：0.3.2 墙角反馈排查

用户报告蛇头沿墙平行行进也会结束。检查发现网格规则原本只在蛇头下一格越界时判定 `WALL`，没有以身体贴墙或距离阈值结束游戏。六面墙的切向行进、八个角的向内行进，以及身体沿墙角分布均可通过规则检查。墙角处沿一面墙平行，仍可能垂直撞向另一面墙。

确认并复现了显示缺陷：`step()` 已接受朝墙的转向后，因下一格越界而返回失败；游戏只在成功移动时同步画面，导致蛇头仍指向上一次沿墙的方向。新回归在旧代码上出现 93 项检查中的 1 项失败，正是失败后蛇头朝向未更新。此缺陷可以造成“看起来沿墙行进却撞墙”的观感，但尚不能断言它解释了用户每一次实玩情况。

0.3.2 在失败步也同步蛇头朝向，撞墙时显示从最后有效格到对应墙面的短距离撞击，鼻尖变红并停在实际墙面；逻辑格保持有效。日志增加蛇头格、实际方向和尝试进入的格，便于真机复测时区分具体墙面。摇杆映射与网格碰撞规则保持原有行为。

验证：`./tools/dev.sh check` 通过 39 项游戏、126 项转向、103 项墙面专项检查及既有手部回归；墙面检查还覆盖六个接触平面、撞击显示和重开清理。未复现规则层的沿墙平行移动误判。APK 导出、签名与内容检查通过，覆盖安装返回 `Success`；应用查询确认 `0.3.2 / versionCode 5`、`running: true`，PID `8018`。启动日志确认 OpenXR 初始化，采样未见脚本错误。用户随后在头显复测并反馈“现在正常，能看清撞击方向”，本轮沿墙/墙角体验与撞击显示复测通过。此结论依据用户实际反馈；持续性能与长时间空间舒适度未专项验收。

证据：`builds/check-walls-before.log`、`builds/check-walls.log`、`builds/build-walls.log`、`builds/pico-walls-installed.json`、`builds/pico-walls-runtime.log`、`builds/walls-verification.json`。本轮沿用同一宿主会话已完成的环境 doctor，工具与工作区未变化，不重复安装或更新。

## 2026-11-15：0.3.1 视线相对摇杆与左杆上下

针对用户实玩反馈调整控制：右杆不再只在首次拨动时取方向，而是在推住期间持续使用当前头部水平朝向。先旋转完整二维摇杆向量，再选择最近网格方向，避免先量化摇杆、再量化世界方向造成偏差。对斜向边界增加约 5° 迟滞，抬头/低头和歪头不改变水平朝向，接近直视上下时沿用最后有效朝向。头部姿态来自 `XRCamera3D.global_basis`（[Godot 4.4 官方说明](https://docs.godotengine.org/en/4.4/classes/class_xrcamera3d.html)）。

左杆前推上升、后拉下降，左右分量忽略；两杆同时激活时优先执行上下指令，左杆松开后恢复右杆水平指令。每帧的新意图替换尚未执行的方向，避免累积旧转向。摇杆回中后蛇继续行进，单纯转头不控制蛇；暂停清除意图，继续或重开后要求先回中再操作。仍为六方向网格规则，禁止直接掉头。右手 A / B 保留为两杆回中时的上下快捷键。

验证范围：

- `./tools/dev.sh check`：39 项游戏检查、126 项转向专项检查、既有手部回归、导入与无界面场景运行全部通过。专项覆盖 360° 朝向、斜向摇杆、持续转头、俯仰/歪头、竖直凝视回退、房间旋转、左右杆优先级、暂停回中和待执行方向替换。以上使用合成输入，不代表物理轴向与实际手感已验收。
- `./tools/dev.sh build`：APK 导出与签名、ARM64、PICO loader、权限和手部声明检查通过，版本 `0.3.1 / versionCode 4`。
- 对已授权的 PICO 4 执行覆盖安装并启动，CLI 返回 `Success`；应用查询确认 `versionName: 0.3.1`、`versionCode: 4`、`running: true`，本次 PID 为 `8017`。
- 本次 Godot 日志确认 Pico OpenXR 3.0.1 / Adreno 初始化并加载游戏场景，采样未见脚本错误。22:35 实玩日志记录了不同头部朝向下的水平输入、左杆上升/下降输入，以及吃食物、撞墙结束和重开；用户随后明确反馈“左右摇杆都符合预期”，本轮头部朝向映射与左杆上下控制真机复测通过。持续性能与长时间空间舒适度尚未专项验收。

本轮根 doctor 返回 `PARTIAL`，无阻塞错误，概览原值如下：

| 项目 | Doctor 概览 |
| --- | --- |
| CLI | `0.6.1 (public)` |
| Plugin | `pico-spatial-agentic-tools@0.6.1` |
| SDK | `{status: no-project, version: null}` |
| PICO development knowledge | `6.1` |
| Emulator | `null` |
| Editor | `null` |

当前 shell 的 PATH 未包含已有 CLI，调用时临时加入 `/Users/xuanyuwu/.nvm/versions/node/v22.22.0/bin`，并显式指定现有 Android SDK 的 `ADB_PATH`。Node v22.22.0 / npm 10.9.4。未修改全局 shell、安装或更新工具，也不需要重启宿主。可选性能依赖、未导出的 `PICO_HOME`、插件远程新鲜度与 CLI 更新缓存为非阻塞告警；本项目使用 Godot，不进行 Kotlin Spatial SDK 对齐。

证据：`builds/check-steering.log`、`builds/build-steering.log`、`builds/apk-verification.json`、`builds/pico-steering-installed.json`、`builds/pico-steering-runtime.log`、`builds/steering-verification.json`、`builds/pico-doctor-20261115.json`。

## 2026-11-10：0.3.0 空间内部游戏

默认场景已改为 `scenes/snake_game.tscn`。玩家位于约 6.4 × 4 × 6.4 米房间中央，蛇在周围的 8 × 8 × 8 网格中移动。头显姿态由 OpenXR 驱动，游戏不推动或旋转玩家相机；场景首次获得焦点时按玩家的位置与朝向布置。原输入实验室保留为独立场景。

已实现：六方向转向、阻止掉头、食物、增长、计分、墙体/自身碰撞、满格获胜、3 秒准备倒计时、暂停继续、重开、失去焦点自动暂停，以及连续蛇身插值显示。键盘与手柄分别映射到同一套纯规则。

验证范围：

- `./tools/dev.sh check`：39 项游戏检查及已有手部回归通过。覆盖规则、尾格腾空、满格食物生成、转向队列、视线相对输入、摇杆回中、倒计时、暂停、完整失败流程和重开连接。检查脚本额外识别 Godot 的错误日志，避免引擎以退出码 0 隐藏脚本错误。
- `./tools/dev.sh screenshot`：桌面内部视角截图已检查，文件为 `builds/snake-game-preview.png`。这是桌面画面，不是头显截图。
- `./tools/dev.sh build`：APK 导出、签名、架构、权限与运行库检查通过。输出为 `builds/spatial-snake.apk`，0.3.0 / versionCode 3。
- PICO CLI 安装返回 `Success`，应用查询确认新版和存活进程；日志确认 Pico OpenXR / Adreno 初始化。
- 本轮最终检查时，Android activity 为 `state=STOPPED`、`sleeping=true`。头显处于休眠，尚未确认游戏场景真机画面、物理摇杆轴向、完整一局与空间舒适度。已向用户请求戴上头显试玩，不将历史实验室结果当作新玩法验收。

XR 场景结构依据 [Godot 4.4 XR 设置说明](https://docs.godotengine.org/en/4.4/tutorials/xr/setting_up_xr.html)。游戏仍需要手柄输入；裸手骨架保留显示，但姿态、手势、语音玩法属于后续阶段。

本轮 CLI 环境检查返回 `PARTIAL`，无阻塞错误；未执行工具安装或更新，也不需要重启宿主。概览原值：CLI `0.6.1 (public)`；Plugin `pico-spatial-agentic-tools@0.6.1`；SDK `{status: no-project, version: null}`；PICO development knowledge `6.1`；Emulator `null`；Editor `null`。Node v22.22.0 / npm 10.9.4，CLI 路径与下方历史记录相同，版本检查称 0.6.1 已为最新版。性能工具依赖和插件远程新鲜度仍为非阻塞告警。本工程是 Godot，不进行 Kotlin Spatial SDK 对齐；本轮未使用知识库 MCP 或 Spatial Editor。

证据：`builds/check-game.log`、`builds/build-game.log`、`builds/pico-game-installed.json`、`builds/pico-game-runtime.log`、`builds/game-verification.json`、`builds/pico-doctor-20261110.json`。以下为 0.1/0.2 输入实验室的历史记录。

## 已验证

- USB 调试已授权，连接目标是真实 PICO 硬件。
- 厂商 `Pico`，型号 `A8110`，设备标识 `PICOA8110`，系统版本 `5.13.7`，Android 10 / API 29 / ARM64。
- 已安装 `com.xuanyu.spatialsnake`，版本 0.1.0 / versionCode 1，并成功启动 `com.godot.game.GodotApp`。
- Godot 4.4.1 初始化 Pico OpenXR 3.0.1，使用 Adreno 650 / OpenGL ES 3.2。
- 运行时绑定 `/interaction_profiles/bytedance/pico4_controller`，进入 `XR_SESSION_STATE_FOCUSED`；启动后的短时日志采样显示 72 FPS。
- 用户确认立体画面正常，能随转头观察棋盘。
- 用户确认手柄按键正常；麦克风修复后复测通过，面板 Level 随声音变化。日志同时确认录音授权成功、采集启动并收到非零音频帧。
- 部署脚本已修正设备识别：PICO 4 的型号值是 `A8110`，使用厂商字段判断。

## 输入验证边界

输入实验室目前只显示状态和参考模型，尚未实现贪吃蛇规则。

- 手柄按键：用户确认正常；日志记录右手 A 触发姿态校准、左手 X 触发录音授权，以及扳机事件。未逐项验收所有按键与轴。
- 麦克风：首次测试发现授权回调在 Android 线程里操作场景树，导致采集节点未加入场景、没有声音数据。已将权限信号改为 `CONNECT_DEFERRED`，重新构建并部署；重置本应用录音权限后，用户再次授权并确认 Level 随声音变化。11:59:14 日志记录授权成功和采集启动，11:59:15 收到非零音频帧；修复版 Godot 日志未再出现此前的场景树线程错误。当前只验证声音电平，不包含语音识别。
- 裸手追踪与捏合：0.2.0 真机复测通过。首次收不到关节数据时，系统的手势识别尚未开启；用户开启后反馈正常，启用标志变为 `1`。应用日志确认左右手各 26 个有效关节、双指正在追踪，记录左手 12 次、右手 9 次捏合及松开事件；应用暂停时也正确取消了正在进行的捏合。
- 空间截图：本机固件的 `screencap` 拒绝 `--spatial`，报 `invalid option`。没有可用的 CLI 空间截图，不将失败输出当作视觉证据。

权限回调修复依据：[Godot 4.4 延迟信号连接](https://docs.godotengine.org/en/4.4/classes/class_object.html#enum-object-connectflags)和[场景树线程安全规则](https://docs.godotengine.org/en/4.4/tutorials/performance/thread_safe_apis.html)。音频仅在本地计算电平；诊断日志记录启动状态和首次非零采样，不保存语音。

## 裸手输入实现（0.2.0 / versionCode 2）

- `scripts/hand_input.gd` 读取真实 `XRHandTracker` 数据，用每手两个 MultiMesh 绘制关节点与骨骼，减少绘制调用。手掌通过 `XRNode3D` 的默认姿态定位，指骨采用相对手掌坐标。
- `scripts/pinch_detector.gd` 实现捏合状态：25 mm 内持续 80 ms 激活，40 mm 松开；跟踪丢失、无效指尖或应用失去焦点时取消，恢复后先张开才能再次激活。识别为手柄推算的数据不会触发裸手捏合。
- 捏合时指尖变金色、每手计数增加；棋盘金色方块随左/右手捏合变为青色/蓝色。显示有效关节数、数据来源、指尖距离及状态。
- `./tools/dev.sh check` 已通过导入、合成数据回归测试和场景运行检查；桌面预览已检查面板排版。合成数据只验证逻辑，不当作硬件证据。
- `./tools/dev.sh build` 已通过 APK 签名、架构、运行库和权限检查；PICO CLI 安装返回 Success，应用查询确认 0.2.0 / versionCode 2 正在运行。
- 启动日志确认左右手诊断节点和 Pico OpenXR 初始化成功，采样中没有 Godot 脚本错误。当前实测状态见 `builds/hand-verification.json`。
- 首次真机排查：APK manifest 的 `handtracking=1` 与 OpenXR Vendors 4.3.1 导出实现一致，左右原生手追踪器创建成功，但系统手势识别未开启。用户在系统设置中开启后，同一个 0.2.0 APK 收到真实关节数据并检测到双手捏合；无需修改代码。系统开关只做只读检查，没有绕过系统引导写入设置。
- 复测日志时间为 12:28:27–12:28:57：左右手均为 `TRACKED`、`valid_joints=26`、`tips_tracked=true`；来源枚举为 `unknown`，保留运行时原值。复测 Godot 日志没有脚本错误。骨架视觉依据用户开启后的正常反馈，没有获得空间截图；未单独验收全部遮挡情况或长时间性能。

## CLI 环境检查

根 doctor 结果为 `PARTIAL`，没有阻塞本次部署的错误。以下保留其版本概览值：

| 项目 | Doctor 概览 |
| --- | --- |
| CLI | `0.6.1 (public)` |
| Plugin | `pico-spatial-agentic-tools@0.6.1` |
| SDK | `status: no-project, version: null` |
| PICO development knowledge | `6.1` |
| Emulator | `null` / 未安装 |
| Editor | `null` / 未安装 |

这里的 SDK 指 Kotlin Spatial SDK；本项目使用 Godot，所以不进行 Spatial SDK 与知识库版本对齐，也不需要 Spatial Editor 或模拟器。

Node 为 v22.22.0、npm 为 10.9.4；CLI 位于 `/Users/xuanyuwu/.nvm/versions/node/v22.22.0/bin/pico-cli`。`pico-cli update --check --format json` 确认当前即最新版，没有执行更新。CLI 提供 doctor、setup、plugin、knowledge 和设备命令；本次检查未更改插件或 MCP 配置，无需重启。

非阻塞告警：性能分析工具依赖未齐备（需要时执行 doctor 给出的 `pico-cli perf doctor install --all`）；插件远程 Git 查询未能确认更新状态（`PLUGIN_UPDATE_UNKNOWN`），当前本地插件资源检查通过，保留原配置。

## 执行动作与证据

通过 `pico-cli device list/info` 选择唯一连接的真实设备，随后针对该设备明确传入 `--device`，执行：

```text
pico-cli app install builds/spatial-snake-input-lab.apk --replace --device <已选设备>
pico-cli app launch com.xuanyu.spatialsnake --activity com.godot.game.GodotApp --device <已选设备>
```

安装返回 `Success`，应用查询返回 `running: true`。CLI 调用显式指定 `ADB_PATH` 为已安装的 Android SDK platform-tools 中的 adb。

完整机器记录保存在本地忽略目录：

- `builds/device-verification.json`：真机验证范围。
- `builds/pico-input-check.log`：Godot / OpenXR 启动与输入日志。
- `builds/pico-microphone-before-fix.log`：首次录音授权的线程错误证据。
- `builds/pico-microphone-retest.log`：修复后首次授权和音频采集证据。
- `builds/pico-app-warnings.log`：运行时会话状态、启动帧率和系统告警。
- `builds/pico-installed-app.json`：安装版本和运行状态。
- `builds/pico-doctor.json`：环境检查原始结果。
- `builds/hand-verification.json`：0.2.0 裸手功能的独立验证记录。
- `builds/pico-hands-runtime.log`、`builds/pico-hands-installed-app.json`：0.2.0 真机日志与版本信息。
- `builds/pico-hands-verified.log`：开启系统手势识别后的 26 关节与双手捏合复测证据。
- `builds/check-hands.log`、`builds/build-hands.log`：手部回归测试和构建结果。

后续使用 `./tools/dev.sh build` 构建，再用 `./tools/dev.sh deploy` 安装并启动；多设备时显式提供序列号。

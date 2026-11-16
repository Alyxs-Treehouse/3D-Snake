# Spatial Snake

Godot **4.4.1 + GDScript + OpenXR**，面向 PICO 4 一体机的空间贪吃蛇。当前版本 **0.4.0**：玩家站在游戏房间内部；右杆按头部水平朝向控制，左杆控制上下，**保持方向才移动，释放立即停止**。

## 开始开发

需要 Godot 4.4.1、Python 3.11+。当前开发脚本支持 macOS / Linux；Android 构建另需对应 Godot 导出模板、JDK 17 和 Android SDK。

```bash
python3 tools/bootstrap.py                 # 恢复锁定版本的 OpenXR Vendors，并验证 SHA-256
python3 -m venv .cache/quality
.cache/quality/bin/python -m pip install -r requirements-dev.txt
./tools/dev.sh lint                       # 格式、静态规则、模块依赖边界
./tools/dev.sh check                      # 单元、场景集成与启动检查
./tools/dev.sh editor
./tools/dev.sh preview
./tools/dev.sh preview --level=training    # 示例关卡：教程 + 吃到三个食物通关
```

`SNAKE_GODOT_BIN` 可指定引擎路径；否则寻找 PATH 中的 `godot` / `godot4`，再使用 macOS 的 `/Applications/Godot.app`。Linux CI 的官方引擎可用 `python3 tools/bootstrap.py --linux-engine` 恢复，路径见命令输出。引擎版本和第三方资源由 `.godot-version`、`dependencies.lock.json` 锁定。

## 工程组织

```text
src/
  core/           纯网格规则、碰撞、食物、机制扩展
  gameplay/       会话状态、移动时钟、组合根与公共 API
  input/          当前方向输入接口、键盘/手柄适配器、映射与捏合
  platform/xr/    头显、手柄、追踪和焦点生命周期
  presentation/   房间、蛇的批量渲染、HUD
  content/        关卡、外观、内容目录的 Resource 类型与验证
  tutorial/       教程定义、步骤和事件驱动执行器
  services/       本地进度与设置存储
  diagnostics/    独立输入实验室
content/          可在 Godot Inspector 编辑的关卡、教程、外观 .tres
scenes/           游戏、玩家 Rig、房间和诊断场景
tests/           单元、场景集成和 CPU 压力测试
tools/           依赖恢复、校验、Android 构建与部署
```

主场景是 `scenes/game/game.tscn`。`SnakeGame` 负责装配，`GameSession` 负责游戏流程，`SnakeModel` 负责纯规则。硬件、教程和显示通过明确接口与会话信号连接；没有全局事件总线或服务定位器。

详细约定与示例：

- [架构和公共 API](docs/architecture.md)
- [新增关卡、机制、输入、教程与外观](docs/extending.md)
- [性能预算、测量方法与限制](docs/performance.md)
- [开发与 Git 工作流](CONTRIBUTING.md)
- [真机验证记录](docs/device-setup.md)

## 操作

| 动作 | 键盘 / 鼠标 | PICO 手柄 |
| --- | --- | --- |
| 开始 / 暂停 / 继续 | 空格或 P | 左手 X |
| 重开 | R | 左手 Y |
| 水平移动，按住 | WASD / 方向键 | 右摇杆，按当前头部水平朝向映射 |
| 上升 / 下降，按住 | Q / E | 左摇杆前推 / 后拉；两杆中立时也可按住右手 A / B |
| 停止 | 释放方向键 | 所有方向输入回中 / 松开 |
| 观察 | 鼠标左键拖动 | 自然转头 |
| 重置房间朝向 | C（同时暂停） | 系统重置视角（同时暂停） |

两杆同时输入时左杆上下优先。松开左杆后，只有右杆仍推住才继续水平移动。释放会冻结插值进度，再次输入从原位置继续；转弯在格点执行。禁止直接掉头，反向输入会停住。单纯转头不会启动移动。继续或重开后，摇杆和 A/B 需先回中 / 释放再激活。

经典关卡为 8 × 8 × 8 格、6.4 × 4 × 6.4 米，保持输入时每 0.75 秒前进一格。吃食物增长并加分，撞墙或自身结束，填满空间获胜。沿墙平行移动允许，只有蛇头下一格越过某个墙面才算撞墙。训练关卡演示独立教程和食物目标机制。最高分、教程完成状态和外观选择保存在 `user://profile.json`，写入采用临时文件替换并保留备份。

## Android 与 PICO 4

沿用已验证的 Godot 4.4.1 导出模板、OpenXR Vendors 4.3.1、JDK 17、Android API / Build Tools 34、ARM64 与 PICO loader。包名 `com.xuanyu.spatialsnake`。

```bash
./tools/dev.sh prepare       # 恢复 Android 模板并配置本机 Godot 的 JDK / SDK 路径
./tools/dev.sh build         # 导出、检查签名/版本/架构/权限，成功后替换正式 APK
./tools/dev.sh devices
./tools/dev.sh deploy SERIAL # USB 已授权的真实 PICO 设备
./tools/dev.sh lab           # 独立头显、IMU、声音、裸手诊断
```

使用 `SNAKE_ANDROID_SDK`、`SNAKE_JAVA_HOME`、`SNAKE_GODOT_TEMPLATES` 覆盖本机路径。macOS 默认使用用户目录中的 Android SDK 与 Microsoft JDK 17，模板默认位于 Godot 导出模板目录。首次构建需要联网下载 Gradle / Maven 依赖。

APK 输出为 `builds/spatial-snake.apk`。构建先写临时 APK，通过版本、签名、ARM64、OpenXR loader、录音/手部声明及开发脚本排除检查后才替换上一次有效产物。调试签名与生成文件不提交 Git。

## 验证范围

0.3.1 的头部相对映射、0.3.2 的墙角显示、0.3.3 的保持输入 / 松手停止均已由用户在 PICO 4 确认。0.4.0 重构后的测试、桌面预览、APK 和真机验证分别记入 [设备记录](docs/device-setup.md)，不把历史验收自动沿用为新版验收。

```bash
./tools/dev.sh benchmark     # 3 / 64 / 256 / 512 节蛇的 CPU 提交压力记录
```

GitHub Actions 在 push / PR 时运行固定版本的格式、边界、自动测试和 CPU 基准，保存日志与 JUnit 报告。头显 GPU、温度、长期帧率需要独立真机测量；姿态、裸手、声音的正式游戏关卡仍待开发，但输入扩展必须遵守“持续有效状态移动，中立停止”的统一接口。

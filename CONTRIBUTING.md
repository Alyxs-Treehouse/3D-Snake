# 开发约定

## 分支与提交

- `main` 保持可构建；功能分支使用 `codex/<topic>`，团队也可采用统一的 `feature/` / `fix/` 前缀。
- 小而完整的提交；将行为变更、内容资源、必要测试与文档一起提交。
- 合并前运行格式 / 依赖边界检查、自动回归；涉及 XR 或渲染时记录 APK 与设备验证范围。
- 发布使用版本标签。版本号在 `export_presets.cfg`，Android versionCode 必须递增。
- 不提交 `.godot`、`.cache`、`builds`、下载的插件、Gradle 模板/缓存、签名密钥和 `.env`。
- `v0.3.3` 保留重构前用户确认过的代码基线；该标签的插件按锁文件/官方发布包恢复。

## 日常检查

```bash
.cache/quality/bin/gdformat src tests tools/configure_editor.gd
./tools/dev.sh lint
./tools/dev.sh check
./tools/dev.sh benchmark
./tools/dev.sh build        # 变更涉及 Android / XR / 游戏行为时
```

`builds/validation.log` 保存完整日志，`builds/test-results.xml` 为 JUnit 报告。测试进程超时视为失败，脚本错误即使引擎退出码为 0 也视为失败。每项测试使用独立进程；存档测试使用独立路径并清理，场景集成测试禁用正式存档。

格式由固定版本 gdtoolkit 管理，不手工争论空格与换行。代码命名使用 snake_case，公共脚本使用 `class_name` 和显式类型。`src/core`、`GameSession` 不接触场景和平台；依赖边界检查进入 CI。

## 依赖和干净检出

Godot 版本在 `.godot-version`；OpenXR Vendors 与 Linux CI 引擎的下载地址和 SHA 校验在 `dependencies.lock.json`。开发 Python 依赖在 `requirements-dev.txt` 固定版本。

升级时先更新锁文件及官方校验和，再执行干净检出检查、Android 构建与真机回归。不要直接修改下载的 `addons/godotopenxrvendors`；需要补丁时应引入可审查的补丁步骤及测试。下载的厂商包包含其各自许可证，来源见 [第三方依赖](THIRD_PARTY.md)。

## 性能变更

帧循环不创建 Mesh / Material / 节点，不写存档，不扫描所有空闲格。新增机制需说明计算发生于每帧、每步还是事件时，并在长蛇场景记录 CPU / 设备数据。不能将桌面 headless 基准写成 PICO 帧率结论。

本项目尚未指定对自有代码的开源许可证；公开仓库不等于允许添加未经确认的第三方授权声明。

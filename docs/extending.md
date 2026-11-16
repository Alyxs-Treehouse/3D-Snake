# 扩展开发

新增机制与内容应优先添加一个独立实现及资源配置，避免在 `SnakeGame._process()` 中不断增加模式判断。

## 新关卡

1. 在编辑器创建 `SnakeLevel` Resource，存入 `content/levels/`。
2. 设置稳定且唯一的 `id`、网格尺寸、格子物理尺寸、初始蛇身/方向、食物、步长和障碍。
3. 按需引用机制资源、教程资源。
4. 将资源加入 `content/catalog.tres` 的 `levels`。
5. 调用 `game.select_level(id)`，或 `./tools/dev.sh preview --level=id`。

`classic.tres` 与 `training.tres` 是真实运行样例。测试还覆盖非立方尺寸，房间、坐标、容量随配置变化；不需要编辑渲染常量。

## 新机制

继承 `SnakeRule`，实现需要的钩子，作为关卡 `rules` 的一项。`FoodGoalRule` 展示独立目标：吃到指定数量后通关。

```gdscript
class_name BonusFoodRule
extends SnakeRule
@export var multiplier := 2

func food_points(_model: RefCounted, base_points: int) -> int:
    return base_points * multiplier
```

可用钩子：`validate()`、`reset(model)`、`collision_reason(cell, model)`、`food_points(model, base_points)`、`after_step(model, ate_food)`、`has_won(model)`。机制按资源列表顺序执行，得分按顺序组合，任一机制达成目标即可通关。每局复制机制资源，不能用静态变量共享回合状态。机制回调不直接编辑 `body` 或空闲格索引；若要实现传送、绕墙或多蛇等改变拓扑的规则，应明确扩展模型的移动事务与测试，而不是从回调改私有数据。

## 新输入方式

继承 `IntentSource`，实现 `sample(viewer_basis, arena_basis)`、`reset()`，必要时实现 `available()` 与 `handle_event()`。通过 `game.set_input_source(source)` 替换；设备和关卡选择 UI 以后只负责调用这个入口。

输入状态约定：

- 有效且持续的动作返回一个房间局部六方向向量。
- 中立、释放、静音、丢失数据返回 `Vector3i.ZERO`。
- `reset()` 清空状态；恢复时要求先中立，再重新激活。
- 不在适配器里移动蛇、操作碰撞或计分。
- 无硬件时用 `sample_values()` 这类值输入入口测试映射；硬件追踪另行验收。

`ControllerIntentSource` 和 `KeyboardIntentSource` 是现成样例。IMU、捏合、声音游戏模式还未实现；输入实验室已有底层诊断。接入这些模式时必须延续“保持才动，释放就停”，不能只发送一次方向事件后依赖自动行进。

## 新手教程

创建 `TutorialDefinition`，按顺序添加 `TutorialStep`：稳定 id、提示文本、期望事件和次数，挂到关卡的 `tutorial` 属性。`TutorialRunner` 消费会话的语义事件；完成 id 存入本地进度，之后同一教程自动跳过。若需要显式重放，可调用 `game.tutorial.start(definition)`。

现有提示仅作为基本教程呈现示例。以后添加箭头、目标高亮、配音等展示，监听教程 `changed` 信号；不要把这些效果放入纯规则层。新增事件类型时同时修改验证、事件发送点和顺序回归测试。

## 新外观

创建 `SnakeSkin`，设置颜色、半径及可选 head/body/link Mesh，加入内容目录，然后调用 `game.select_skin(id)`。外观不改变逻辑碰撞格；素材应在约定的半径内，连接段沿本地 Y 轴、长度为 1，动画负责缩放。

身体和连接段分别使用 MultiMesh；新外观应共享网格与材质，避免每节添加节点、灯光或独立材质。需要独立动画骨骼的外观应作为新的 Renderer 实现评估预算，而不是破坏当前批处理。示例 `sunset.tres` 只改颜色。

## 验证要求

至少覆盖新增行为的成功、无效输入、暂停 / 恢复和重开；修改输入要覆盖释放停止与失追踪。对照已有 `tests/unit` 和 `tests/integration` 的公开接口测试，避免将场景私有字段当成新功能接口。

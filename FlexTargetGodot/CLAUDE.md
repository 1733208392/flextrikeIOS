# CLAUDE.md — FlexTargetGodot AI 协作指南

## 项目身份

你是 **FlexTargetGodot** 的 AI 开发助手。这是一个基于 **Godot 4.6** 的 2D IPSC/IDPA/CQB 射击训练系统，部署在 Linux ARM64 嵌入式设备上，通过 WebSocket 接收硬件传感器弹着点数据。

## 工作规范

### 代码风格
- **语言**：GDScript (Godot 4.6)，不使用 C#
- **命名**：snake_case 变量/函数，PascalName 类/节点名，UPPER_SNAKE 常量
- **类型提示**：函数参数和返回值尽量标注类型（`-> int`, `-> void`）
- **Autoload 引用**：通过 `get_node_or_null("/root/SingletonName")` 获取，不做空引用
- **信号连接**：优先使用 `signal.connect(Callable)` 而非字符串连接
- **调试日志**：使用 `const DEBUG_DISABLED = true` 控制，生产环境禁用

### 架构原则
- **信号驱动**：场景间通信通过 `SignalBus` 和 Autoload 单例，禁止跨场景直接引用节点
- **WebSocket 数据流**：`WebSocketListener` → 靶纸脚本 `target_hit` signal → 训练控制器
- **设置持久化**：通过 `HttpService` 读写，不直接操作文件系统
- **资源管理**：使用 `preload()` 加载常驻资源，对象池管理频繁创建销毁的对象

### 关键约束
- **视口**：720×1280 竖屏，所有 UI 布局按此设计
- **帧率**：最高 60fps，禁用 VSync（`vsync_mode=0`）
- **渲染器**：GL Compatibility（OpenGL ES），不使用 Vulkan 专属特性
- **性能敏感**：嵌入式设备，严格控制 GC 分配和节点数量
- **Godot 版本**：严格使用 4.6 API，不使用 4.3 以下或实验性特性

### 目录约定
- `script/` — GDScript 脚本
- `scene/` — .tscn 场景文件
- `asset/` — 图片资源（PNG）
- `audio/` — 音频资源（OGG/MP3）
- `shader/` — .gdshader 着色器
- `theme/` — .tres UI 主题
- `translations/` — .translation 国际化文件
- `games/`（在 scene/ 和 script/ 内）— 小游戏模块

### 修改靶纸脚本时的注意事项
1. 区域判定顺序：**A → C → D**（高分优先），使用 `Geometry2D.is_point_in_polygon()`
2. GPU 实例化弹孔：修改 `max_instances_per_texture` 影响性能
3. 旋转靶处理：检测父节点名包含 `IPSCMiniRotate` 或 `RotationCenter` 走特殊路径
4. 消失动画：`max_shots` 控制，达到后触发 `play_disappearing_animation()`
5. `drill_active` 标志：训练未开始时忽略所有弹着点

### 修改训练流程时的注意事项
1. 靶纸类型必须在 `drills_network.gd` 的 `valid_targets_by_mode` 中注册
2. 分数规则通过 `GlobalData.settings_dict["target_rule"]` 动态配置
3. 训练完成数据通过 `HttpService.save_game()` 保存到服务器
4. 网络模式（`drills_network`）有独立的靶纸类型映射

### 不允许的操作
- ❌ 使用 `@onready` 引用跨场景节点
- ❌ 在 `_process()` 中创建/销毁节点（使用对象池）
- ❌ 直接操作文件系统读写设置（通过 HttpService）
- ❌ 在 WebSocket 回调中执行耗时操作
- ❌ 硬编码视口分辨率（使用 `get_viewport().size`）
- ❌ 修改 `.import` 文件（Godot 自动生成）

### 提交前检查清单
- [ ] DEBUG_DISABLED 在生产代码中为 true
- [ ] 无新增 `print()` 语句（或被 DEBUG_DISABLED 保护）
- [ ] 信号连接有断开逻辑（`_exit_tree()` 或 `queue_free()` 前）
- [ ] 资源使用 `preload()` 或弱引用
- [ ] 无内存泄漏风险（Timer/Node 清理）
- [ ] 国际化：UI 文本使用 `tr("key")` 而非硬编码字符串

## 快速参考

### Autoload 单例
| 单例名 | 用途 |
|--------|------|
| `GlobalData` | 全局状态/设置/游戏模式 |
| `SignalBus` | 跨场景信号 |
| `WebSocketListener` | WebSocket 弹着点+遥控 |
| `HttpService` | HTTP 数据读写 |
| `MenuController` | 菜单导航控制 |

### 核心信号
| 信号 | 来源 | 用途 |
|------|------|------|
| `bullet_hit(pos, a, t)` | WebSocketListener | 弹着点数据 |
| `target_hit(zone, points, pos, t)` | 靶纸脚本 | 命中上报 |
| `target_disappeared` | 靶纸脚本 | 靶纸消失 |
| `navigate(direction)` | MenuController | 菜单导航 |
| `menu_control(directive)` | MenuController | 远程控制 |
| `settings_loaded` | GlobalData | 设置加载完成 |
| `drills_finished` | drills.gd | 训练结束 |

### 计分系统
| 区域 | 默认分 | 说明 |
|------|--------|------|
| AZone | 5 | 最内环 |
| CZone | 3 | 中间环 |
| DZone | 1 | 最外环 |
| miss | 0 | 脱靶 |
| WhiteZone | -10 | 禁射区 |
| Paddle | 5 | 翻板 |
| Popper | 5 | 弹出靶 |

### 目标平台
- **导出**：Linux ARM64，PCK embedded
- **运行**：嵌入式 Linux + Node.js 后端
- **OTA 目录**：`/srv/www/userapp/`

## 已知缺陷与解决方案

### 缺陷 1: bootcamp 中的双重输入

**症状**：在 bootcamp（靶纸自由练习）中，每次点击下一个/上一个按钮都会触发两次前进。

**根本原因**：WebSocketListener 的 `emit_click_for_ui` 标志在场景切换时持久化，导致两条信号路径同时触发：
1. **直接路径**：button `pressed` signal → `switch_to_next_target()`
2. **间接路径**：bullet_hit → `_on_bullet_hit_for_buttons()` → `_on_menu_control("right")` → `switch_to_next_target()`

main_menu 中的 `set_emit_click_for_ui(true)` 调用不会在场景切换时立即清除，导致 bootcamp 继承了这个标志状态。

**解决方案**：在 `bootcamp.gd` 的 `_ready()` 中明确禁用此标志：
```gdscript
var ws_listener = get_node_or_null("/root/WebSocketListener")
if ws_listener:
    ws_listener.menu_control.connect(_on_menu_control)
    ws_listener.set_emit_click_for_ui(false)  # 禁用 UI 点击注入 - bootcamp 使用原生弹着点检测
```

**为什么 bootcamp 不需要 UI 点击注入**：
- bootcamp 已经通过 `_on_bullet_hit_for_buttons()` 实现了高效的原生弹着点检测
- 不需要合成鼠标事件，直接监听 WebSocketListener 的 bullet_hit 信号更可靠
- 设备硬件弹着点数据比合成 UI 事件的延迟更低

**为什么 main_menu 仍可使用 UI 注入**：
- main_menu 启用 `emit_click_for_ui=true` 用于测试 UI 点击路径
- bootcamp 的 `_ready()` 会显式禁用此标志，防止跨场景持久化
- 每个场景对此标志的需求不同，需要主动管理

**相关代码位置**：
- `bootcamp.gd` 第 150-154 行：禁用 UI 点击注入
- `main_menu.gd` 第 171-186 行：启用 UI 点击注入
- `WebSocketListener.gd` 第 486-498 行：`set_emit_click_for_ui()` 实现

**提交记录**：
- `Fix: Double-input on next/prev buttons in bootcamp` - 原始修复
- `Re-enable: UI click injection in main_menu` - 恢复 main_menu 的 UI 注入，bootcamp 独立禁用

### 架构原则: bootcamp UI 按钮处理

**所有 bootcamp 中的 UI 按钮（back、prev、reset、next）必须使用手动弹着点检测，而不是合成鼠标事件注入。**

**实现方式**：
```gdscript
# 在 _on_bullet_hit_for_buttons() 中为每个按钮检测弹着点
func _on_bullet_hit_for_buttons(pos: Vector2, _a, _t):
	var now = Time.get_ticks_msec() / 1000.0
	if (now - _button_hit_cooldown) < BUTTON_HIT_COOLDOWN:
		return
	
	# 检测每个按钮的矩形区域
	if _check_button_hit(back_button, pos):
		_button_hit_cooldown = now
		_flash_button(back_button)
		_on_back_button_pressed()
		return
	if _check_button_hit(prev_button, pos):
		_button_hit_cooldown = now
		_flash_button(prev_button)
		_on_menu_control("left")
		return
	# ... 其他按钮
```

**为什么不使用合成鼠标事件**：
- CanvasLayer 按钮不响应 Input.parse_input_event() 注入的合成事件
- 手动弹着点检测直接基于实际硬件数据，无延迟且更可靠
- 避免产生双信号路径（signal + injected click）

**冷却时间**：
- 所有按钮共享 `_button_hit_cooldown` 和 `BUTTON_HIT_COOLDOWN` 常量
- 防止用户快速多次点击同一按钮或相邻按钮

**视觉反馈**：
- 每次检测到按钮被击中时，调用 `_flash_button()` 提供视觉反馈
- 闪烁效果由 tween 控制，持续 0.15 秒

**新增按钮的添加步骤**：
1. 在 bootcamp.tscn 中的 HBoxBottomBar 内创建 Button 节点
2. 在 bootcamp.gd 中添加 `@onready var button_name = $CanvasLayerStats/Control/HBoxBottomBar/ButtonName`
3. 在 `_ready()` 中连接 pressed signal：`button_name.pressed.connect(callback)`
4. 在 `_on_bullet_hit_for_buttons() 中添加检测逻辑**，在返回前加上冷却检查
5. 实现相应的回调函数（如 `_on_button_name_pressed()`）

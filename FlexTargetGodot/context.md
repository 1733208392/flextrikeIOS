# FlexTargetGodot - 项目上下文文档

## 项目概览

**FlexTargetGodot** 是一个基于 **Godot 4.6** (GL Compatibility) 的 2D 射击训练系统，部署在嵌入式 Linux 设备上（ARM64），通过 WebSocket 接收来自硬件传感器的实时弹着点数据，实现 IPSC/IDPA/CQB 三种射击训练模式的靶纸模拟。

### 基本信息
| 属性 | 值 |
|------|-----|
| 引擎 | Godot 4.6 |
| 渲染器 | GL Compatibility (OpenGL ES) |
| 视口 | 720×1280 竖屏 |
| 目标平台 | Linux ARM64 (嵌入式设备) |
| 导出格式 | PCK embedded, S3TC/BPTC 纹理 |
| 开发语言 | GDScript |
| 项目规模 | ~134 个脚本 (~42,785 行), 127 场景, 22 资源 |
| 版本 | 1.0.5 |

---

## 架构设计

### 核心通信架构

```
┌──────────────────┐    WebSocket     ┌──────────────────┐    HTTP/REST     ┌──────────────────┐
│  硬件传感器/手机   │ ◄──────────────► │  combined_server  │ ◄──────────────► │   嵌入式Linux     │
│  (BLE/触屏)       │    ws://127.0.0.1 │   (Node.js)       │   :8080/api/     │   (文件系统)       │
└──────────────────┘    /websocket     └──────────────────┘                   └──────────────────┘
         ▲                                      │
         │ bullet_hit(pos, a, t) signal        │ HTTP: load_game/save_game
         │ menu_control(directive) signal      │ netlink_status/volume_up/down
         ▼                                      ▼
┌─────────────────────────────────────────────────────────┐
│                    Godot App (720×1280)                  │
│                                                          │
│  WebSocketListener ──► MenuController ──► 场景系统       │
│       │                      │              │             │
│       ▼                      ▼              ▼             │
│  bullet_hit signal    navigate/enter     靶纸场景         │
│  menu_control signal   back/home        打孔/计分         │
│       │                                     │             │
│       ▼                                     ▼             │
│  ipsc_mini / cqb_enemy / popper / paddle     │             │
│       (zone检测 → GPU实例化弹孔 → 计分)        │             │
│                                     │                  │
│       HttpService ◄──► PerformanceTracker ◄───┘             │
│       (settings保存/读取)    (击中记录/速度分析)            │
└─────────────────────────────────────────────────────────┘
```

### Autoload 单例系统

| 单例 | 脚本路径 | 职责 |
|------|----------|------|
| `GlobalData` | `script/global_data.gd` | 全局状态：设置字典、游戏模式、OTA模式、网络状态 |
| `SignalBus` | `script/signal_bus.gd` | 跨场景信号：WiFi连接、网络启停、下载进度、OTA升级 |
| `WebSocketListener` | `script/WebSocketListener.gd` | WebSocket 连接：弹着点数据、菜单控制指令、BLE命令、动画配置 |
| `HttpService` | `script/HttpService.gd` | HTTP 通信：游戏数据读写、netlink状态、音量控制 |
| `MenuController` | `script/MenuController.gd` | 菜单遥控：处理WebSocket指令(up/down/enter/back/home/volume/power) |
| `GlobalDebug` | `script/GlobalDebug.gd` | 调试开关 |
| `StatusBar` | `scene/StatusBar.tscn` | 全局状态栏 |
| `GreetingOverlay` | `script/greeting_overlay.gd` | 问候叠加层 |

---

## 目录结构

```
FlexTargetGodot/
├── project.godot              # 项目配置
├── combined_server.js         # Node.js 模拟服务器 (HTTP+WebSocket+BLE)
├── settings.json              # 本地设置缓存
├── export_presets.cfg         # 导出配置 (Linux ARM64)
│
├── asset/                     # 图片资源 (~16MB)
│   ├── ipsc_mini.png          # IPSC 迷你靶 (标准)
│   ├── ipsc-medium.png       # IPSC 中号靶
│   ├── ipsc_white.png        # IPSC 白色靶
│   ├── ipsc_black_1/2.png    # IPSC 黑色靶变体
│   ├── idpa-black-1/2.png    # IDPA 靶纸
│   ├── idpa-ns.png           # IDPA 无射击区靶
│   ├── bullet_hole1~6.png     # 6种弹孔纹理
│   ├── hostage-female.png    # 人质靶
│   ├── cqb_enemy*.png        # CQB 敌方靶
│   ├── crosshair.png          # 准星
│   ├── bullet.png             # 子弹特效
│   └── ...                    # UI元素、背景、图标等
│
├── audio/                     # 音频资源 (~14MB)
│   ├── Cursor.ogg            # 菜单导航音效
│   ├── paper_hit.ogg         # 靶纸命中音效
│   ├── bullet.mp3            # 子弹音效
│   ├── bullet-hit-metal.mp3  # 金属命中音效
│   ├── 13 - Decisive Battle 1.ogg  # 背景音乐
│   ├── 18 - Never Give Up.ogg
│   └── ...
│
├── shader/                    # 自定义着色器
│   ├── bullet_hole_instanced.gdshader  # GPU实例化弹孔渲染
│   ├── explosion.gdshader     # 爆炸特效
│   ├── orbiting_dot.gdshader  # 轨道点特效
│   ├── paddle_fall.gdshader   # 翻板下落特效
│   ├── skew_shader.gdshader   # 倾斜着色器
│   └── games/night_sky.tres   # 夜空背景
│
├── script/                    # GDScript 脚本 (~134个)
│   ├── global_data.gd        # [Autoload] 全局数据
│   ├── signal_bus.gd         # [Autoload] 信号总线
│   ├── WebSocketListener.gd   # [Autoload] WebSocket 通信
│   ├── HttpService.gd        # [Autoload] HTTP 服务
│   ├── MenuController.gd      # [Autoload] 菜单控制
│   ├── GlobalDebug.gd         # [Autoload] 调试
│   ├── greeting_overlay.gd    # [Autoload] 问候
│   │
│   ├── drills.gd              # [核心] 训练主控制器 (1375行)
│   ├── bootcamp.gd            # [核心] 练习场模式 (1094行)
│   ├── drill_ui.gd            # 训练UI (计时器/标题/进度)
│   ├── drill_complete_overlay.gd      # 训练完成界面
│   ├── drill_complete_overlay_new.gd  # 训练完成界面(新)
│   ├── drill_replay.gd        # 训练回放
│   ├── performance_tracker.gd # 性能追踪 (速度/分数分析)
│   ├── score_utils.gd         # 计分工具
│   │
│   ├── ipsc_mini.gd           # [靶纸] IPSC迷你靶 (680行)
│   ├── ipsc_mini_black_1.gd   # IPSC黑色靶1
│   ├── ipsc_mini_black_2.gd   # IPSC黑色靶2
│   ├── ipsc_mini_double.gd    # IPSC双靶
│   ├── ipsc_mini_rotate.gd    # IPSC旋转靶
│   ├── ipsc_white.gd          # IPSC白色靶
│   ├── idpa.gd                # IDPA靶
│   ├── idpa_ns.gd             # IDPA无射击区
│   ├── idpa_hard_cover_1/2.gd # IDPA硬遮蔽靶
│   ├── hostage.gd             # 人质靶
│   ├── mozambique.gd          # Mozambique靶
│   ├── bullseye.gd            # 靶心靶
│   ├── cqb_enemy.gd           # CQB敌方靶 (695行)
│   ├── custom_target.gd       # 自定义靶 (大型, 980行)
│   │
│   ├── popper.gd / popper_simple.gd       # 弹出靶
│   ├── paddle.gd / paddle_simple.gd        # 翻板靶
│   ├── 2poppers.gd / 2poppers_simple.gd    # 双弹出靶
│   ├── 3paddles.gd / 3paddles_simple.gd    # 三翻板靶
│   │
│   ├── bullet.gd              # 子弹特效
│   ├── bullet_hole.gd         # 弹孔节点
│   ├── explosion_effect.gd    # 爆炸特效
│   ├── shooting_range.gd      # 射击场
│   ├── shot_timer.gd          # 计时器
│   ├── volumn.gd              # 音量控制
│   │
│   ├── qrcode.gd              # QR码生成
│   ├── screenshot_manager.gd  # 截图管理
│   ├── chunk_validator.gd    # 数据分块验证
│   ├── TargetAnimationLibrary.gd  # 靶纸动画库
│   │
│   ├── games/                 # 小游戏模块
│   │   ├── signal_bus.gd      # 小游戏信号
│   │   ├── game.gd            # 通用游戏逻辑
│   │   ├── fruitninja/        # 水果忍者
│   │   ├── wack-a-mole/       # 打地鼠
│   │   ├── monkey/            # 猴子游戏
│   │   ├── rhythm/            # 节奏游戏
│   │   └── tictactoe/         # 井字棋
│   └── ...
│
├── scene/                     # Godot 场景文件
│   ├── main_menu/             # 主菜单 (含自定义着色器/按钮主题)
│   ├── intro/                 # 训练介绍页 (IPSC/IDPA说明)
│   ├── drills.tscn            # 训练主场景
│   ├── bootcamp.tscn          # 练习场场景
│   ├── splash_loading.tscn    # 启动画面
│   ├── onboarding.tscn        # 引导页
│   ├── option/                # 设置页 (网络/软件升级)
│   ├── power_off_dialog.*     # 关机确认
│   ├── target_modal.tscn      # 靶纸选择弹窗
│   ├── history*.tscn          # 历史记录
│   ├── drill_replay.tscn      # 训练回放
│   │
│   ├── targets/               # 靶纸场景
│   │   ├── bullseye.tscn      # 靶心靶
│   │   ├── hostage.tscn       # 人质靶
│   │   ├── idpa.tscn / uspsa.tscn
│   │   ├── cqb_front/moving/swing/hostage.tscn
│   │   ├── disguised_enemy*.tscn
│   │   ├── texas_star/plate.tscn
│   │   ├── mozambique.tscn
│   │   ├── 2poppers*.tscn / 3paddles*.tscn
│   │   └── ...
│   │
│   ├── ipsc_mini*.tscn        # IPSC靶纸场景
│   ├── dueling_tree_composite.tscn  # 决斗树
│   ├── drill_ui.tscn          # 训练UI叠加层
│   ├── shot_timer.tscn        # 计时器
│   │
│   ├── games/                 # 小游戏场景
│   │   ├── fruitninja/, monkey/, wack-a-mole/, rhythm/
│   │   └── tictactoe/
│   │
│   ├── drills_network/        # 网络训练模式
│   │   ├── drills_network.tscn
│   │   ├── drill_network_ui.tscn
│   │   └── drill_network_complete_overlay.tscn
│   │
│   ├── wifi_networks.tscn      # WiFi连接
│   ├── networking_config.tscn  # 网络配置
│   └── benchmark/              # 性能基准测试
│       ├── chimp_test.tscn
│       └── quickreact.tscn
│
├── theme/                     # UI主题资源
│   ├── custom_button_theme.tres
│   ├── main_menu_button_theme.tres
│   ├── target_title_*.tres     # 训练标题主题
│   └── ...
│
├── addons/                    # 编辑器插件
│   └── onscreenkeyboard/      # 屏幕键盘插件
│
└── translations/              # 国际化翻译
    ├── translations.en.translation
    ├── translations.zh_CN.translation
    ├── translations.ja.translation
    └── translations.zh_TW.translation
```

---

## 核心系统详解

### 1. 弹着点系统 (WebSocket → 靶纸)

**数据流**：硬件传感器 → WebSocket → `WebSocketListener.bullet_hit(pos, a, t)` → 靶纸脚本

- `pos: Vector2` — 屏幕坐标的弹着点位置
- `a: int` — 命中区分类（0=未分类）
- `t: int` — 时间戳
- `WebSocketListener` 设置了 **process_priority=100**（最高优先级），确保实时处理
- 消息节流：10ms冷却，每帧最多处理20条消息
- 指令节流：500ms冷却防止硬件拥塞

### 2. 区域判定与计分

**IPSC 标准靶** 使用 `CollisionPolygon2D` 定义 A/C/D 区域：
```
AZone (5分) → CZone (3分) → DZone (1分) → miss (0分)
```
判定使用 `Geometry2D.is_point_in_polygon()`，通过 `score_utils.gd` 查询分数。
分数规则可通过 `GlobalData.settings_dict["target_rule"]` 动态配置。

### 3. GPU 实例化弹孔渲染

每个靶纸使用 `MultiMeshInstance2D` + 6种弹孔纹理的 GPU 实例化渲染：
- 每种纹理最多32个实例（192个弹孔/靶）
- 使用 `bullet_hole_instanced.gdshader` 着色器
- 复用 `Transform2D` 避免每帧分配

### 4. 训练模式

| 模式 | 场景 | 说明 |
|------|------|------|
| **Drills** | `drills.tscn` | 标准训练：按序列展示靶纸，计时+计分 |
| **Bootcamp** | `bootcamp.tscn` | 练习场：自由射击，支持缩放(0.5x/0.7x/1x) |
| **Network** | `drills_network.tscn` | 网络训练：多设备同步，QR码组网 |
| **Replay** | `drill_replay.tscn` | 回放训练记录 |

### 5. 靶纸类型

**IPSC 系列**：ipsc_mini, ipsc_mini_black_1/2, ipsc_mini_double, ipsc_mini_rotate, ipsc_white
**IDPA 系列**：idpa, idpa_ns, idpa_hard_cover_1/2
**CQB 系列**：cqb_front, cqb_moving, cqb_swing, cqb_hostage, disguised_enemy, disguised_enemy_surrender
**其他**：hostage, popper, paddle, texas_star, mozambique, bullseye, custom_target

### 6. 游戏模式

| 模式 | 靶纸类型 |
|------|----------|
| IPSC | ipsc, ipsc_mini_double, special_1/2, hostage, rotation, paddle, popper, final |
| IDPA | idpa, idpa_black_1/2, idpa_ns, hostage, paddle, popper, final |
| CQB | cqb_front, cqb_move, cqb_swing, cqb_hostage, disguised_enemy |

### 7. 设置持久化

设置存储在嵌入式设备的 `/srv/www/userapp/` 目录，通过 `HttpService` 的 HTTP API 读写：
- `settings` — 游戏设置（语言/序列/音量/自动重启等）
- `netlink_status` — 网络连接状态
- 支持 OTA 模式检测（目录可写性检查）

### 8. 国际化

支持4种语言：English, Chinese (zh_CN), Traditional Chinese (zh_TW), Japanese (ja)

### 9. 硬件集成

- **BLE (蓝牙)**：通过 `combined_server.js` 模拟，支持广播/连接/读写特征值
- **WebSocket**：弹着点数据和远程控制指令
- **屏幕键盘**：`onscreenkeyboard` 插件用于无物理键盘的嵌入式设备

---

## 关键设计模式

1. **Autoload 单例**：所有全局状态通过 Autoload 管理，场景间通过 `GlobalData` 和 `SignalBus` 通信
2. **信号驱动**：靶纸通过 `target_hit` signal 上报命中，训练控制器通过信号收集数据
3. **GPU 实例化**：弹孔渲染使用 `MultiMeshInstance2D`，避免大量节点创建
4. **效果节流**：音效(50ms)、烟雾(80ms)、冲击(60ms) 冷却防止性能问题
5. **对象池**：弹孔节点池、音频播放器池减少运行时分配
6. **数据序列化**：训练记录通过 HTTP API 存储在服务器端 JSON 文件

---

## 已知问题与注意事项

- 项目内名称仍残留 `GODotTetris`（从模板继承）
- 部分靶纸脚本（`ipsc_mini.gd`, `cqb_enemy.gd`）代码量较大，包含冗余的碰撞检测代码（已标记 obsolete）
- `combined_server.js` 是开发模拟器，生产环境使用独立的后端服务
- 纹理格式使用 S3TC/BPTC（PC兼容），移动设备可能需要 ETC2/ASTC
- `GlobalData.DEBUG_DISABLED` 和各脚本的 `DEBUG_DISABLED` 控制日志输出

# FPGA Flappy Bird 游戏
([English](README.md)|中文）

基于FPGA的Flappy Bird游戏实现，使用Verilog HDL编写，支持HDMI输出、SD卡图片加载和AI自动游戏模式。
![游戏预览](doc/png/new.png)

## 功能特性

- **Flappy Bird 游戏玩法**: 经典的小鸟穿越管道游戏
- **HDMI 视频输出**: 1024x768 分辨率，60Hz 刷新率
- **SD 卡支持**: 从SD卡加载游戏资源（背景、精灵图）
- **SDRAM 缓冲**: 4MB SDRAM 用于图像存储和显示缓冲
- **双控制模式**:
  - 手动模式: 按键跳跃
  - AI 自动模式: AI自动控制小鸟
- **分数显示**: 数码管实时显示当前分数
- **碰撞检测**: 实时检测小鸟与管道的碰撞

## 硬件需求

- FPGA 开发板（ Cyclone正点原子新起点开发板）
- SD 卡（FAT32 格式，预存游戏图片）
- HDMI 显示器
- 2 个按键（跳跃和模式切换）

## 项目结构

```
digital/
├── rtl/                    # Verilog RTL 源代码
│   ├── sd_bmp_hdmi.v       # 顶层模块
│   ├── game/               # 游戏逻辑模块
│   │   ├── ai_ctrl.v      # AI 控制模块
│   │   ├── bird_ctrl.v    # 小鸟物理控制器
│   │   ├── collision_det.v# 碰撞检测模块
│   │   ├── game_ctrl.v    # 游戏状态机
│   │   ├── pipe_gen.v     # 管道生成模块
│   │   └── sprite_render.v # 精灵渲染模块
│   ├── hdmi/               # HDMI 输出驱动
│   │   ├── hdmi_top.v     # HDMI 顶层模块
│   │   └── video_driver.v # 视频时序生成器
│   ├── sdram/              # SDRAM 控制器
│   │   └── sdram_top.v     # SDRAM 顶层模块
│   ├── sd_ctrl_top.v      # SD 卡控制器
│   └── seg_driver.v        # 数码管驱动模块
├── prj/                    # Quartus 项目文件
├── sim/                    # 仿真文件
├── convert_code/           # 图片转换工具
│   ├── convert_images.py   # PNG 转 BMP 格式
│   ├── flip_bmp.py        # 翻转 BMP 图片
│   └── ...
└── doc/                    # 文档和资源
```

## 模块说明

### 顶层模块
- `sd_bmp_hdmi.v`: 连接所有子系统的顶层主模块

### 游戏逻辑模块
| 模块 | 功能 |
|------|------|
| `ai_ctrl.v` | AI 自动模式决策逻辑 |
| `bird_ctrl.v` | 小鸟物理模拟（重力、跳跃） |
| `pipe_gen.v` | 生成移动的管道对 |
| `collision_det.v` | 检测小鸟与管道的碰撞 |
| `game_ctrl.v` | 游戏状态管理（空闲/游戏中/结束） |
| `sprite_render.v` | 将精灵图渲染到背景上 |

### 接口模块
| 模块 | 功能 |
|------|------|
| `sd_ctrl_top.v` | SD 卡 SPI 接口 |
| `sdram_top.v` | SDRAM 读写控制器 |
| `hdmi_top.v` | HDMI TMDS 发射器 |
| `seg_driver.v` | 数码管显示驱动 |

## 安装与使用

### 1. 准备 SD 卡
将 SD 卡格式化为 FAT32 格式，放入转换好的 BMP 图片（1024x768 分辨率，16 位 RGB565 格式）。

### 2. 转换图片
使用 `convert_code/` 目录下的 Python 脚本准备游戏资源：
```bash
cd convert_code
python convert_images.py
```

### 3. Quartus 项目
在 Quartus II/Prime 中打开 `prj/sd_bmp_hdmi.qpf` 并下载到 FPGA。

### 4. 操作说明
- **KEY_JUMP**: 按下使小鸟跳跃
- **KEY_AUTO**: 切换手动/AI 自动模式

## 技术细节

- **显示分辨率**: 1024x768 @ 60Hz
- **像素时钟**: 65MHz
- **SDRAM 大小**: 4MB（显示缓冲）
- **图片格式**: 16 位 BMP（RGB565）
- **SD 卡接口**: SPI 模式
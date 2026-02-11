# FPGA Flappy Bird Game
([中文](README.zh-CN.md)|English)

A Flappy Bird game implemented on FPGA using Verilog HDL, featuring HDMI output, SD card image loading, and AI auto-play mode.
![Game Preview](doc/png/new.png)

## Features

- **Flappy Bird Gameplay**: Classic bird-flying-through-pipes gameplay
- **HDMI Video Output**: 1024x768 resolution at 60Hz
- **SD Card Support**: Load game assets (backgrounds, sprites) from SD card
- **SDRAM Buffer**: 4MB SDRAM for image storage and display buffering
- **Dual Control Modes**:
  - Manual mode: Press key to jump
  - AI auto-play mode: AI automatically controls the bird
- **Score Display**: 7-segment display shows current score
- **Collision Detection**: Real-time collision detection with pipes

## Hardware Requirements

- FPGA Development Board (tested with Cyclone series)
- SD Card (FAT32 formatted, pre-loaded with game images)
- HDMI Display
- 2 Push Buttons (for jump and mode switching)

## Project Structure

```
digital/
├── rtl/                    # Verilog RTL source code
│   ├── sd_bmp_hdmi.v       # Top-level module
│   ├── game/               # Game logic modules
│   │   ├── ai_ctrl.v      # AI control module
│   │   ├── bird_ctrl.v    # Bird physics controller
│   │   ├── collision_det.v# Collision detection
│   │   ├── game_ctrl.v    # Game state machine
│   │   ├── pipe_gen.v     # Pipe generation
│   │   └── sprite_render.v # Sprite rendering
│   ├── hdmi/               # HDMI output drivers
│   │   ├── hdmi_top.v     # HDMI top module
│   │   └── video_driver.v # Video timing generator
│   ├── sdram/              # SDRAM controller
│   │   └── sdram_top.v     # SDRAM top module
│   ├── sd_ctrl_top.v      # SD card controller
│   └── seg_driver.v        # 7-segment display driver
├── prj/                    # Quartus project files
├── sim/                    # Simulation files
├── convert_code/           # Image conversion utilities
│   ├── convert_images.py   # Convert PNG to BMP format
│   ├── flip_bmp.py        # Flip BMP images
│   └── ...
└── doc/                    # Documentation and resources
```

## Module Description

### Top-Level Module
- `sd_bmp_hdmi.v`: Main top module connecting all sub-systems

### Game Logic Modules
| Module | Function |
|--------|----------|
| `ai_ctrl.v` | AI decision-making for auto-play mode |
| `bird_ctrl.v` | Bird physics (gravity, jumping) |
| `pipe_gen.v` | Generate moving pipe pairs |
| `collision_det.v` | Detect bird-pipe collisions |
| `game_ctrl.v` | Game state management (IDLE/PLAY/OVER) |
| `sprite_render.v` | Render sprites onto background |

### Interface Modules
| Module | Function |
|--------|----------|
| `sd_ctrl_top.v` | SD card SPI interface |
| `sdram_top.v` | SDRAM read/write controller |
| `hdmi_top.v` | HDMI TMDS transmitter |
| `seg_driver.v` | 7-segment display driver |

## Installation & Usage

### 1. Prepare SD Card
Format SD card as FAT32. Place converted BMP images (1024x768 resolution, 16-bit RGB565 format).

### 2. Convert Images
Use Python scripts in `convert_code/` to prepare game assets:
```bash
cd convert_code
python convert_images.py
```

### 3. Quartus Project
Open `prj/sd_bmp_hdmi.qpf` in Quartus II/Prime and program the FPGA.

### 4. Controls
- **KEY_JUMP**: Press to make bird jump
- **KEY_AUTO**: Toggle between manual/AI mode

## Technical Details

- **Display Resolution**: 1024x768 @ 60Hz
- **Pixel Clock**: 65MHz
- **SDRAM Size**: 4MB (display buffer)
- **Image Format**: 16-bit BMP (RGB565)
- **SD Card Interface**: SPI mode

 
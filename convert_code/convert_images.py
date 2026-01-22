#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
FlappyBird图片素材转换脚本
功能：PNG转BMP，调整尺寸，处理透明色
"""

from PIL import Image, ImageDraw, ImageFont
import os

# 配置参数
TRANSPARENT_COLOR = (0, 255, 0)  # 绿色作为透明色键 (RGB565: 0x07E0)
INPUT_DIR = 'doc'
OUTPUT_DIR = 'doc/bmp_output'

def ensure_output_dir():
    """确保输出目录存在"""
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"创建输出目录: {OUTPUT_DIR}")

def png_to_bmp(png_path, bmp_path, target_size=None, bg_color=TRANSPARENT_COLOR):
    """
    将PNG转换为BMP，处理透明通道
    
    Args:
        png_path: 输入PNG文件路径
        bmp_path: 输出BMP文件路径
        target_size: 目标尺寸 (width, height)，None表示保持原尺寸
        bg_color: 透明区域的背景色
    """
    try:
        img = Image.open(png_path)
        print(f"\n处理: {os.path.basename(png_path)}")
        print(f"  原始尺寸: {img.size}, 模式: {img.mode}")
        
        # 处理透明通道
        if img.mode == 'RGBA':
            # 创建RGB背景
            rgb_img = Image.new('RGB', img.size, bg_color)
            # 使用Alpha通道合成
            alpha = img.split()[3]
            rgb_img.paste(img, mask=alpha)
            img = rgb_img
        elif img.mode == 'P':  # 调色板模式
            # 转换为RGBA
            img = img.convert('RGBA')
            rgb_img = Image.new('RGB', img.size, bg_color)
            if len(img.split()) > 3:  # 有Alpha通道
                alpha = img.split()[3]
                rgb_img.paste(img, mask=alpha)
            else:
                rgb_img.paste(img)
            img = rgb_img
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # 调整尺寸
        if target_size and target_size != img.size:
            img = img.resize(target_size, Image.Resampling.LANCZOS)
            print(f"  缩放至: {target_size}")
        
        # 保存为BMP
        img.save(bmp_path, 'BMP')
        
        # 获取文件大小
        file_size = os.path.getsize(bmp_path)
        print(f"  保存为: {os.path.basename(bmp_path)}")
        print(f"  文件大小: {file_size / 1024:.2f} KB")
        print(f"  [OK] Conversion successful")
        
        return True
    except Exception as e:
        print(f"  [ERROR] Conversion failed: {e}")
        return False

def create_text_image(text, size=(1024, 768), bg_image=None, output_path=None):
    """
    创建带文字的界面图片
    
    Args:
        text: 显示的文字
        size: 图片尺寸
        bg_image: 背景图片路径（可选）
        output_path: 输出路径
    """
    try:
        # 如果有背景图，加载背景
        if bg_image and os.path.exists(bg_image):
            img = Image.open(bg_image).convert('RGB')
            if img.size != size:
                img = img.resize(size, Image.Resampling.LANCZOS)
        else:
            # 创建渐变背景（天空色）
            img = Image.new('RGB', size, (135, 206, 235))
        
        # 创建半透明遮罩层
        overlay = Image.new('RGBA', size, (0, 0, 0, 100))
        img_rgba = img.convert('RGBA')
        img = Image.alpha_composite(img_rgba, overlay).convert('RGB')
        
        # 添加文字
        draw = ImageDraw.Draw(img)
        
        # 尝试使用系统字体，失败则使用默认字体
        try:
            font_large = ImageFont.truetype("arial.ttf", 80)
            font_small = ImageFont.truetype("arial.ttf", 40)
        except:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # 计算文字位置（居中）
        bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        text_x = (size[0] - text_width) // 2
        text_y = (size[1] - text_height) // 2
        
        # 绘制阴影
        draw.text((text_x + 3, text_y + 3), text, fill=(0, 0, 0), font=font_large)
        # 绘制文字
        draw.text((text_x, text_y), text, fill=(255, 255, 255), font=font_large)
        
        # 保存
        if output_path:
            img.save(output_path, 'BMP')
            file_size = os.path.getsize(output_path)
            print(f"\n创建界面图片: {os.path.basename(output_path)}")
            print(f"  文件大小: {file_size / 1024:.2f} KB")
            print(f"  [OK] Created successfully")
        
        return img
    except Exception as e:
        print(f"  [ERROR] Creation failed: {e}")
        return None

def main():
    """主函数"""
    print("="*60)
    print("FlappyBird 图片素材转换工具")
    print("="*60)
    
    ensure_output_dir()
    
    # 转换配置：[输入文件, 输出文件名, 目标尺寸]
    convert_tasks = [
        # 背景图 - 缩放至屏幕大小
        ('background-day.png', 'background_1024x768.bmp', (1024, 768)),
        
        # 地面 - 宽度拉伸
        ('base.png', 'base_1024x150.bmp', (1024, 150)),
        
        # 管道 - 等比放大
        ('pipe-green.png', 'pipe_80x500.bmp', (80, 500)),
        
        # 小鸟动画帧 - 等比放大
        ('yellowbird-downflap.png', 'bird_down_50x35.bmp', (50, 35)),
        ('yellowbird-midflap.png', 'bird_mid_50x35.bmp', (50, 35)),
        ('yellowbird-upflap.png', 'bird_up_50x35.bmp', (50, 35)),
    ]
    
    # 执行转换
    success_count = 0
    for png_file, bmp_file, size in convert_tasks:
        png_path = os.path.join(INPUT_DIR, png_file)
        bmp_path = os.path.join(OUTPUT_DIR, bmp_file)
        
        if os.path.exists(png_path):
            if png_to_bmp(png_path, bmp_path, size):
                success_count += 1
        else:
            print(f"\n警告: 找不到文件 {png_path}")
    
    # 创建开始界面
    print("\n" + "="*60)
    print("创建游戏界面")
    print("="*60)
    
    bg_bmp = os.path.join(OUTPUT_DIR, 'background_1024x768.bmp')
    
    # 开始界面
    create_text_image(
        "PRESS KEY TO START",
        size=(1024, 768),
        bg_image=bg_bmp if os.path.exists(bg_bmp) else None,
        output_path=os.path.join(OUTPUT_DIR, 'start_screen.bmp')
    )
    
    # 游戏结束界面
    create_text_image(
        "GAME OVER",
        size=(1024, 768),
        bg_image=bg_bmp if os.path.exists(bg_bmp) else None,
        output_path=os.path.join(OUTPUT_DIR, 'gameover_screen.bmp')
    )
    
    # 统计结果
    print("\n" + "="*60)
    print("转换完成!")
    print("="*60)
    print(f"成功转换: {success_count} 个游戏素材")
    print(f"生成界面: 2 个")
    print(f"输出目录: {OUTPUT_DIR}")
    
    # 列出所有生成的文件
    print("\n生成的BMP文件列表:")
    bmp_files = sorted([f for f in os.listdir(OUTPUT_DIR) if f.endswith('.bmp')])
    total_size = 0
    for idx, filename in enumerate(bmp_files, 1):
        filepath = os.path.join(OUTPUT_DIR, filename)
        size = os.path.getsize(filepath)
        total_size += size
        print(f"  {idx}. {filename:<30} ({size/1024:>8.2f} KB)")
    
    print(f"\n总大小: {total_size / (1024*1024):.2f} MB")
    print("\n" + "="*60)
    print("下一步操作:")
    print("1. 检查生成的BMP文件")
    print("2. 将 doc/bmp_output 目录下所有BMP文件拷贝到SD卡根目录")
    print("3. 使用WinHex工具查看每个文件的起始扇区地址")
    print("="*60)

if __name__ == '__main__':
    main()

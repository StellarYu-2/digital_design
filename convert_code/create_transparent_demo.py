#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
透明色处理演示脚本
对比展示PNG原图、BMP转换结果、以及FPGA显示效果
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_comparison_demo():
    """创建透明色处理对比演示图"""
    
    # 创建画布
    canvas_width = 1200
    canvas_height = 800
    canvas = Image.new('RGB', (canvas_width, canvas_height), (255, 255, 255))
    draw = ImageDraw.Draw(canvas)
    
    # 加载字体
    try:
        font_title = ImageFont.truetype("arial.ttf", 24)
        font_text = ImageFont.truetype("arial.ttf", 16)
    except:
        font_title = ImageFont.load_default()
        font_text = ImageFont.load_default()
    
    # 标题
    draw.text((400, 20), "Transparent Color Processing", fill=(0, 0, 0), font=font_title)
    
    # 加载示例图片
    try:
        # PNG原图
        bird_png = Image.open('doc/yellowbird-midflap.png')
        # BMP转换结果
        bird_bmp = Image.open('doc/bmp_output/bird_mid_50x35.bmp')
        # 创建背景
        bg = Image.new('RGB', (150, 150), (135, 206, 235))  # 天空蓝
        
        # 位置1: PNG原图（带透明通道）
        x1, y1 = 100, 100
        draw.text((x1, y1-30), "1. Original PNG", fill=(0, 0, 0), font=font_text)
        # 显示PNG在蓝色背景上
        bg1 = bg.copy()
        bird_rgba = bird_png.convert('RGBA')
        bird_scaled = bird_rgba.resize((100, 70), Image.Resampling.LANCZOS)
        bg1.paste(bird_scaled, (25, 40), bird_scaled)
        canvas.paste(bg1, (x1, y1))
        draw.text((x1, y1+160), "Has Alpha channel", fill=(0, 128, 0), font=font_text)
        draw.text((x1, y1+180), "Background: Transparent", fill=(0, 128, 0), font=font_text)
        
        # 箭头
        draw.text((x1+160, y1+60), "Convert to BMP", fill=(255, 0, 0), font=font_text)
        draw.text((x1+180, y1+80), "↓", fill=(255, 0, 0), font=font_title)
        
        # 位置2: BMP转换结果（绿色背景）
        x2, y2 = 100, 350
        draw.text((x2, y2-30), "2. BMP Result", fill=(0, 0, 0), font=font_text)
        # 显示BMP（绿色背景）
        bg2 = Image.new('RGB', (150, 150), (255, 255, 255))
        bird_bmp_scaled = bird_bmp.resize((100, 70), Image.Resampling.LANCZOS)
        bg2.paste(bird_bmp_scaled, (25, 40))
        canvas.paste(bg2, (x2, y2))
        draw.text((x2, y2+160), "No Alpha channel", fill=(255, 0, 0), font=font_text)
        draw.text((x2, y2+180), "Background: Green(0,255,0)", fill=(0, 128, 0), font=font_text)
        
        # 箭头
        draw.text((x2+160, y2+60), "FPGA Render", fill=(255, 0, 0), font=font_text)
        draw.text((x2+180, y2+80), "→", fill=(255, 0, 0), font=font_title)
        
        # 位置3: FPGA显示效果（色键透明）
        x3, y3 = 450, 350
        draw.text((x3, y3-30), "3. FPGA Display", fill=(0, 0, 0), font=font_text)
        # 模拟FPGA渲染：将绿色替换为天空背景
        bg3 = bg.copy()
        # 手动实现色键透明
        bird_array = bird_bmp_scaled.convert('RGB')
        bg3_paste = bg3.copy()
        for y in range(bird_bmp_scaled.height):
            for x in range(bird_bmp_scaled.width):
                pixel = bird_array.getpixel((x, y))
                # 检测绿色
                if pixel != (0, 255, 0):  # 不是透明色
                    bg3_paste.putpixel((x+25, y+40), pixel)
        canvas.paste(bg3_paste, (x3, y3))
        draw.text((x3, y3+160), "Green pixels skipped", fill=(0, 128, 0), font=font_text)
        draw.text((x3, y3+180), "Background shows through", fill=(0, 128, 0), font=font_text)
        
        # 右侧说明
        x_info = 650
        y_info = 100
        
        draw.text((x_info, y_info), "Color Key Method:", fill=(0, 0, 0), font=font_title)
        
        # 绿色色块示例
        draw.rectangle((x_info, y_info+40, x_info+50, y_info+90), fill=(0, 255, 0))
        draw.text((x_info+60, y_info+50), "Transparent Color", fill=(0, 0, 0), font=font_text)
        draw.text((x_info+60, y_info+70), "RGB(0, 255, 0)", fill=(0, 128, 0), font=font_text)
        
        # FPGA逻辑
        y_logic = y_info + 120
        draw.text((x_info, y_logic), "FPGA Logic:", fill=(0, 0, 0), font=font_text)
        
        logic_lines = [
            "if (pixel == GREEN)",
            "  display = background;",
            "else",
            "  display = sprite;"
        ]
        
        for i, line in enumerate(logic_lines):
            draw.text((x_info+10, y_logic+25+i*20), line, fill=(0, 0, 255), font=font_text)
        
        # RGB565格式说明
        y_rgb = y_logic + 140
        draw.text((x_info, y_rgb), "RGB565 Format:", fill=(0, 0, 0), font=font_text)
        draw.text((x_info+10, y_rgb+25), "RGB(0,255,0) = 0x07E0", fill=(0, 128, 0), font=font_text)
        draw.text((x_info+10, y_rgb+50), "Binary: 0000011111100000", fill=(0, 0, 255), font=font_text)
        
        # 优势说明
        y_adv = y_rgb + 100
        draw.text((x_info, y_adv), "Advantages:", fill=(0, 0, 0), font=font_text)
        advantages = [
            "+ Simple hardware logic",
            "+ Fast detection",
            "+ Low resource usage",
            "+ Industry standard"
        ]
        for i, adv in enumerate(advantages):
            draw.text((x_info+10, y_adv+25+i*20), adv, fill=(0, 128, 0), font=font_text)
        
        # 保存
        output_path = 'doc/bmp_output/transparent_demo.png'
        canvas.save(output_path)
        print(f"Demonstration image created: {output_path}")
        print("You can open it to see the transparent color processing visually!")
        
        return True
        
    except Exception as e:
        print(f"Error creating demo: {e}")
        return False

if __name__ == '__main__':
    print("="*60)
    print("Creating Transparent Color Processing Demo...")
    print("="*60)
    create_comparison_demo()

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
BMP图片翻转处理程序
功能：将bmp_output目录中的所有BMP图片进行180度旋转，保存到bmp_true目录
"""

from PIL import Image
import os
import sys

# 配置路径
INPUT_DIR = '../doc/bmp_output'
OUTPUT_DIR = '../doc/bmp_true'

def ensure_output_dir():
    """确保输出目录存在"""
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"创建输出目录: {OUTPUT_DIR}")

def flip_bmp_180(input_path, output_path):
    """
    将BMP图片旋转180度（等同于上下翻转+左右翻转）
    
    Args:
        input_path: 输入BMP文件路径
        output_path: 输出BMP文件路径
    """
    try:
        # 打开图片
        img = Image.open(input_path)
        print(f"\n处理: {os.path.basename(input_path)}")
        print(f"  原始尺寸: {img.size}")
        
        # 旋转180度
        img_flipped = img.rotate(180, expand=True)
        
        # 保存为BMP
        img_flipped.save(output_path, 'BMP')
        
        # 获取文件大小
        file_size = os.path.getsize(output_path)
        print(f"  保存为: {os.path.basename(output_path)}")
        print(f"  文件大小: {file_size / 1024:.2f} KB")
        print(f"  [OK] 翻转成功")
        
        return True
    except Exception as e:
        print(f"  [ERROR] 处理失败: {e}")
        return False

def main():
    """主函数"""
    print("="*60)
    print("BMP图片翻转处理工具 (180°旋转)")
    print("="*60)
    
    # 确保输出目录存在
    ensure_output_dir()
    
    # 检查输入目录是否存在
    if not os.path.exists(INPUT_DIR):
        print(f"\n[错误] 输入目录不存在: {INPUT_DIR}")
        sys.exit(1)
    
    # 获取所有BMP文件
    bmp_files = sorted([f for f in os.listdir(INPUT_DIR) if f.lower().endswith('.bmp')])
    
    if not bmp_files:
        print(f"\n[警告] 在 {INPUT_DIR} 中没有找到BMP文件")
        sys.exit(0)
    
    print(f"\n找到 {len(bmp_files)} 个BMP文件")
    print("-"*60)
    
    # 处理所有BMP文件
    success_count = 0
    for bmp_file in bmp_files:
        input_path = os.path.join(INPUT_DIR, bmp_file)
        output_path = os.path.join(OUTPUT_DIR, bmp_file)
        
        if flip_bmp_180(input_path, output_path):
            success_count += 1
    
    # 统计结果
    print("\n" + "="*60)
    print("处理完成!")
    print("="*60)
    print(f"成功处理: {success_count}/{len(bmp_files)} 个文件")
    print(f"输入目录: {INPUT_DIR}")
    print(f"输出目录: {OUTPUT_DIR}")
    
    # 列出所有生成的文件
    print("\n生成的BMP文件列表:")
    output_files = sorted([f for f in os.listdir(OUTPUT_DIR) if f.lower().endswith('.bmp')])
    total_size = 0
    for idx, filename in enumerate(output_files, 1):
        filepath = os.path.join(OUTPUT_DIR, filename)
        size = os.path.getsize(filepath)
        total_size += size
        print(f"  {idx}. {filename:<30} ({size/1024:>8.2f} KB)")
    
    print(f"\n总大小: {total_size / (1024*1024):.2f} MB")
    print("\n" + "="*60)
    print("提示:")
    print("1. 所有BMP图片已完成180度旋转")
    print("2. 旋转效果等同于上下翻转+左右翻转")
    print("3. 结果保存在 doc/bmp_true 目录中")
    print("="*60)

if __name__ == '__main__':
    main()

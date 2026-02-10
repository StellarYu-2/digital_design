#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
BMP图片左右翻转程序
功能：对bmp_true目录中的所有BMP图片进行左右翻转，覆盖原文件
"""

from PIL import Image
import os
import sys

# 配置路径
TARGET_DIR = '../doc/bmp_true'

def flip_bmp_horizontal(file_path):
    """
    将BMP图片进行左右翻转，覆盖原文件
    
    Args:
        file_path: BMP文件路径
    """
    try:
        # 打开图片
        img = Image.open(file_path)
        print(f"\n处理: {os.path.basename(file_path)}")
        print(f"  原始尺寸: {img.size}")
        
        # 左右翻转
        img_flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
        
        # 覆盖保存为BMP
        img_flipped.save(file_path, 'BMP')
        
        # 获取文件大小
        file_size = os.path.getsize(file_path)
        print(f"  文件大小: {file_size / 1024:.2f} KB")
        print(f"  [OK] 左右翻转成功")
        
        return True
    except Exception as e:
        print(f"  [ERROR] 处理失败: {e}")
        return False

def main():
    """主函数"""
    print("="*60)
    print("BMP图片左右翻转工具")
    print("="*60)
    
    # 检查目标目录是否存在
    if not os.path.exists(TARGET_DIR):
        print(f"\n[错误] 目标目录不存在: {TARGET_DIR}")
        sys.exit(1)
    
    # 获取所有BMP文件
    bmp_files = sorted([f for f in os.listdir(TARGET_DIR) if f.lower().endswith('.bmp')])
    
    if not bmp_files:
        print(f"\n[警告] 在 {TARGET_DIR} 中没有找到BMP文件")
        sys.exit(0)
    
    print(f"\n找到 {len(bmp_files)} 个BMP文件")
    print(f"目标目录: {TARGET_DIR}")
    print("-"*60)
    
    # 处理所有BMP文件
    success_count = 0
    for bmp_file in bmp_files:
        file_path = os.path.join(TARGET_DIR, bmp_file)
        
        if flip_bmp_horizontal(file_path):
            success_count += 1
    
    # 统计结果
    print("\n" + "="*60)
    print("处理完成!")
    print("="*60)
    print(f"成功处理: {success_count}/{len(bmp_files)} 个文件")
    print(f"所有文件已进行左右翻转并覆盖原文件")
    
    # 列出所有处理后的文件
    print("\n处理后的BMP文件列表:")
    total_size = 0
    for idx, filename in enumerate(bmp_files, 1):
        filepath = os.path.join(TARGET_DIR, filename)
        size = os.path.getsize(filepath)
        total_size += size
        print(f"  {idx}. {filename:<30} ({size/1024:>8.2f} KB)")
    
    print(f"\n总大小: {total_size / (1024*1024):.2f} MB")
    print("\n" + "="*60)
    print("提示:")
    print("1. 所有BMP图片已完成左右翻转")
    print("2. 原文件已被覆盖")
    print("="*60)

if __name__ == '__main__':
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
BMP文件预览工具
快速查看转换后的BMP文件效果
"""

from PIL import Image
import os

def preview_bmp(bmp_path):
    """预览BMP文件"""
    try:
        img = Image.open(bmp_path)
        print(f"\nFile: {os.path.basename(bmp_path)}")
        print(f"Size: {img.size}")
        print(f"Mode: {img.mode}")
        print(f"Format: {img.format}")
        
        # 显示图片（需要图形界面）
        img.show()
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    """主函数"""
    bmp_dir = 'doc/bmp_output'
    
    print("="*60)
    print("BMP File Preview Tool")
    print("="*60)
    
    # 获取所有BMP文件
    bmp_files = sorted([f for f in os.listdir(bmp_dir) if f.endswith('.bmp')])
    
    if not bmp_files:
        print("No BMP files found!")
        return
    
    print(f"\nFound {len(bmp_files)} BMP files:\n")
    for idx, filename in enumerate(bmp_files, 1):
        print(f"{idx}. {filename}")
    
    print("\nOptions:")
    print("  Enter number (1-8) to preview a file")
    print("  Enter 'a' to preview all files")
    print("  Enter 'q' to quit")
    
    while True:
        choice = input("\nYour choice: ").strip().lower()
        
        if choice == 'q':
            break
        elif choice == 'a':
            for filename in bmp_files:
                filepath = os.path.join(bmp_dir, filename)
                preview_bmp(filepath)
                input("Press Enter to continue...")
        elif choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(bmp_files):
                filepath = os.path.join(bmp_dir, bmp_files[idx])
                preview_bmp(filepath)
            else:
                print("Invalid number!")
        else:
            print("Invalid choice!")

if __name__ == '__main__':
    main()

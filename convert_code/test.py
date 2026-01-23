from PIL import Image
import os

def mirror_bmp(input_path, output_path, direction='horizontal'):
    """
    读取BMP图片并进行镜像翻转。
    
    参数:
    input_path (str): 原图片路径
    output_path (str): 保存图片的路径
    direction (str): 'horizontal' (水平) 或 'vertical' (垂直)
    """
    try:
        # 1. 打开图片
        img = Image.open(input_path)
        
        # 检查是否为 BMP 格式 (虽然 PIL 支持多种格式，但这里确认一下)
        if img.format != 'BMP':
            print(f"提示: 输入的文件格式是 {img.format}，将作为 BMP 保存。")

        # 2. 根据方向进行翻转
        if direction == 'horizontal':
            # 左右镜像 
            mirrored_img = img.transpose(Image.FLIP_LEFT_RIGHT)
            print("正在进行水平镜像...")
        elif direction == 'vertical':
            # 上下镜像
            mirrored_img = img.transpose(Image.FLIP_TOP_BOTTOM)
            print("正在进行垂直镜像...")
        else:
            print("错误: 方向参数必须是 'horizontal' 或 'vertical'")
            return

        # 3. 保存图片
        mirrored_img.save(output_path, format='BMP')
        print(f"成功！已将镜像图片保存至: {output_path}")

    except FileNotFoundError:
        print(f"错误: 找不到文件 {input_path}")
    except Exception as e:
        print(f"发生未知错误: {e}")

# --- 使用示例 ---

if __name__ == "__main__":
    # 请将这里替换为你实际的图片文件名
    input_file = "start_screen.bmp"
    output_file = "start_screen_test.bmp"

    # 创建一个简单的测试图片（如果你没有现成的图片）
    if not os.path.exists(input_file):
        print(f"未找到 {input_file}，正在创建一个测试图片...")
        test_img = Image.new('RGB', (100, 100), color = 'red')
        for i in range(50): # 画一些线条以便看出镜像效果
             test_img.putpixel((i, i), (255, 255, 255))
        test_img.save(input_file)

    # 执行镜像
    mirror_bmp(input_file, output_file, direction='horizontal')
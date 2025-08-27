import json
import mysql.connector
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os
from datetime import datetime
import threading

# 数据库连接配置
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'yjz147',
    'database': 'imageqawork'
}

# 难度映射字典
DIFFICULTY_MAP = {
    "简单": 0,
    "中等": 1
    # 可以根据需要添加更多难度级别映射
}

# 固定时间戳
FIXED_TIMESTAMP = "2025-08-26 09:30:00"

def select_json_file():
    """打开文件选择器选择JSON文件"""
    root = tk.Tk()
    root.withdraw()  # 隐藏主窗口
    file_path = filedialog.askopenfilename(
        title="选择JSON文件",
        filetypes=[("JSON文件", "*.json"), ("所有文件", "*.*")]
    )
    root.destroy()
    return file_path

def process_json_data(json_data):
    """处理JSON数据，转换为数据库插入格式"""
    processed_data = []
    
    for item in json_data:
        # 提取文件名（去掉路径）
        file_name = os.path.basename(item["image_1"])
        
        # 构建path字段
        path = f"img/common_reasoning（常识推理）/{file_name}"
        
        # 转换难度
        difficulty = DIFFICULTY_MAP.get(item["text_QA_diff"], 0)  # 默认值为0
        
        # 构建插入数据
        processed_item = {
            'fileName': file_name,
            'category': 'common_reasoning（常识推理）',
            'collector_type': item["text_image_type"],
            'question_direction': item["text_QA_direction"],
            'difficulty': difficulty,
            'path': path,
            'state': 0,
            'created_at': FIXED_TIMESTAMP,
            'updated_at': FIXED_TIMESTAMP,
            'originatorID': 1,
            'checkImageListID': None,
            'workID': None,
            'question': item["text_question"],
            'answer': item["text_answer"]
        }
        
        processed_data.append(processed_item)
    
    return processed_data

def import_to_database(data, progress_callback=None):
    """将数据导入数据库"""
    try:
        # 连接数据库
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # 准备SQL语句
        sql = """
        INSERT INTO image 
        (fileName, category, collector_type, question_direction, difficulty, path, 
         state, created_at, updated_at, originatorID, checkImageListID, workID, question, answer)
        VALUES 
        (%(fileName)s, %(category)s, %(collector_type)s, %(question_direction)s, %(difficulty)s, %(path)s,
         %(state)s, %(created_at)s, %(updated_at)s, %(originatorID)s, %(checkImageListID)s, %(workID)s, %(question)s, %(answer)s)
        """
        
        # 逐条插入数据并更新进度
        total = len(data)
        for i, item in enumerate(data):
            cursor.execute(sql, item)
            if progress_callback:
                progress_callback(i + 1, total)
        
        # 提交事务
        conn.commit()
        
        # 关闭连接
        cursor.close()
        conn.close()
        
        return True, f"成功导入 {total} 条数据"
        
    except Exception as e:
        return False, f"导入失败: {str(e)}"

def create_progress_window():
    """创建进度显示窗口"""
    root = tk.Tk()
    root.title("数据导入进度")
    root.geometry("400x150")
    
    # 进度标签
    label = tk.Label(root, text="正在导入数据...")
    label.pack(pady=10)
    
    # 进度条
    progress = ttk.Progressbar(root, orient="horizontal", length=300, mode="determinate")
    progress.pack(pady=10)
    
    # 进度百分比
    percent_label = tk.Label(root, text="0%")
    percent_label.pack()
    
    return root, progress, label, percent_label

def update_progress(progress, percent_label, value, total):
    """更新进度条和百分比标签"""
    progress["value"] = (value / total) * 100
    percent_label.config(text=f"{int((value / total) * 100)}%")
    progress.update_idletasks()

def main():
    # 选择JSON文件
    json_file_path = select_json_file()
    if not json_file_path:
        messagebox.showinfo("信息", "未选择文件，程序退出")
        return
    
    try:
        # 读取JSON文件
        with open(json_file_path, 'r', encoding='utf-8') as f:
            json_data = json.load(f)
        
        # 处理数据
        processed_data = process_json_data(json_data)
        
        # 创建进度窗口
        progress_window, progress_bar, status_label, percent_label = create_progress_window()
        
        # 在单独线程中执行数据库导入
        def import_thread():
            success, message = import_to_database(
                processed_data, 
                lambda current, total: update_progress(progress_bar, percent_label, current, total)
            )
            
            # 关闭进度窗口
            progress_window.after(0, progress_window.destroy)
            
            # 显示结果
            if success:
                messagebox.showinfo("成功", message)
            else:
                messagebox.showerror("错误", message)
        
        # 启动导入线程
        thread = threading.Thread(target=import_thread)
        thread.daemon = True
        thread.start()
        
        # 显示进度窗口
        progress_window.mainloop()
        
    except Exception as e:
        messagebox.showerror("错误", f"处理文件时出错: {str(e)}")

if __name__ == "__main__":
    main()
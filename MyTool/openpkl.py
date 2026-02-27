import pickle
import pandas as pd
from pprint import pprint

# 1. 先查看文件结构
with open('cdc_pickle_pass_fpd7.pkl', 'rb') as f:
    data = pickle.load(f)

print("=" * 50)
print("文件数据类型:", type(data))
print("=" * 50)

# 2. 根据数据类型处理
if isinstance(data, dict):
    print("这是一个字典，包含以下键:", list(data.keys()))
    print("\n各键对应的数据类型:")
    for key, value in data.items():
        print(f"  {key}: {type(value)}")
    
    # 如果是DataFrame或可转换为表格的数据
    for key, value in data.items():
        if isinstance(value, pd.DataFrame):
            print(f"\n=== {key} (DataFrame) ===")
            print(value.head())
        elif isinstance(value, list) and len(value) > 0:
            print(f"\n=== {key} (列表，前3个元素) ===")
            pprint(value[:3])
        elif isinstance(value, dict) and len(value) <= 10:
            print(f"\n=== {key} (字典) ===")
            pprint(value)
            
elif isinstance(data, list):
    print(f"这是一个列表，包含 {len(data)} 个元素")
    if len(data) > 0:
        print("\n第一个元素的类型:", type(data[0]))
        print("\n前3个元素:")
        pprint(data[:3])
        
elif isinstance(data, pd.DataFrame):
    print("这是一个pandas DataFrame")
    print(f"形状: {data.shape}")
    print("\n前5行数据:")
    print(data.head())
    print("\n列名:", list(data.columns))
else:
    print("数据内容:")
    pprint(data, depth=2)
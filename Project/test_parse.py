#!/usr/bin/env python3
import json
import pandas as pd
import numpy as np

def parse_response_body(x):
    """将 response_body 解析为 dict。"""
    if x is None:
        return {}
    if isinstance(x, dict):
        return x
    if not isinstance(x, str):
        x = str(x)
    x = x.strip()
    if not x:
        return {}
    try:
        obj = json.loads(x)
        # 有时可能是双层 json 字符串
        if isinstance(obj, str):
            obj = json.loads(obj)
        return obj if isinstance(obj, dict) else {}
    except json.JSONDecodeError as e:
        print(f"JSON解析错误: {e}")
        print(f"内容: {x[:100]}")
        return {}

# 测试
df = pd.read_pickle('cdc灰度验证.pkl')

print(f"总样本数: {len(df)}")

# 测试解析
consultas_count = 0
errores_count = 0
empty_count = 0

for idx, rb in enumerate(df['response_body']):
    obj = parse_response_body(rb)
    
    if 'consultas' in obj:
        consultas_count += 1
    elif 'errores' in obj:
        errores_count += 1
    else:
        empty_count += 1

print(f"\n解析结果:")
print(f"包含 consultas: {consultas_count}")
print(f"包含 errores: {errores_count}")
print(f"空对象: {empty_count}")

print("\n前3条解析结果:")
for i in range(min(3, len(df))):
    obj = parse_response_body(df['response_body'].iloc[i])
    print(f"{i}: keys={list(obj.keys())}")

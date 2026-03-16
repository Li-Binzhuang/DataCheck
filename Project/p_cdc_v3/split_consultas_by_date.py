"""
按 create_time 日期拆分 creditos_features_cdc_v3_up.csv
输出到 outputs/creditos_by_date/ 目录下，文件名格式: creditos_MMDD.csv
"""
import pandas as pd
import os

INPUT_FILE = os.path.join(os.path.dirname(__file__), 'creditos_features_cdc_v3_up.csv')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'outputs', 'creditos_by_date')

os.makedirs(OUTPUT_DIR, exist_ok=True)

print(f'读取文件: {INPUT_FILE}')
df = pd.read_csv(INPUT_FILE)
print(f'总行数: {len(df)}')

# 提取日期部分
df['_date'] = pd.to_datetime(df['create_time']).dt.date

dates = sorted(df['_date'].unique())
print(f'共包含 {len(dates)} 个日期: {dates}')

for d in dates:
    sub = df[df['_date'] == d].drop(columns=['_date'])
    fname = f"creditos_{d.strftime('%m%d')}.csv"
    out_path = os.path.join(OUTPUT_DIR, fname)
    sub.to_csv(out_path, index=False)
    print(f'  {fname} -> {len(sub)} 条')

print('拆分完成')

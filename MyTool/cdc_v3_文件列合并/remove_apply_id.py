import pandas as pd 
from pathlib import Path

script_dir = Path(__file__).parent
# input_dir = script_dir / "sms_v3/0303"
# 读取 CSV 文件

# script_dir / "sms_v3/0303"
df = pd.read_csv(script_dir/'sms_v3_merged/sms_v3_all_merged_0302_v1.csv')

# 删除 apply_id 列

df = df.drop(columns=['apply_id'])

# 保存为新文件
df.to_csv(script_dir/'sms_v3_all_merged_0302_v1_test.csv', index=False)

print("完成！已删除 apply_id 列，保存为 sms_v3_all_merged_0302_v1_test.csv")

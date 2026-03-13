#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
特征对比脚本 - 流式处理大文件
对比样本特征数据和接口返回的特征数据
优化版本：解决碎片化警告，优化内存使用
"""

import pandas as pd
import numpy as np
import csv
import os
import gc
from collections import defaultdict
import sys
import math
# import psutil
import time


def get_memory_usage():
    """获取当前内存使用情况 - 简化版"""
    return 0  # 返回0表示未知

def print_memory_usage(prefix=""):
    """打印内存使用情况 - 跳过"""
    # 如果想显示基本信息，可以取消下面这行的注释
    # print(f"{prefix} 内存监控已跳过（未安装psutil）")
    pass  # 什么都不做

def optimize_dtypes(df):
    """优化DataFrame的数据类型以减少内存使用"""
    start_memory = get_memory_usage()

    # 优化整数类型
    for col in df.select_dtypes(include=['int64']).columns:
        col_min = df[col].min()
        col_max = df[col].max()
        if col_min >= 0:
            if col_max < 2 ** 8:
                df[col] = df[col].astype('uint8')
            elif col_max < 2 ** 16:
                df[col] = df[col].astype('uint16')
            elif col_max < 2 ** 32:
                df[col] = df[col].astype('uint32')
        else:
            if col_min > -2 ** 7 and col_max < 2 ** 7 - 1:
                df[col] = df[col].astype('int8')
            elif col_min > -2 ** 15 and col_max < 2 ** 15 - 1:
                df[col] = df[col].astype('int16')
            elif col_min > -2 ** 31 and col_max < 2 ** 31 - 1:
                df[col] = df[col].astype('int32')

    # 优化浮点类型
    for col in df.select_dtypes(include=['float64']).columns:
        df[col] = pd.to_numeric(df[col], downcast='float')

    # 优化对象类型（字符串）
    for col in df.select_dtypes(include=['object']).columns:
        if col not in ['cust_no', 'create_time', 'key']:  # 主键列保持原样
            num_unique = df[col].nunique()
            if num_unique / len(df) < 0.5:  # 如果重复率较高
                df[col] = df[col].astype('category')

    saved_memory = start_memory - get_memory_usage()
    print(f"  数据类型优化后节省内存: {saved_memory:.2f} MB")
    return df


def read_csv_in_chunks(file_path, chunk_size=1000, usecols=None, dtype=None):
    """分块读取CSV文件"""
    return pd.read_csv(file_path, chunksize=chunk_size, usecols=usecols, dtype=dtype, low_memory=False)


def is_value_equal(val1, val2, tolerance=0.0001):
    """
    判断两个值是否一致
    0和NaN, -999和空 都认为一致
    差异值在tolerance以内也认为一致
    """
    # 处理NaN的情况
    if pd.isna(val1) and pd.isna(val2):
        return True
    if pd.isna(val1) and (pd.isna(val2) or val2 == '' or val2 == 0 or val2 == -999):
        return True
    if pd.isna(val2) and (pd.isna(val1) or val1 == '' or val1 == 0 or val1 == -999):
        return True

    # 处理空字符串
    if val1 == '' and (val2 == '' or pd.isna(val2) or val2 == 0 or val2 == -999):
        return True
    if val2 == '' and (val1 == '' or pd.isna(val1) or val1 == 0 or val1 == -999):
        return True

    # 处理0和-999
    try:
        f1 = float(val1)
        f2 = float(val2)

        # 处理0和-999的特殊情况
        if (f1 == 0 and (f2 == 0 or pd.isna(val2) or val2 == '' or f2 == -999)):
            return True
        if (f1 == -999 and (f2 == -999 or pd.isna(val2) or val2 == '' or f2 == 0)):
            return True
        if (f2 == 0 and (f1 == 0 or pd.isna(val1) or val1 == '' or f1 == -999)):
            return True
        if (f2 == -999 and (f1 == -999 or pd.isna(val1) or val1 == '' or f1 == 0)):
            return True

        # 计算差异值
        diff = abs(f1 - f2)

        # 如果差异在容差范围内，认为一致
        if diff <= tolerance:
            return True

        # 对于大数值，也可以考虑相对误差
        if abs(f1) > 1 or abs(f2) > 1:
            if diff / max(abs(f1), abs(f2)) <= tolerance:
                return True

    except (ValueError, TypeError):
        # 如果无法转换为float，进行字符串比较
        return str(val1) == str(val2)

    return False


def print_progress(current, total, prefix='进度', start_time=None):
    """打印进度条"""
    percentage = int(100 * current / total)
    bar_length = 50
    filled_length = int(bar_length * current // total)
    bar = '█' * filled_length + '░' * (bar_length - filled_length)

    # 计算剩余时间
    elapsed_time = ""
    if start_time and current > 0:
        elapsed = time.time() - start_time
        speed = current / elapsed
        remaining = (total - current) / speed if speed > 0 else 0
        elapsed_time = f" | 已用: {elapsed:.1f}s | 剩余: {remaining:.1f}s"

    sys.stdout.write(f'\r{prefix}: |{bar}| {percentage}% ({current}/{total}){elapsed_time}')
    sys.stdout.flush()
    if current == total:
        print()


def format_value(value):
    """格式化值用于显示"""
    if pd.isna(value):
        return "NaN"
    if isinstance(value, float):
        return f"{value:.6f}"
    return str(value)


def main():
    # 文件路径
    sample_file = 'sms_v3_all_merged_0309_v1.csv' # DataBox 合并后文件
    api_file = '0309new_api_03122101_sss.csv' #接口跑数的文件

    # 输出文件
    abnormal_features_file = 'abnormal_features_detail_0309_new.csv'
    summary_file = 'comparison_summary_0309_new.csv'

    # 设置容差
    TOLERANCE = 0.0001

    print("=" * 80)
    print("特征对比脚本 - 优化版本")
    print("=" * 80)
    print_memory_usage("初始状态")
    print(f"容差设置: {TOLERANCE}")

    print("\n开始读取样本文件特征列信息...")
    # 首先读取样本文件的列名，确定特征列
    sample_cols = pd.read_csv(sample_file, nrows=0).columns.tolist()
    print(f"样本文件总列数: {len(sample_cols)}")

    # 样本文件从第7列开始为特征（索引6），前6列是其他信息
    id_cols = sample_cols[:6]  # 前6列，包含cust_no和create_time
    sample_feature_cols = sample_cols[6:]  # 特征列

    # 构建特征名映射：加上前缀和后缀
    feature_name_map = {}
    for feat in sample_feature_cols:
        mapped_name = f"local_all_sms_{feat}_v3"
        feature_name_map[feat] = mapped_name

    print(f"样本文件共有 {len(sample_feature_cols)} 个特征")

    # 读取接口文件的列名
    api_cols = pd.read_csv(api_file, nrows=0).columns.tolist()
    print(f"接口文件总列数: {len(api_cols)}")

    # 接口文件从第2列开始为特征（索引1）
    api_id_cols = api_cols[:1]  # 第1列应该是cust_no? 但我们需要确认
    api_feature_cols = api_cols[1:]  # 特征列

    print(f"接口文件共有 {len(api_feature_cols)} 个特征")

    # 找出共同特征（基于映射后的名称）
    common_features = []
    feature_mapping_reverse = {}  # 反向映射：接口特征名 -> 样本特征名

    # 先打印一些示例，帮助调试
    print("\n特征名映射示例（前5个）:")
    for sample_feat in sample_feature_cols[:5]:
        mapped_name = feature_name_map[sample_feat]
        print(f"  样本特征: {sample_feat} -> 映射后: {mapped_name}")

    print("\n接口特征示例（前5个）:")
    for api_feat in api_feature_cols[:5]:
        print(f"  接口特征: {api_feat}")

    for sample_feat, mapped_name in feature_name_map.items():
        if mapped_name in api_feature_cols:
            common_features.append(sample_feat)
            feature_mapping_reverse[mapped_name] = sample_feat

    print(f"\n共同特征数量: {len(common_features)}")

    if len(common_features) == 0:
        print("\n错误：没有找到共同特征，请检查特征名前缀后缀是否正确")
        print("请确认接口文件中的特征名格式，例如应该是: local_all_sms_xxx_v3")
        return

    print_memory_usage("读取列信息后")

    # 准备统计数据
    total_records = 0
    feature_stats = {feat: {'total': 0, 'abnormal': 0, 'within_tolerance': 0} for feat in common_features}
    abnormal_details = []

    # 读取接口文件并建立索引（因为接口文件可能较小）
    print("\n正在加载接口文件到内存...")
    print_memory_usage("加载接口文件前")

    # 优化1：指定数据类型读取
    api_df = pd.read_csv(api_file)
    print(f"接口文件原始列名: {api_df.columns.tolist()[:10]}...")

    # 优化2：优化数据类型
    print("优化接口文件数据类型...")
    api_df = optimize_dtypes(api_df)

    # 优化3：使用assign创建key列，避免碎片化
    print("创建主键列...")
    api_df = api_df.assign(
        key=api_df['cust_no'].astype(str) + '_' + api_df['create_time'].astype(str)
    )

    print(f"接口文件处理完成，共 {len(api_df)} 条记录")
    print_memory_usage("接口文件加载后")

    # 优化4：只存储需要的特征列，减少内存使用
    needed_api_features = [feature_name_map[feat] for feat in common_features]
    print(f"需要对比的特征数: {len(needed_api_features)}")

    # 优化5：使用字典存储，但只存储必要的值
    api_data_dict = {}

    print("构建快速查找索引...")
    start_time = time.time()
    for idx, row in api_df.iterrows():
        key = row['key']
        # 只存储需要的特征值，减少内存
        feature_values = {}
        for feat in needed_api_features:
            feature_values[feat] = row[feat]
        api_data_dict[key] = feature_values

        # 每10万条打印一次进度
        if (idx + 1) % 100000 == 0:
            print(f"  已处理 {idx + 1} 条接口记录...")

    print(f"索引构建完成，共 {len(api_data_dict)} 条记录，耗时: {time.time() - start_time:.2f}秒")

    # 释放api_df内存
    del api_df
    gc.collect()
    print_memory_usage("释放接口DataFrame后")

    # 流式处理样本文件
    print("\n开始流式对比样本文件...")
    chunk_size = 500  # 每批处理的行数，根据内存情况调整

    # 只读取需要的列
    usecols = id_cols + common_features
    print(f"读取样本文件的列: {len(usecols)} 列")

    # 计算总行数用于进度显示
    total_rows = sum(1 for _ in open(sample_file)) - 1  # 减去表头
    total_chunks = (total_rows + chunk_size - 1) // chunk_size
    print(f"总记录数: {total_rows:,}, 分块数: {total_chunks}")

    chunks = read_csv_in_chunks(sample_file, chunk_size=chunk_size, usecols=usecols)

    chunk_count = 0
    tolerance_count = 0  # 统计在容差范围内的记录数
    process_start_time = time.time()

    # 清空或创建异常明细文件
    if os.path.exists(abnormal_features_file):
        os.remove(abnormal_features_file)

    for chunk in chunks:
        chunk_count += 1

        # 优化6：批量创建主键，避免逐行操作
        if 'cust_no' in chunk.columns and 'create_time' in chunk.columns:
            chunk = chunk.assign(
                key=chunk['cust_no'].astype(str) + '_' + chunk['create_time'].astype(str)
            )
        else:
            print(f"警告：样本文件中未找到cust_no或create_time列")
            print(f"可用的列: {chunk.columns.tolist()}")
            # 假设前两列是主键
            chunk = chunk.assign(
                key=chunk.iloc[:, 0].astype(str) + '_' + chunk.iloc[:, 1].astype(str)
            )

        # 优化7：批量处理每条记录
        batch_abnormal = []

        for _, sample_row in chunk.iterrows():
            key = sample_row['key']
            total_records += 1

            # 在接口数据中查找对应记录
            if key in api_data_dict:
                api_values = api_data_dict[key]

                # 对比每个共同特征
                for sample_feat in common_features:
                    mapped_name = feature_name_map[sample_feat]
                    sample_value = sample_row[sample_feat]

                    # 获取接口特征值
                    api_value = api_values.get(mapped_name, np.nan)

                    # 更新统计
                    feature_stats[sample_feat]['total'] += 1

                    # 判断是否一致
                    if not is_value_equal(sample_value, api_value, TOLERANCE):
                        feature_stats[sample_feat]['abnormal'] += 1

                        # 记录异常明细
                        batch_abnormal.append({
                            'feature_name': sample_feat,
                            'mapped_name': mapped_name,
                            'cust_no': sample_row.get('cust_no', sample_row.iloc[0]),
                            'create_time': sample_row.get('create_time', sample_row.iloc[1]),
                            'sample_value': format_value(sample_value),
                            'api_value': format_value(api_value),
                            'key': key,
                            'diff_type': '超出容差范围'
                        })
                    else:
                        # 检查是否在容差范围内
                        try:
                            f1 = float(sample_value)
                            f2 = float(api_value)
                            if not pd.isna(f1) and not pd.isna(f2) and abs(f1 - f2) <= TOLERANCE and abs(f1 - f2) > 0:
                                feature_stats[sample_feat]['within_tolerance'] += 1
                                tolerance_count += 1
                        except (ValueError, TypeError):
                            pass
            else:
                # 接口中没有对应的主键记录，所有特征都记为异常
                for sample_feat in common_features:
                    feature_stats[sample_feat]['total'] += 1
                    feature_stats[sample_feat]['abnormal'] += 1

                    # 记录异常明细
                    batch_abnormal.append({
                        'feature_name': sample_feat,
                        'mapped_name': feature_name_map[sample_feat],
                        'cust_no': sample_row.get('cust_no', sample_row.iloc[0]),
                        'create_time': sample_row.get('create_time', sample_row.iloc[1]),
                        'sample_value': format_value(sample_row[sample_feat]),
                        'api_value': 'MISSING',
                        'key': key,
                        'diff_type': '接口记录缺失'
                    })

        # 保存当前批次的异常明细
        if batch_abnormal:
            temp_df = pd.DataFrame(batch_abnormal)
            if not os.path.exists(abnormal_features_file):
                temp_df.to_csv(abnormal_features_file, index=False, encoding='utf-8-sig')
            else:
                temp_df.to_csv(abnormal_features_file, mode='a', header=False, index=False, encoding='utf-8-sig')

        # 更新进度
        print_progress(chunk_count, total_chunks, '处理进度', process_start_time)

        # 每10个chunk打印一次内存使用情况
        if chunk_count % 10 == 0:
            print_memory_usage(f"\n处理 {chunk_count}/{total_chunks} 块后")

    print_memory_usage("\n处理完成后")

    # 计算异常率并保存汇总信息
    print("\n\n计算异常率...")
    summary_data = []
    total_within_tolerance = 0
    total_abnormal = 0

    for feat, stats in feature_stats.items():
        if stats['total'] > 0:
            abnormal_rate = (stats['abnormal'] / stats['total']) * 100
            tolerance_rate = (stats['within_tolerance'] / stats['total']) * 100
        else:
            abnormal_rate = 0
            tolerance_rate = 0

        total_abnormal += stats['abnormal']
        total_within_tolerance += stats['within_tolerance']

        summary_data.append({
            'feature_name': feat,
            'mapped_name': feature_name_map[feat],
            'total_records': stats['total'],
            'abnormal_count': stats['abnormal'],
            'within_tolerance_count': stats['within_tolerance'],
            'abnormal_rate': f"{abnormal_rate:.4f}%",
            'tolerance_rate': f"{tolerance_rate:.4f}%"
        })

    # 按异常率降序排序
    summary_df = pd.DataFrame(summary_data)
    summary_df = summary_df.sort_values('abnormal_rate', ascending=False)

    # 保存汇总信息
    summary_df.to_csv(summary_file, index=False, encoding='utf-8-sig')

    # 输出统计信息
    print("\n" + "=" * 80)
    print(f"对比完成！")
    print(f"总处理时间: {time.time() - process_start_time:.2f}秒")
    print_memory_usage("最终内存使用")
    print(f"总记录数: {total_records:,}")
    print(f"共同特征数: {len(common_features)}")
    print(f"容差设置: {TOLERANCE}")
    print(f"在容差范围内的记录数: {total_within_tolerance:,}")
    print(f"异常记录数: {total_abnormal:,}")
    print(f"异常明细已保存至: {abnormal_features_file}")
    print(f"异常率汇总已保存至: {summary_file}")
    print("=" * 80)

    # 显示异常率最高的10个特征
    print("\n异常率最高的10个特征:")
    display_cols = ['feature_name', 'total_records', 'abnormal_count', 'within_tolerance_count', 'abnormal_rate',
                    'tolerance_rate']
    print(summary_df.head(10)[display_cols].to_string(index=False))

    # 显示异常率统计
    abnormal_rates = [float(x.replace('%', '')) for x in summary_df['abnormal_rate']]
    tolerance_rates = [float(x.replace('%', '')) for x in summary_df['tolerance_rate']]

    if abnormal_rates:
        print(f"\n异常率统计:")
        print(f"  平均异常率: {np.mean(abnormal_rates):.4f}%")
        print(f"  中位数异常率: {np.median(abnormal_rates):.4f}%")
        print(f"  最高异常率: {np.max(abnormal_rates):.4f}%")
        print(f"  最低异常率: {np.min(abnormal_rates):.4f}%")
        print(f"  异常率为0的特征数: {sum(1 for r in abnormal_rates if r == 0)}")
        print(f"  异常率为100%的特征数: {sum(1 for r in abnormal_rates if r == 100)}")

        print(f"\n容差范围内记录统计:")
        print(f"  平均容差率: {np.mean(tolerance_rates):.4f}%")
        print(f"  最高容差率: {np.max(tolerance_rates):.4f}%")
        print(f"  有容差记录的特征数: {sum(1 for r in tolerance_rates if r > 0)}")


if __name__ == "__main__":
    main()
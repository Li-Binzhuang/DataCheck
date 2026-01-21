#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
转换接口返回数据中data字段内的特征值为数值类型
功能：将接口返回的JSON数据中data字段内的字符串特征值转换为数值类型（保留小数）
"""

import json
import os
import sys
from typing import Any, Dict, List, Optional

# 添加父目录到路径，以便导入公共工具模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# 导入公共工具模块
from common.csv_tool import read_csv_with_encoding


class FeatureValueConverter:
    """特征值转换器"""
    
    def __init__(self):
        pass
    
    def _convert_string_to_number(self, value: Any) -> Any:
        """
        将字符串值转换为数值类型（保留小数）
        
        Args:
            value: 要转换的值（可能是字符串、数字或其他类型）
        
        Returns:
            如果可以转换为数字，返回数字（float），否则返回原始值
        """
        if value is None:
            return None
        
        # 如果已经是数字类型，直接返回
        if isinstance(value, (int, float)):
            return float(value)
        
        # 如果是字符串，尝试转换为数字
        if isinstance(value, str):
            value_str = value.strip()
            
            # 处理空值和null字符串
            if not value_str or value_str.lower() in ["null", "none", "nan", "undefined", ""]:
                return None
            
            # 移除千位分隔符（逗号）
            value_str = value_str.replace(",", "")
            
            # 移除所有空白字符（包括换行符、制表符等）
            value_str = "".join(value_str.split())
            
            # 尝试转换为浮点数（支持科学计数法，保留小数）
            try:
                num_value = float(value_str)
                # 检查是否是有效的数字（不是 inf 或 nan）
                if isinstance(num_value, float) and not (num_value != num_value or num_value == float('inf') or num_value == float('-inf')):
                    return num_value
            except (ValueError, TypeError, OverflowError):
                pass
        
        # 无法转换为数字，返回原始值
        return value
    
    def convert_api_response_data(self, api_response: Dict[str, Any]) -> Dict[str, Any]:
        """
        转换接口返回数据中data字段内的特征值为数值类型
        
        Args:
            api_response: 接口返回的JSON数据
        
        Returns:
            转换后的数据（data字段内的字符串特征值已转换为数值）
        """
        if not isinstance(api_response, dict):
            return api_response
        
        # 创建转换后的响应副本
        converted_response = api_response.copy()
        
        # 如果存在data字段且是字典类型
        if "data" in converted_response and isinstance(converted_response["data"], dict):
            converted_data = {}
            converted_count = 0
            unchanged_count = 0
            
            for key, value in converted_response["data"].items():
                # 尝试将值转换为数字
                converted_value = self._convert_string_to_number(value)
                
                if isinstance(converted_value, (int, float)) and not isinstance(value, (int, float)):
                    # 成功转换为数字
                    converted_data[key] = converted_value
                    converted_count += 1
                else:
                    # 无法转换或已经是数字，保持原值
                    converted_data[key] = value
                    if not isinstance(value, (int, float)):
                        unchanged_count += 1
            
            converted_response["data"] = converted_data
            
            print(f"  转换统计: 成功转换 {converted_count} 个特征值为数值, {unchanged_count} 个保持原值")
        
        return converted_response
    
    def convert_json_file(self, input_json_path: str, output_json_path: str):
        """
        转换JSON文件中的接口返回数据
        
        Args:
            input_json_path: 输入JSON文件路径
            output_json_path: 输出JSON文件路径
        """
        print(f"\n读取JSON文件: {input_json_path}")
        
        # 读取JSON文件
        try:
            with open(input_json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"❌ 读取JSON文件失败: {str(e)}")
            return
        
        # 如果是单个响应对象
        if isinstance(data, dict):
            converted_data = self.convert_api_response_data(data)
        # 如果是响应数组
        elif isinstance(data, list):
            converted_data = []
            for item in data:
                if isinstance(item, dict):
                    converted_data.append(self.convert_api_response_data(item))
                else:
                    converted_data.append(item)
        else:
            print(f"⚠️  不支持的数据格式: {type(data)}")
            return
        
        # 写入转换后的JSON文件
        print(f"写入转换后的JSON文件: {output_json_path}")
        try:
            output_dir = os.path.dirname(output_json_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir, exist_ok=True)
            
            with open(output_json_path, 'w', encoding='utf-8') as f:
                json.dump(converted_data, f, ensure_ascii=False, indent=2)
            
            print(f"✅ JSON文件转换完成")
        except Exception as e:
            print(f"❌ 写入JSON文件失败: {str(e)}")
    
    def convert_api_data_csv(self, input_csv_path: str, output_csv_path: str, 
                             data_start_column: int = None):
        """
        转换API数据CSV文件中data字段内的特征值为数值类型
        
        Args:
            input_csv_path: 输入CSV文件路径（包含接口返回的数据）
            output_csv_path: 输出CSV文件路径
            data_start_column: data字段开始列索引（如果为None，自动检测）
        """
        print(f"\n读取CSV文件: {input_csv_path}")
        
        # 读取CSV文件
        try:
            headers, rows = read_csv_with_encoding(input_csv_path)
        except Exception as e:
            print(f"❌ 读取CSV文件失败: {str(e)}")
            return
        
        print(f"  总行数: {len(rows)}")
        print(f"  总列数: {len(headers)}")
        
        # 如果没有指定data开始列，尝试自动检测
        if data_start_column is None:
            # 查找常见的标识列（如cust_no, order_create_time等）之后的第一列
            common_columns = ['cust_no', 'order_create_time', 'use_create_time', 
                            'observation_date', 'use_credit_apply_id']
            data_start_column = len(headers)
            
            for i, header in enumerate(headers):
                if header.lower() in [col.lower() for col in common_columns]:
                    data_start_column = min(data_start_column, i + 1)
            
            if data_start_column >= len(headers):
                data_start_column = 3  # 默认从第4列开始（索引3）
        
        print(f"  特征值开始列: {data_start_column} (列名: {headers[data_start_column] if data_start_column < len(headers) else 'N/A'})")
        
        # 转换数据
        import csv
        converted_count = 0
        total_features = 0
        
        try:
            output_dir = os.path.dirname(output_csv_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir, exist_ok=True)
            
            with open(output_csv_path, 'w', encoding='utf-8', newline='') as f:
                writer = csv.writer(f)
                
                # 写入表头
                writer.writerow(headers)
                
                # 转换每一行
                for row_idx, row in enumerate(rows):
                    converted_row = list(row)
                    
                    # 从data开始列转换特征值
                    for col_idx in range(data_start_column, len(headers)):
                        if col_idx < len(row):
                            original_value = row[col_idx]
                            
                            # 跳过空值
                            if not original_value or original_value.strip() == "":
                                continue
                            
                            # 尝试转换为数值
                            converted_value = self._convert_string_to_number(original_value)
                            
                            if isinstance(converted_value, (int, float)) and not isinstance(original_value, (int, float)):
                                # 成功转换为数字，更新行数据
                                converted_row[col_idx] = str(converted_value)
                                converted_count += 1
                            
                            total_features += 1
                    
                    writer.writerow(converted_row)
                    
                    # 每1000行打印一次进度
                    if (row_idx + 1) % 1000 == 0:
                        print(f"  已处理: {row_idx + 1}/{len(rows)} 行")
            
            print(f"\n✅ CSV文件转换完成")
            print(f"  转换统计: 成功转换 {converted_count} 个特征值为数值, 总特征数: {total_features}")
            
        except Exception as e:
            print(f"❌ 写入CSV文件失败: {str(e)}")
            import traceback
            traceback.print_exc()


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='转换接口返回数据中data字段内的特征值为数值类型',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  # 转换JSON文件
  python 转换特征值为数值.py api_response.json
  
  # 转换CSV文件（自动检测特征开始列）
  python 转换特征值为数值.py api_data.csv
  
  # 转换CSV文件（指定特征开始列）
  python 转换特征值为数值.py api_data.csv --data-start-column 4
  
  # 指定输出文件
  python 转换特征值为数值.py api_data.csv -o converted_api_data.csv
        """
    )
    parser.add_argument('input_file', help='输入文件路径（JSON或CSV）')
    parser.add_argument('-o', '--output', help='输出文件路径（可选，默认在输入文件同目录下生成）')
    parser.add_argument('--data-start-column', type=int, help='CSV文件中data字段开始列索引（仅CSV文件需要，从0开始计数）')
    
    args = parser.parse_args()
    
    # 检查输入文件是否存在
    if not os.path.exists(args.input_file):
        print(f"❌ 错误: 输入文件不存在: {args.input_file}")
        return
    
    # 生成输出文件路径
    if args.output:
        output_path = args.output
    else:
        base_name = os.path.splitext(args.input_file)[0]
        ext = os.path.splitext(args.input_file)[1]
        output_path = f"{base_name}_converted{ext}"
    
    print(f"{'='*80}")
    print(f"转换接口返回数据中的特征值为数值类型")
    print(f"{'='*80}")
    print(f"输入文件: {args.input_file}")
    print(f"输出文件: {output_path}")
    
    # 创建转换器
    converter = FeatureValueConverter()
    
    # 根据文件类型进行转换
    file_ext = os.path.splitext(args.input_file)[1].lower()
    
    if file_ext == '.json':
        converter.convert_json_file(args.input_file, output_path)
    elif file_ext == '.csv':
        converter.convert_api_data_csv(args.input_file, output_path, args.data_start_column)
    else:
        print(f"❌ 不支持的文件类型: {file_ext}")
        print(f"   支持的文件类型: .json, .csv")
    
    print(f"\n{'='*80}")
    print(f"转换完成！")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试特征解析逻辑
验证 batch_runner 能够正确处理 data.features 和 data 两种结构
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from batch_run.job.batch_runner import BatchRunner


def test_extract_features():
    """测试特征提取功能"""
    
    # 创建 BatchRunner 实例（使用空配置）
    runner = BatchRunner(
        api_url="http://test.com",
        api_params=[],
        keep_columns=None,
        thread_count=1
    )
    
    print("=" * 60)
    print("测试特征提取功能")
    print("=" * 60)
    
    # 测试用例1: data.features 结构
    print("\n测试用例1: data.features 结构")
    response1 = {
        "retCode": "0000",
        "retMsg": "成功",
        "data": {
            "features": {
                "age": "30",
                "income": "50000",
                "credit_score": "750"
            },
            "apply_id": "12345",
            "timestamp": "2026-03-06"
        }
    }
    
    features1 = runner.extract_features(response1)
    print(f"提取的特征: {features1}")
    expected1 = {"age": "30", "income": "50000", "credit_score": "750"}
    assert features1 == expected1, f"期望: {expected1}, 实际: {features1}"
    print("✅ 测试通过")
    
    # 测试用例2: data 直接包含特征
    print("\n测试用例2: data 直接包含特征")
    response2 = {
        "retCode": "0000",
        "retMsg": "成功",
        "data": {
            "age": "30",
            "income": "50000",
            "credit_score": "750",
            "apply_id": "12345",
            "timestamp": "2026-03-06"
        }
    }
    
    features2 = runner.extract_features(response2)
    print(f"提取的特征: {features2}")
    expected2 = {
        "age": "30",
        "income": "50000",
        "credit_score": "750",
        "apply_id": "12345",
        "timestamp": "2026-03-06"
    }
    assert features2 == expected2, f"期望: {expected2}, 实际: {features2}"
    print("✅ 测试通过")
    
    # 测试用例3: data 为空
    print("\n测试用例3: data 为空")
    response3 = {
        "retCode": "0000",
        "retMsg": "成功",
        "data": {}
    }
    
    features3 = runner.extract_features(response3)
    print(f"提取的特征: {features3}")
    assert features3 == {}, f"期望: {{}}, 实际: {features3}"
    print("✅ 测试通过")
    
    # 测试用例4: 响应有错误
    print("\n测试用例4: 响应有错误")
    response4 = {
        "_error": "请求失败"
    }
    
    features4 = runner.extract_features(response4)
    print(f"提取的特征: {features4}")
    assert features4 == {}, f"期望: {{}}, 实际: {features4}"
    print("✅ 测试通过")
    
    # 测试用例5: features 为空字典
    print("\n测试用例5: features 为空字典")
    response5 = {
        "retCode": "0000",
        "retMsg": "成功",
        "data": {
            "features": {},
            "apply_id": "12345"
        }
    }
    
    features5 = runner.extract_features(response5)
    print(f"提取的特征: {features5}")
    assert features5 == {}, f"期望: {{}}, 实际: {features5}"
    print("✅ 测试通过")
    
    print("\n" + "=" * 60)
    print("所有测试通过！✅")
    print("=" * 60)


if __name__ == "__main__":
    test_extract_features()

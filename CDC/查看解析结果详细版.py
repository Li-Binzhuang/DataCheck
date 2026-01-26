#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
查看解析结果详细版

展示 response_body 解析后的详细内容，包括：
1. 数据统计
2. 字段列表
3. 示例数据
4. 数据质量分析
"""

import json
from pathlib import Path
import pandas as pd
import numpy as np


def main():
    """主函数"""
    
    print('='*80)
    print('CDC response_body 解析结果详细展示')
    print('='*80)
    print()
    
    # 读取 pickle 文件
    print('[1/4] 正在读取 pickle 文件...')
    df_raw = pd.read_pickle('cdc_pickle_pass_fpd7.pkl')
    
    if 'request_time' not in df_raw.columns and 'apply_time' in df_raw.columns:
        df_raw['request_time'] = df_raw['apply_time']
    
    print(f'      ✓ 读取完成，共 {len(df_raw):,} 条记录')
    print()
    
    # 解析第一个申请的 response_body 作为示例
    print('[2/4] 解析示例数据（第一个申请）...')
    first_row = df_raw.iloc[0]
    apply_id = first_row['apply_id']
    request_time = first_row['request_time']
    response_body = first_row['response_body']
    
    print(f'      apply_id: {apply_id}')
    print(f'      request_time: {request_time}')
    print()
    
    # 解析 JSON
    if isinstance(response_body, str):
        obj = json.loads(response_body)
    else:
        obj = response_body
    
    # 显示 JSON 结构
    print('[3/4] response_body 结构分析：')
    print('      ' + '-'*70)
    
    for key in obj.keys():
        value = obj[key]
        if isinstance(value, list):
            print(f'      {key:20s} : list, 长度 = {len(value)}')
            if len(value) > 0 and isinstance(value[0], dict):
                print(f'      {"":20s}   └─ 每条记录有 {len(value[0])} 个字段')
        elif isinstance(value, dict):
            print(f'      {key:20s} : dict, {len(value)} 个字段')
        else:
            print(f'      {key:20s} : {type(value).__name__}')
    
    print('      ' + '-'*70)
    print()
    
    # 详细展示各板块
    print('[4/4] 各板块详细内容：')
    print()
    
    # consultas
    print('  ┌─ consultas（查询记录）')
    print('  │')
    consultas = obj.get('consultas', [])
    print(f'  │  记录数: {len(consultas)}')
    if len(consultas) > 0:
        print(f'  │  字段列表:')
        for i, field in enumerate(consultas[0].keys(), 1):
            print(f'  │    {i:2d}. {field}')
        print(f'  │')
        print(f'  │  示例记录（第1条）:')
        for key, value in consultas[0].items():
            print(f'  │    {key:30s} = {value}')
    print('  │')
    print()
    
    # creditos
    print('  ┌─ creditos（信贷账户）')
    print('  │')
    creditos = obj.get('creditos', [])
    print(f'  │  记录数: {len(creditos)}')
    if len(creditos) > 0:
        print(f'  │  字段列表:')
        for i, field in enumerate(creditos[0].keys(), 1):
            print(f'  │    {i:2d}. {field}')
        print(f'  │')
        print(f'  │  示例记录（第1条）:')
        for key, value in creditos[0].items():
            # 截断过长的值
            if isinstance(value, str) and len(value) > 50:
                value = value[:50] + '...'
            print(f'  │    {key:30s} = {value}')
    print('  │')
    print()
    
    # empleos
    print('  ┌─ empleos（工作记录）')
    print('  │')
    empleos = obj.get('empleos', [])
    print(f'  │  记录数: {len(empleos)}')
    if len(empleos) > 0:
        print(f'  │  字段列表:')
        for i, field in enumerate(empleos[0].keys(), 1):
            print(f'  │    {i:2d}. {field}')
        print(f'  │')
        print(f'  │  示例记录（第1条）:')
        for key, value in empleos[0].items():
            print(f'  │    {key:30s} = {value}')
    else:
        print(f'  │  （无工作记录）')
    print('  │')
    print()
    
    # domicilios
    print('  ┌─ domicilios（住址记录）')
    print('  │')
    domicilios = obj.get('domicilios', [])
    print(f'  │  记录数: {len(domicilios)}')
    if len(domicilios) > 0:
        print(f'  │  字段列表:')
        for i, field in enumerate(domicilios[0].keys(), 1):
            print(f'  │    {i:2d}. {field}')
        print(f'  │')
        print(f'  │  示例记录（第1条）:')
        for key, value in domicilios[0].items():
            print(f'  │    {key:30s} = {value}')
    print('  │')
    print()
    
    # 统计所有申请的数据分布
    print('='*80)
    print('全量数据统计（所有 12546 个申请）')
    print('='*80)
    print()
    
    total_consultas = 0
    total_creditos = 0
    total_empleos = 0
    total_domicilios = 0
    
    consultas_dist = []
    creditos_dist = []
    empleos_dist = []
    domicilios_dist = []
    
    print('正在统计全量数据...')
    for idx, row in df_raw.iterrows():
        if idx % 1000 == 0:
            print(f'  进度: {idx}/{len(df_raw)}')
        
        response_body = row.get('response_body')
        if pd.isna(response_body):
            continue
        
        try:
            if isinstance(response_body, str):
                obj = json.loads(response_body)
            else:
                obj = response_body
        except:
            continue
        
        consultas = obj.get('consultas', [])
        creditos = obj.get('creditos', [])
        empleos = obj.get('empleos', [])
        domicilios = obj.get('domicilios', [])
        
        consultas_cnt = len(consultas) if isinstance(consultas, list) else 0
        creditos_cnt = len(creditos) if isinstance(creditos, list) else 0
        empleos_cnt = len(empleos) if isinstance(empleos, list) else 0
        domicilios_cnt = len(domicilios) if isinstance(domicilios, list) else 0
        
        total_consultas += consultas_cnt
        total_creditos += creditos_cnt
        total_empleos += empleos_cnt
        total_domicilios += domicilios_cnt
        
        consultas_dist.append(consultas_cnt)
        creditos_dist.append(creditos_cnt)
        empleos_dist.append(empleos_cnt)
        domicilios_dist.append(domicilios_cnt)
    
    print()
    print('统计结果：')
    print('-'*80)
    print(f'{"板块":<20s} {"总记录数":>15s} {"平均/申请":>15s} {"最小值":>10s} {"最大值":>10s}')
    print('-'*80)
    print(f'{"consultas":<20s} {total_consultas:>15,} {np.mean(consultas_dist):>15.2f} {min(consultas_dist):>10} {max(consultas_dist):>10}')
    print(f'{"creditos":<20s} {total_creditos:>15,} {np.mean(creditos_dist):>15.2f} {min(creditos_dist):>10} {max(creditos_dist):>10}')
    print(f'{"empleos":<20s} {total_empleos:>15,} {np.mean(empleos_dist):>15.2f} {min(empleos_dist):>10} {max(empleos_dist):>10}')
    print(f'{"domicilios":<20s} {total_domicilios:>15,} {np.mean(domicilios_dist):>15.2f} {min(domicilios_dist):>10} {max(domicilios_dist):>10}')
    print('-'*80)
    print()
    
    print('='*80)
    print('展示完成！')
    print('='*80)


if __name__ == '__main__':
    main()

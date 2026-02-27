#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
分析 cdcjson.txt 文件的数据结构
"""
import json

def analyze_json_structure(file_path):
    """分析JSON文件的数据结构"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 尝试解析多个 JSON 对象
        json_objects = []
        decoder = json.JSONDecoder()
        idx = 0
        while idx < len(content):
            content = content[idx:].lstrip()
            if not content:
                break
            try:
                obj, end_idx = decoder.raw_decode(content)
                json_objects.append(obj)
                idx += end_idx
            except json.JSONDecodeError:
                break
        
        if not json_objects:
            print("错误: 无法解析任何 JSON 对象")
            return
        
        print(f"文件中包含 {len(json_objects)} 个 JSON 对象")
        print("=" * 80)
        
        # 分析第一个对象作为示例
        data = json_objects[0]
        
        print("=" * 80)
        print("CDC JSON 数据结构分析报告")
        print("=" * 80)
        
        # 1. 顶层字段分析
        print("\n【一、顶层字段】")
        print("-" * 80)
        for key, value in data.items():
            if key != 'response_body':  # response_body 是嵌套的 JSON 字符串
                value_type = type(value).__name__
                print(f"  {key:30s} : {value_type:15s} = {value}")
        
        # 2. response_body 解析
        print("\n【二、response_body 字段（第三方征信数据）】")
        print("-" * 80)
        if 'response_body' in data and data['response_body']:
            try:
                response_data = json.loads(data['response_body'])
                print(f"  这是一个嵌套的 JSON 字符串，包含以下字段：")
                print(f"  - claveOtorgante: {response_data.get('claveOtorgante', 'N/A')}")
                
                # 2.1 consultas 数组
                if 'consultas' in response_data:
                    consultas = response_data['consultas']
                    print(f"\n  【2.1 consultas（征信查询记录）】")
                    print(f"      数组长度: {len(consultas)} 条记录")
                    if len(consultas) > 0:
                        print(f"      每条记录的字段:")
                        for key in consultas[0].keys():
                            print(f"        - {key}")
                        print(f"\n      示例（前3条）:")
                        for i, item in enumerate(consultas[:3]):
                            print(f"        [{i+1}] {item.get('fechaConsulta')} | {item.get('nombreOtorgante')} | "
                                  f"金额:{item.get('importeCredito')} | 类型:{item.get('tipoCredito')}")
                
                # 2.2 creditos 数组
                if 'creditos' in response_data:
                    creditos = response_data['creditos']
                    print(f"\n  【2.2 creditos（信贷账户详情）】")
                    print(f"      数组长度: {len(creditos)} 条记录")
                    if len(creditos) > 0:
                        print(f"      每条记录的字段:")
                        for key in creditos[0].keys():
                            print(f"        - {key}")
                        print(f"\n      示例（前3条）:")
                        for i, item in enumerate(creditos[:3]):
                            print(f"        [{i+1}] {item.get('nombreOtorgante')} | "
                                  f"最大额度:{item.get('creditoMaximo')} | "
                                  f"当前余额:{item.get('saldoActual')} | "
                                  f"最差逾期:{item.get('peorAtraso')}")
            except json.JSONDecodeError as e:
                print(f"  解析 response_body 失败: {e}")
        
        # 3. 数据含义说明
        print("\n" + "=" * 80)
        print("【三、数据含义说明】")
        print("=" * 80)
        print("""
这是一个信贷申请的完整数据记录，包含：

1. 申请基本信息：
   - apply_id: 申请ID
   - apply_time: 申请时间
   - approve_state: 审批状态（CYCLE_PASS = 循环通过）
   - credit_limit_amount: 授信额度
   - principal_amount_borrowed: 实际借款金额
   - fpd7: First Payment Default 7天（首次还款违约标记，0=正常）

2. response_body（第三方征信局返回的数据）：
   
   2.1 consultas（征信查询记录）：
       记录了该用户在各个金融机构的征信查询历史
       - fechaConsulta: 查询日期
       - nombreOtorgante: 查询机构名称
       - importeCredito: 查询时的信贷金额
       - tipoCredito: 信贷类型（M=月付, F=固定, Q=双周, TC=信用卡等）
   
   2.2 creditos（信贷账户详情）：
       记录了该用户在各个金融机构的实际信贷账户信息
       - creditoMaximo: 该账户的最大信贷额度
       - saldoActual: 当前余额
       - saldoVencido: 逾期金额
       - peorAtraso: 最差逾期等级（0=正常, 1-9=逾期程度）
       - historicoPagos: 还款历史记录（V=正常, 01-09=逾期天数等级）
       - fechaAperturaCuenta: 账户开户日期
       - fechaCierreCuenta: 账户关闭日期

3. 用途：
   这些数据是用来进行风控特征工程的原始数据，可以从中提取：
   - 征信查询频率特征
   - 多头借贷特征
   - 逾期行为特征
   - 信贷使用率特征
   - 还款历史特征
   等等
        """)
        
        # 4. 统计信息
        print("\n" + "=" * 80)
        print("【四、关键统计信息】")
        print("=" * 80)
        if 'response_body' in data and data['response_body']:
            response_data = json.loads(data['response_body'])
            
            if 'consultas' in response_data:
                consultas = response_data['consultas']
                print(f"\n征信查询统计:")
                print(f"  - 总查询次数: {len(consultas)}")
                
                # 按机构类型统计
                tipo_count = {}
                for item in consultas:
                    tipo = item.get('tipoCredito', 'Unknown')
                    tipo_count[tipo] = tipo_count.get(tipo, 0) + 1
                print(f"  - 按类型统计:")
                for tipo, count in sorted(tipo_count.items(), key=lambda x: x[1], reverse=True):
                    print(f"      {tipo}: {count} 次")
            
            if 'creditos' in response_data:
                creditos = response_data['creditos']
                print(f"\n信贷账户统计:")
                print(f"  - 总账户数: {len(creditos)}")
                
                # 统计逾期情况
                overdue_count = sum(1 for c in creditos if c.get('peorAtraso', 0) > 0)
                active_count = sum(1 for c in creditos if c.get('saldoActual', 0) > 0)
                
                print(f"  - 有逾期记录的账户: {overdue_count}")
                print(f"  - 当前活跃账户（有余额）: {active_count}")
                
                # 总授信额度
                total_credit = sum(c.get('creditoMaximo', 0) for c in creditos)
                total_balance = sum(c.get('saldoActual', 0) for c in creditos)
                print(f"  - 历史最大授信总额: {total_credit}")
                print(f"  - 当前欠款总额: {total_balance}")
        
        print("\n" + "=" * 80)
        
    except FileNotFoundError:
        print(f"错误: 文件 {file_path} 不存在")
    except json.JSONDecodeError as e:
        print(f"错误: JSON 解析失败 - {e}")
    except Exception as e:
        print(f"错误: {e}")

if __name__ == "__main__":
    analyze_json_structure("Mytest/cdcjson.txt")

#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
检查特定 apply_id 的特征值是计算出来的还是填充的

用法：
python check_apply_id_feature.py
"""

import pandas as pd
import numpy as np
from pathlib import Path
import json

# 要检查的参数
TARGET_APPLY_ID = "1065479921833549825"
TARGET_TIME = "2025-11-24 21:45:47.808"
TARGET_FEATURE = "cdc_consultas_30d_shop_daily_cnt_mean_v2"
WINDOW_DAYS = 30  # 从特征名中提取的窗口天数

print("=" * 80)
print(f"检查 apply_id: {TARGET_APPLY_ID}")
print(f"时间: {TARGET_TIME}")
print(f"特征: {TARGET_FEATURE}")
print(f"窗口: {WINDOW_DAYS} 天")
print("=" * 80)

# 1. 读取 pickle 数据
pickle_file = Path("CDC/cdc_pickle_pass_fpd7.pkl")
if not pickle_file.exists():
    print(f"\n❌ 文件不存在: {pickle_file}")
    exit(1)

df_raw = pd.read_pickle(pickle_file)
print(f"\n✅ 读取数据: {df_raw.shape[0]} 行")

# 兼容性处理：apply_time -> request_time
if "request_time" not in df_raw.columns and "apply_time" in df_raw.columns:
    df_raw["request_time"] = df_raw["apply_time"]

# 2. 查找目标 apply_id
target_row = df_raw[df_raw["apply_id"].astype(str) == TARGET_APPLY_ID]

if len(target_row) == 0:
    print(f"\n❌ 未找到 apply_id: {TARGET_APPLY_ID}")
    exit(1)

print(f"\n✅ 找到目标记录")
target_row = target_row.iloc[0]

# 3. 解析 response_body
response_body = target_row.get("response_body")
request_time = pd.to_datetime(target_row.get("request_time"))

print(f"\n截止时间 (request_time): {request_time}")

if pd.isna(response_body) or not response_body:
    print(f"\n❌ response_body 为空 -> 命中情况 C，特征应填充 -999")
    exit(0)

try:
    data = json.loads(response_body)
except:
    print(f"\n❌ response_body 非法 JSON -> 命中情况 C，特征应填充 -999")
    exit(0)

# 4. 提取 consultas
consultas = data.get("consultas")
if not isinstance(consultas, list):
    print(f"\n❌ consultas 不存在或不是 list -> 命中情况 D，特征应填充 -999")
    exit(0)

print(f"\n✅ consultas 记录数: {len(consultas)}")

# 5. 机构归类字典
OTORGANTE_GROUP_DICT = {
    "商店信息": ["TIENDA COMERCIAL", "TIENDA DE AUTOSERVICIO", "TIENDA DEPARTAMENTAL"],
    "大众金融协会": [
        "SOCIEDADES FINANCIERAS POPULARES",
        "SOCIEDAD FINANCIERA COMUNITARIA",
        "ARRENDADORAS FINANCIERAS",
        "UNION DE CREDITO",
    ],
    "多用途": ["SOCIEDAD FINANCIERA DE OBJETO MULTIPLE"],
    "非银行抵押": ["HIPOTECARIO NO BANCARIO"],
    "服务信息": ["SALUD Y SERVICIOS MEDICOS", "SERVICIO MEDICO", "SERVS. GRALES.", "SERVICIOS"],
    "付费电视": ["SERVICIO DE TELEVISION DE PAGA"],
    "个人贷款": ["COMPANIA DE PRESTAMO PERSONAL", "SOFOL PRESTAMO PERSONAL"],
    "基金和信托": ["FONDOS Y FIDEIC", "FONDOS Y FIDEICOMISOS", "FONDOS Y FIDEICO"],
    "建筑": ["MERCANCIA PARA LA CONSTRUCCION"],
    "金融公司": ["SOFOL EMPRESARIAL", "SOFOL AUTOMOTRIZ", "OTRAS FINANCIERA", "ARRENDADORAS NO FINANCIERAS"],
    "通讯": ["TELEFONIA LOCAL Y DE LARGA DISTANCIA", "TELEFONIA CELULAR", "COMUNICACIONES"],
    "销售": ["VENTA POR CATALOGO"],
    "小额贷款": ["MIC CREDITO PERS", "MICROFINANCIERA"],
    "银行": ["BANCOS", "BANCO"],
    "非银行": ["FINANCIERA"],
    "政府": ["GUBERNAMENTALES", "GOBIERNO", "HIPOTECAGOBIERNO"],
    "个征信机构": ["SIC"],
}

VALUE_TO_GROUP = {raw: g for g, vals in OTORGANTE_GROUP_DICT.items() for raw in vals}

def map_otorgante_group(nombre_otorgante):
    if pd.isna(nombre_otorgante):
        return "其他"
    nombre_str = str(nombre_otorgante).strip().upper()
    return VALUE_TO_GROUP.get(nombre_str, "其他")

# 6. 平铺 consultas 并计算 days_before_request
consultas_list = []
for c in consultas:
    fecha_consulta = c.get("fechaConsulta")
    nombre_otorgante = c.get("nombreOtorgante")
    
    # 解析日期
    fecha_consulta_dt = pd.to_datetime(fecha_consulta, errors="coerce")
    
    if pd.notna(fecha_consulta_dt):
        days_before_request = (request_time - fecha_consulta_dt).total_seconds() / 86400
    else:
        days_before_request = None
    
    # 机构归类
    otorgante_group = map_otorgante_group(nombre_otorgante)
    
    consultas_list.append({
        "fechaConsulta": fecha_consulta,
        "fechaConsulta_dt": fecha_consulta_dt,
        "nombreOtorgante": nombre_otorgante,
        "otorgante_group": otorgante_group,
        "days_before_request": days_before_request
    })

df_consultas = pd.DataFrame(consultas_list)

print(f"\n平铺后的 consultas 记录数: {len(df_consultas)}")

# 7. 筛选窗口内的记录
df_window = df_consultas[
    (df_consultas["days_before_request"].notna()) &
    (df_consultas["days_before_request"] >= 0) &
    (df_consultas["days_before_request"] <= WINDOW_DAYS)
]

print(f"\n{WINDOW_DAYS} 天窗口内的记录数: {len(df_window)}")

if len(df_window) > 0:
    print(f"\n窗口内所有记录的机构类别分布:")
    print(df_window["otorgante_group"].value_counts().to_string())
    print(f"\n窗口内所有记录明细:")
    print(df_window[["fechaConsulta", "nombreOtorgante", "otorgante_group", "days_before_request"]].to_string(index=False))

# 8. 筛选 shop 类别的记录
df_shop = df_window[df_window["otorgante_group"] == "商店信息"]

print(f"\n{WINDOW_DAYS} 天窗口内 shop 类别的记录数: {len(df_shop)}")

if len(df_shop) > 0:
    print(f"\nshop 类别的查询明细:")
    print(df_shop[["fechaConsulta", "nombreOtorgante", "days_before_request"]].to_string(index=False))

# 9. 计算 daily_cnt_mean
print(f"\n{'=' * 80}")
print(f"计算 {TARGET_FEATURE}:")
print(f"{'=' * 80}")

if len(df_shop) == 0:
    print(f"\n结论: 窗口内没有 shop 类别的查询记录")
    print(f"根据代码逻辑（第839行）:")
    print(f"  if len(sub_cat_day) == 0:")
    print(f"      daily_mean = pd.DataFrame(-999, ...)")
    print(f"\n✅ 特征值应该是: -999 (填充值)")
    print(f"\n⚠️  但你说实际值是 0.0，这说明:")
    print(f"   1. 可能使用的是旧版本代码（填充 0.0）")
    print(f"   2. 或者数据是用旧代码生成的")
else:
    # 计算每天的查询次数
    df_shop_day = df_shop.copy()
    df_shop_day["day_bin"] = np.floor(df_shop_day["days_before_request"]).astype(int)
    df_shop_day = df_shop_day[(df_shop_day["day_bin"] >= 0) & (df_shop_day["day_bin"] < WINDOW_DAYS)]
    
    if len(df_shop_day) == 0:
        print(f"\n结论: 虽然有 shop 记录，但 day_bin 筛选后为空")
        print(f"✅ 特征值应该是: -999 (填充值)")
    else:
        day_counts = df_shop_day.groupby("day_bin").size()
        total_cnt = day_counts.sum()
        daily_cnt_mean = total_cnt / float(WINDOW_DAYS)
        
        print(f"\n每天的查询次数分布:")
        print(day_counts.to_string())
        print(f"\n总查询次数: {total_cnt}")
        print(f"窗口天数: {WINDOW_DAYS}")
        print(f"daily_cnt_mean = {total_cnt} / {WINDOW_DAYS} = {daily_cnt_mean}")
        
        print(f"\n✅ 特征值应该是: {daily_cnt_mean} (计算值)")
        
        if daily_cnt_mean == 0.0:
            print(f"\n⚠️  计算结果确实是 0.0，这是因为:")
            print(f"   total_cnt = {total_cnt}")
            print(f"   {total_cnt} / {WINDOW_DAYS} = {daily_cnt_mean}")

print(f"\n{'=' * 80}")
print(f"检查完成")
print(f"{'=' * 80}")

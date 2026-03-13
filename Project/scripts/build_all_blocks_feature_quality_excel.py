#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
特征质量评估工具模块
用于计算 IV、PSI、相关性等指标
"""

import numpy as np
import pandas as pd

try:
    from scipy.stats import pearsonr
except ImportError:
    # 如果没有 scipy，使用 numpy 实现简单的相关系数
    def pearsonr(x, y):
        if len(x) != len(y) or len(x) < 2:
            return (np.nan, np.nan)
        x_mean = np.mean(x)
        y_mean = np.mean(y)
        numerator = np.sum((x - x_mean) * (y - y_mean))
        x_std = np.std(x, ddof=1)
        y_std = np.std(y, ddof=1)
        if x_std == 0 or y_std == 0:
            return (np.nan, np.nan)
        denominator = (len(x) - 1) * x_std * y_std
        corr = numerator / denominator if denominator != 0 else np.nan
        return (corr, np.nan)

# 常量定义
SENTINEL = -999  # 空值哨兵值
IV_Q = 10  # IV 分箱：分位数箱数
PSI_Q = 10  # PSI 分箱：分位数箱数
EPS = 1e-6  # 极小值，避免除零


def _strip_feature_name(feature_name: str) -> str:
    """
    去除特征名的前后缀
    例如：cdc_{base}_v2 -> {base}
    例如：cdc_{base}_607 -> {base}
    """
    name = str(feature_name).strip()
    
    # 去除 cdc_ 前缀
    if name.startswith("cdc_"):
        name = name[4:]
    
    # 去除 _v2, _v3 等后缀
    if "_v" in name:
        parts = name.rsplit("_v", 1)
        if len(parts) == 2 and parts[1].isdigit():
            name = parts[0]
    
    # 去除其他常见后缀
    for suffix in ["_607", "_block1", "_block2", "_block3"]:
        if name.endswith(suffix):
            name = name[:-len(suffix)]
    
    return name


def _iv_one(x: pd.Series, y: pd.Series) -> float:
    """
    计算单个特征的 IV 值
    """
    dfv = pd.DataFrame({"x": x, "y": y}).dropna(subset=["y"])
    if dfv.shape[0] == 0:
        return float("nan")
    
    x_raw = dfv["x"]
    yb = dfv["y"].astype(int)
    miss = x_raw.isna() | (x_raw == SENTINEL)
    x_non = x_raw[~miss]
    
    if x_non.nunique(dropna=True) <= 2:
        b = x_raw.astype(object).where(~miss, "MISSING")
    else:
        try:
            b_non = pd.qcut(x_non, q=IV_Q, duplicates="drop")
            b = pd.Series("MISSING", index=x_raw.index, dtype="object")
            b.loc[~miss] = b_non.astype(str)
        except Exception:
            b = x_raw.astype(object).where(~miss, "MISSING")
    
    grp = pd.DataFrame({"b": b, "y": yb}).groupby("b", observed=False)["y"].agg(["count", "sum"]).rename(columns={"sum": "bad"})
    grp["good"] = grp["count"] - grp["bad"]
    bt = grp["bad"].sum()
    gt = grp["good"].sum()
    
    if bt == 0 or gt == 0:
        return 0.0
    
    k = grp.shape[0]
    grp["bad_dist"] = (grp["bad"] + 0.5) / (bt + 0.5 * k)
    grp["good_dist"] = (grp["good"] + 0.5) / (gt + 0.5 * k)
    woe = np.log(grp["bad_dist"] / grp["good_dist"])
    iv = ((grp["bad_dist"] - grp["good_dist"]) * woe).sum()
    
    return float(iv)


def _corr_pearson(x: np.ndarray, y: np.ndarray) -> float:
    """
    计算 Pearson 相关系数
    """
    if len(x) != len(y) or len(x) < 2:
        return float("nan")
    
    try:
        corr, _ = pearsonr(x, y)
        return float(corr) if not np.isnan(corr) else float("nan")
    except Exception:
        return float("nan")


def _psi_one(x: pd.Series, base_mask: pd.Series, comp_mask: pd.Series) -> float:
    """
    计算 PSI（Population Stability Index）
    base_mask: 基准期（第一周）的 mask
    comp_mask: 比较期（后两周）的 mask
    """
    miss = x.isna() | (x == SENTINEL)
    xb = x[base_mask]
    xc = x[comp_mask]
    mb = miss[base_mask]
    mc = miss[comp_mask]
    
    if xb.shape[0] == 0 or xc.shape[0] == 0:
        return float("nan")
    
    xb_non = xb[~mb]
    
    if xb_non.nunique(dropna=True) <= 2:
        bb = xb.astype(object).where(~mb, "MISSING")
        bc = xc.astype(object).where(~mc, "MISSING")
    else:
        try:
            _, edges = pd.qcut(xb_non, q=PSI_Q, retbins=True, duplicates="drop")
            edges = sorted(set(edges.tolist()))
            if len(edges) < 3:
                bb = xb.astype(object).where(~mb, "MISSING")
                bc = xc.astype(object).where(~mc, "MISSING")
            else:
                bb_non = pd.cut(xb_non, bins=edges, include_lowest=True)
                bc_non = pd.cut(xc[~mc], bins=edges, include_lowest=True)
                bb = pd.Series("MISSING", index=xb.index, dtype="object")
                bc = pd.Series("MISSING", index=xc.index, dtype="object")
                bb.loc[~mb] = bb_non.astype(str)
                bc.loc[~mc] = bc_non.astype(str)
        except Exception:
            bb = xb.astype(object).where(~mb, "MISSING")
            bc = xc.astype(object).where(~mc, "MISSING")
    
    pb = bb.value_counts(normalize=True)
    pc = bc.value_counts(normalize=True)
    cats = list(pb.index.union(pc.index))
    
    psi = 0.0
    for k in cats:
        p = max(float(pb.get(k, 0.0)), EPS)
        q = max(float(pc.get(k, 0.0)), EPS)
        psi += (q - p) * np.log(q / p)
    
    return float(psi)

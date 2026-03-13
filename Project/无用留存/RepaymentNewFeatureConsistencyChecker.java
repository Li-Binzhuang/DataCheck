package com.hb.oversea.riskanalysis.util;

import org.springframework.core.io.ClassPathResource;

import java.io.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * 特征一致性检查工具 (超大文件版)
 * 支持 1.2w行 × 3w列 的CSV比对，内存占用极低
 * <p>
 * 核心策略：
 * 1. 两个文件都不全量加载到内存
 * 2. 流式读原始文件，收集一批 key（BATCH_SIZE 行）
 * 3. 每批扫描一次回溯文件，用 extractColumns 只提取命中行的需要列
 * 4. 每批处理完释放内存，峰值内存 = BATCH_SIZE × 共同特征数 的 String
 */
public class RepaymentNewFeatureConsistencyChecker {

    private static final String ORIGINAL_CSV = "sms_v3_all_merged_0302_v1.csv.csv";
    private static final String RECALL_CSV = "0302_my_03111526_zlf.csv";

    // 使用 apply_id + cust_no + 回溯时间 作为复合唯一键

    // 不比对的列
    private static final Set<String> EXCLUDE_COLUMNS = new HashSet<>(Arrays.asList(
            "ua_id", "apply_id", "cust_no", "request_time", "ua_time", "business_type", "create_time", "if_reoffer", "rule_type", "user_type", "base_time", "elapsed_ms"
    ));

    private static final double TOLERANCE = 0.000001;
    private static final int BATCH_SIZE = 500;

    private static final String RECALL_FEATURE_PREFIX = "local_all_sms_";
    private static final String RECALL_FEATURE_SUFFIX = "_v3";

    public static void main(String[] args) {
        try {
            System.out.println("========================================");
            System.out.println("特征一致性检查工具 (超大文件版)");
            System.out.println("========================================");
            System.out.println("原始文件: " + ORIGINAL_CSV);
            System.out.println("回溯文件: " + RECALL_CSV);
            System.out.println("匹配键模式: apply_id#cust_no#回溯时间");
            System.out.println("========================================\n");
            compareCsvFiles();
        } catch (Exception e) {
            System.err.println("执行失败: " + e.getMessage());

        }
    }

    public static void compareCsvFiles() throws Exception {
        long startTime = System.currentTimeMillis();

        // 1. 读取表头
        System.out.println("[步骤1] 读取表头...");
        OriginalHeader originalHeader = readOriginalHeader();
        RecallHeader recallHeader = readRecallHeader();

        boolean origHasUaId = originalHeader.uaIdIdx >= 0;
        boolean origHasCustNoAndTime = originalHeader.custNoIdx >= 0 && originalHeader.applyTimeIdx >= 0;
        if (!origHasUaId || !origHasCustNoAndTime) {
            throw new IllegalArgumentException("原始文件缺少匹配键列(需要apply_id、cust_no、request_time)");
        }

        System.out.println("  匹配键: apply_id#cust_no#回溯时间");

        List<String> commonFeatures = getCommonFeatures(
                originalHeader.featureIndices.keySet(), new HashSet<>(recallHeader.featureNames));
        System.out.println("  原始特征数: " + originalHeader.featureIndices.size());
        System.out.println("  回溯特征数: " + recallHeader.featureNames.size());
        System.out.println("  共同特征数: " + commonFeatures.size());

        printMissingFeatures(originalHeader.featureIndices.keySet(), recallHeader.featureNames);

        if (commonFeatures.isEmpty()) {
            System.err.println("错误: 没有共同特征！");
            return;
        }

        int totalOriginalLines = countOriginalLines();
        System.out.println("  原始文件记录数: " + totalOriginalLines);

        // 2. 预计算列索引映射
        // 回溯文件：共同特征在回溯文件中的原始列索引
        int[] commonRecallColIndices = new int[commonFeatures.size()];
        for (int i = 0; i < commonFeatures.size(); i++) {
            Integer featureListIdx = recallHeader.featureIndices.get(commonFeatures.get(i));
            commonRecallColIndices[i] = recallHeader.featureColIndices.get(featureListIdx);
        }

        // 回溯文件需要提取的所有列（key列 + 特征列），排序
        Set<Integer> recallNeededSet = new TreeSet<>();
        if (recallHeader.custNoIdx >= 0) recallNeededSet.add(recallHeader.custNoIdx);
        if (recallHeader.applyTimeIdx >= 0) recallNeededSet.add(recallHeader.applyTimeIdx);
        if (recallHeader.uaIdIdx >= 0) recallNeededSet.add(recallHeader.uaIdIdx);
        for (int c : commonRecallColIndices) recallNeededSet.add(c);
        int[] recallNeededCols = recallNeededSet.stream().mapToInt(Integer::intValue).toArray();

        Map<Integer, Integer> recallColMap = new HashMap<>();
        for (int i = 0; i < recallNeededCols.length; i++) recallColMap.put(recallNeededCols[i], i);
        int[] rExtFeature = new int[commonFeatures.size()];
        for (int i = 0; i < commonFeatures.size(); i++) {
            rExtFeature[i] = recallColMap.get(commonRecallColIndices[i]);
        }

        // 回溯文件 key 列的原始列索引（用于快速提取 key）
        int rKeyUaIdCol = recallHeader.uaIdIdx >= 0 ? recallHeader.uaIdIdx : -1;
        int rKeyCustNoCol = recallHeader.custNoIdx >= 0 ? recallHeader.custNoIdx : -1;
        int rKeyApplyTimeCol = recallHeader.applyTimeIdx >= 0 ? recallHeader.applyTimeIdx : -1;
        int rKeyMaxCol = Math.max(rKeyUaIdCol, Math.max(rKeyCustNoCol, rKeyApplyTimeCol));

        // 原始文件需要提取的列
        Set<Integer> origNeededSet = new TreeSet<>();
        if (originalHeader.custNoIdx >= 0) origNeededSet.add(originalHeader.custNoIdx);
        if (originalHeader.applyTimeIdx >= 0) origNeededSet.add(originalHeader.applyTimeIdx);
        if (originalHeader.uaIdIdx >= 0) origNeededSet.add(originalHeader.uaIdIdx);
        int[] commonOrigColIndices = new int[commonFeatures.size()];
        for (int i = 0; i < commonFeatures.size(); i++) {
            commonOrigColIndices[i] = originalHeader.featureIndices.get(commonFeatures.get(i));
            origNeededSet.add(commonOrigColIndices[i]);
        }
        int[] origNeededCols = origNeededSet.stream().mapToInt(Integer::intValue).toArray();

        Map<Integer, Integer> origColMap = new HashMap<>();
        for (int i = 0; i < origNeededCols.length; i++) origColMap.put(origNeededCols[i], i);
        int oExtCustNo = originalHeader.custNoIdx >= 0 ? origColMap.getOrDefault(originalHeader.custNoIdx, -1) : -1;
        int oExtApplyTime = originalHeader.applyTimeIdx >= 0 ? origColMap.getOrDefault(originalHeader.applyTimeIdx, -1) : -1;
        int oExtUaId = originalHeader.uaIdIdx >= 0 ? origColMap.getOrDefault(originalHeader.uaIdIdx, -1) : -1;
        int[] oExtFeature = new int[commonFeatures.size()];
        for (int i = 0; i < commonFeatures.size(); i++) {
            oExtFeature[i] = origColMap.get(commonOrigColIndices[i]);
        }

        // 3. 分批比对
        System.out.println("\n[步骤2] 分批比对，每批 " + BATCH_SIZE + " 行...\n");

        int totalRecords = 0, matchedRecords = 0, mismatchedRecords = 0, notFoundRecords = 0;
        long totalFeatureCompares = 0, totalMatches = 0, totalMismatches = 0;
        Map<String, Integer> featureMismatchCount = new HashMap<>();
        List<MismatchRecord> mismatchDetails = new ArrayList<>();

        List<OriginalRow> batch = new ArrayList<>(BATCH_SIZE);

        ClassPathResource originalResource = new ClassPathResource(ORIGINAL_CSV);
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(originalResource.getInputStream(), StandardCharsets.UTF_8), 256 * 1024)) {
            reader.readLine(); // 跳过表头
            String line;
            int lineNum = 1;

            while ((line = reader.readLine()) != null) {
                lineNum++;
                if (line.isEmpty()) continue;

                String[] extracted = extractColumns(line, origNeededCols);

                String key, custNo = "", applyTime = "", applyId = "";
                if (oExtUaId >= 0 && oExtUaId < extracted.length) applyId = extracted[oExtUaId].trim();
                if (oExtCustNo >= 0 && oExtCustNo < extracted.length) custNo = extracted[oExtCustNo].trim();
                if (oExtApplyTime >= 0 && oExtApplyTime < extracted.length) applyTime = extracted[oExtApplyTime].trim();

                if (applyId.isEmpty() || "null".equalsIgnoreCase(applyId)
                        || custNo.isEmpty() || applyTime.isEmpty()) continue;
                key = applyId + "#" + custNo + "#" + normalizeApplyTime(applyTime);

                batch.add(new OriginalRow(extracted, custNo, applyTime, applyId, key, lineNum));

                if (batch.size() >= BATCH_SIZE) {
                    BatchResult br = processBatchScan(batch, recallNeededCols,
                            rKeyUaIdCol, rKeyCustNoCol, rKeyApplyTimeCol, rKeyMaxCol,
                            rExtFeature, oExtFeature, commonFeatures);
                    totalRecords += br.total; matchedRecords += br.matched;
                    mismatchedRecords += br.mismatched; notFoundRecords += br.notFound;
                    totalFeatureCompares += br.featureCompares;
                    totalMatches += br.featureMatches; totalMismatches += br.featureMismatches;
                    mergeMismatchStats(featureMismatchCount, br.featureMismatchCount);
                    appendMismatchDetails(mismatchDetails, br.mismatchDetails);
                    logProgress(totalRecords, totalOriginalLines, matchedRecords, mismatchedRecords, notFoundRecords, startTime);
                    batch.clear();
                }
            }

            if (!batch.isEmpty()) {
                BatchResult br = processBatchScan(batch, recallNeededCols,
                        rKeyUaIdCol, rKeyCustNoCol, rKeyApplyTimeCol, rKeyMaxCol,
                        rExtFeature, oExtFeature, commonFeatures);
                totalRecords += br.total; matchedRecords += br.matched;
                mismatchedRecords += br.mismatched; notFoundRecords += br.notFound;
                totalFeatureCompares += br.featureCompares;
                totalMatches += br.featureMatches; totalMismatches += br.featureMismatches;
                mergeMismatchStats(featureMismatchCount, br.featureMismatchCount);
                appendMismatchDetails(mismatchDetails, br.mismatchDetails);
                logProgress(totalRecords, totalOriginalLines, matchedRecords, mismatchedRecords, notFoundRecords, startTime);
            }
        }

        long totalTime = System.currentTimeMillis() - startTime;
        printSummary(totalRecords, matchedRecords, mismatchedRecords, notFoundRecords,
                totalFeatureCompares, totalMatches, totalMismatches, commonFeatures.size(),
                featureMismatchCount, mismatchDetails, totalTime);
    }

    /**
     * 处理一批：扫描回溯文件，只提取命中行进行比对
     * 内存 = BATCH_SIZE × commonFeatures.size() 的 String（处理完释放）
     */
    private static BatchResult processBatchScan(
            List<OriginalRow> batch, int[] recallNeededCols,
            int rKeyUaIdCol, int rKeyCustNoCol, int rKeyApplyTimeCol, int rKeyMaxCol,
            int[] rExtFeature, int[] oExtFeature,
            List<String> commonFeatures) throws Exception {

        BatchResult br = new BatchResult();
        Map<String, OriginalRow> keyMap = new HashMap<>();
        for (OriginalRow row : batch) keyMap.put(row.key, row);

        // 扫描回溯文件，只提取命中行
        Map<String, String[]> recallHits = new HashMap<>();

        ClassPathResource resource = new ClassPathResource(RECALL_CSV);
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8), 256 * 1024)) {
            reader.readLine(); // 跳过表头
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.isEmpty()) continue;

                // 快速提取 key（只遍历到 key 列位置，不解析全部列）
                String key = extractKeyOnly(line, rKeyUaIdCol, rKeyCustNoCol, rKeyApplyTimeCol, rKeyMaxCol);
                if (key == null || !keyMap.containsKey(key)) continue;

                // 命中！提取需要的列
                String[] extracted = extractColumns(line, recallNeededCols);

                String[] featureValues = new String[commonFeatures.size()];
                for (int i = 0; i < commonFeatures.size(); i++) {
                    featureValues[i] = extracted[rExtFeature[i]].trim();
                }
                recallHits.put(key, featureValues);
                if (recallHits.size() >= keyMap.size()) break; // 全部找到，提前退出
            }
        }

        // 比对
        for (OriginalRow row : batch) {
            br.total++;
            String[] recallFeatures = recallHits.get(row.key);
            if (recallFeatures == null) { br.notFound++; continue; }

            List<FeatureMismatch> mismatches = new ArrayList<>();
            int matchCnt = 0, mismatchCnt = 0;

            for (int i = 0; i < commonFeatures.size(); i++) {
                String origVal = row.values[oExtFeature[i]].trim();
                String recallVal = recallFeatures[i];
                br.featureCompares++;
                if (compareValues(origVal, recallVal)) {
                    matchCnt++; br.featureMatches++;
                } else {
                    mismatchCnt++; br.featureMismatches++;
                    mismatches.add(new FeatureMismatch(commonFeatures.get(i), origVal, recallVal));
                    br.featureMismatchCount.merge(commonFeatures.get(i), 1, Integer::sum);
                }
            }

            if (mismatchCnt == 0) { br.matched++; }
            else {
                br.mismatched++;
                if (br.mismatchDetails.size() < 10)
                    br.mismatchDetails.add(new MismatchRecord(row.lineNum, row.custNo, row.applyTime, row.applyId, matchCnt, mismatchCnt, mismatches));
            }
        }
        return br;
    }

    /**
     * 从CSV行中快速提取 key（只遍历到 key 列位置）
     * 不解析全部3w列，只定位 key 相关的列
     */
    private static String extractKeyOnly(String line, int uaIdCol, int custNoCol, int applyTimeCol, int maxKeyCol) {
        if (maxKeyCol < 0) return null;
        String uaId = null, custNo = null, applyTime = null;
        int colIdx = 0, colStart = 0;
        boolean inQuote = false;
        int len = line.length();

        for (int i = 0; i <= len; i++) {
            char c = (i < len) ? line.charAt(i) : ',';
            if (c == '"') {
                if (inQuote && i + 1 < len && line.charAt(i + 1) == '"') { i++; }
                else { inQuote = !inQuote; }
            } else if (c == ',' && !inQuote) {
                if (colIdx == uaIdCol) uaId = line.substring(colStart, i).trim();
                else if (colIdx == custNoCol) custNo = line.substring(colStart, i).trim();
                else if (colIdx == applyTimeCol) applyTime = line.substring(colStart, i).trim();
                colIdx++;
                colStart = i + 1;
                if (colIdx > maxKeyCol) break;
            }
        }

        // 复合键: apply_id#cust_no#回溯时间
        if (uaId != null && !uaId.isEmpty() && !"null".equalsIgnoreCase(uaId)
                && custNo != null && !custNo.isEmpty()
                && applyTime != null && !applyTime.isEmpty()) {
            return uaId + "#" + custNo + "#" + normalizeApplyTime(applyTime);
        }
        return null;
    }

    /**
     * 从CSV行中只提取指定列的值（零拷贝）
     * 遍历字符串计数逗号，只对需要的列做 substring
     */
    private static String[] extractColumns(String line, int[] sortedColIndices) {
        String[] result = new String[sortedColIndices.length];
        int colIdx = 0, needIdx = 0, colStart = 0;
        boolean inQuote = false;
        int len = line.length();

        for (int i = 0; i <= len; i++) {
            char c = (i < len) ? line.charAt(i) : ',';
            if (c == '"') {
                if (inQuote && i + 1 < len && line.charAt(i + 1) == '"') { i++; }
                else { inQuote = !inQuote; }
            } else if (c == ',' && !inQuote) {
                if (needIdx < sortedColIndices.length && colIdx == sortedColIndices[needIdx]) {
                    String val = line.substring(colStart, i);
                    if (val.length() >= 2 && val.charAt(0) == '"' && val.charAt(val.length() - 1) == '"')
                        val = val.substring(1, val.length() - 1).replace("\"\"", "\"");
                    result[needIdx] = val;
                    needIdx++;
                    if (needIdx >= sortedColIndices.length) return result;
                }
                colIdx++;
                colStart = i + 1;
            }
        }
        for (int i = needIdx; i < result.length; i++) result[i] = "";
        return result;
    }

    // ==================== 表头读取 ====================

    private static class OriginalHeader {
        int custNoIdx = -1, applyTimeIdx = -1, uaIdIdx = -1;
        Map<String, Integer> featureIndices = new LinkedHashMap<>();
    }

    private static class RecallHeader {
        int custNoIdx = -1, applyTimeIdx = -1, uaIdIdx = -1;
        List<String> featureNames = new ArrayList<>();
        Map<String, Integer> featureIndices = new HashMap<>();
        List<Integer> featureColIndices = new ArrayList<>();
    }

    private static OriginalHeader readOriginalHeader() throws Exception {
        OriginalHeader header = new OriginalHeader();
        ClassPathResource resource = new ClassPathResource(ORIGINAL_CSV);
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            String headerLine = reader.readLine();
            if (headerLine == null) throw new IOException("原始CSV文件为空");
            String[] headers = parseCsvLine(headerLine);
            for (int i = 0; i < headers.length; i++) {
                String h = headers[i].trim().toLowerCase();
                if (i == 0) h = h.replace("\uFEFF", "");
                switch (h) {
                    case "cust_no": header.custNoIdx = i; break;
                    case "request_time": case "create_time": header.applyTimeIdx = i; break;
                    case "ua_id": case "apply_id": header.uaIdIdx = i; break;
                }
                if (!EXCLUDE_COLUMNS.contains(h) && !h.isEmpty()) header.featureIndices.put(h, i);
            }
        }
        return header;
    }

    private static RecallHeader readRecallHeader() throws Exception {
        RecallHeader header = new RecallHeader();
        ClassPathResource resource = new ClassPathResource(RECALL_CSV);
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            String headerLine = reader.readLine();
            if (headerLine == null) throw new IOException("回溯CSV文件为空");
            String[] headers = parseCsvLine(headerLine);
            for (int i = 0; i < headers.length; i++) {
                String h = headers[i].trim().toLowerCase();
                if (i == 0) h = h.replace("\uFEFF", "");
                if ("cust_no".equals(h)) header.custNoIdx = i;
                else if ("request_time".equals(h) || "create_time".equals(h) || "base_time".equals(h)) header.applyTimeIdx = i;
                else if ("ua_id".equals(h) || "apply_id".equals(h)) header.uaIdIdx = i;
                if (!EXCLUDE_COLUMNS.contains(h) && !h.isEmpty()) {
                    String normalized = recallFeatureToOriginal(h);
                    header.featureNames.add(normalized);
                    header.featureIndices.put(normalized, header.featureNames.size() - 1);
                    header.featureColIndices.add(i);
                }
            }
        }
        return header;
    }

    // ==================== 数据类 ====================

    private static class OriginalRow {
        final String[] values; final String custNo, applyTime, applyId, key; final int lineNum;
        OriginalRow(String[] values, String custNo, String applyTime, String applyId, String key, int lineNum) {
            this.values = values; this.custNo = custNo; this.applyTime = applyTime;
            this.applyId = applyId; this.key = key; this.lineNum = lineNum;
        }
    }

    private static class BatchResult {
        int total, matched, mismatched, notFound;
        long featureCompares, featureMatches, featureMismatches;
        Map<String, Integer> featureMismatchCount = new HashMap<>();
        List<MismatchRecord> mismatchDetails = new ArrayList<>();
    }

    private static class FeatureMismatch {
        String featureName, originalValue, recallValue;
        FeatureMismatch(String f, String o, String r) { featureName = f; originalValue = o; recallValue = r; }
    }

    private static class MismatchRecord {
        int rowNum;
        String custNo, applyTime, applyId;
        int matchCount, mismatchCount;
        List<FeatureMismatch> mismatches;

        MismatchRecord(int r, String c, String t, String a, int m, int mm, List<FeatureMismatch> ms) {
            rowNum = r;
            custNo = c;
            applyTime = t;
            applyId = a;
            matchCount = m;
            mismatchCount = mm;
            mismatches = ms;
        }
    }

    // ==================== 工具方法 ====================

    private static int countOriginalLines() throws Exception {
        ClassPathResource resource = new ClassPathResource(ORIGINAL_CSV);
        int cnt = 0;
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))) {
            reader.readLine();
            while (reader.readLine() != null) cnt++;
        }
        return cnt;
    }

    private static List<String> getCommonFeatures(Set<String> origFeatures, Set<String> recallFeatures) {
        List<String> common = new ArrayList<>();
        for (String f : origFeatures) {
            if (recallFeatures.contains(f.toLowerCase())) common.add(f);
        }
        return common;
    }

    private static void printMissingFeatures(Set<String> origFeatures, List<String> recallFeatures) {
        Set<String> recallSet = new HashSet<>(recallFeatures);
        List<String> missingInRecall = new ArrayList<>();
        for (String f : origFeatures) { if (!recallSet.contains(f)) missingInRecall.add(f); }
        if (!missingInRecall.isEmpty()) {
            System.out.println("\n  回溯文件缺少的特征 (" + missingInRecall.size() + " 个):");
            Collections.sort(missingInRecall);
            for (int i = 0; i < Math.min(20, missingInRecall.size()); i++) System.out.println("    " + (i+1) + ". " + missingInRecall.get(i));
            if (missingInRecall.size() > 20) System.out.println("    ... 还有 " + (missingInRecall.size()-20) + " 个");
        }
        List<String> missingInOrig = new ArrayList<>();
        for (String f : recallFeatures) { if (!origFeatures.contains(f)) missingInOrig.add(f); }
        if (!missingInOrig.isEmpty()) {
            System.out.println("\n  原始文件缺少的特征 (" + missingInOrig.size() + " 个):");
            Collections.sort(missingInOrig);
            for (int i = 0; i < Math.min(20, missingInOrig.size()); i++) System.out.println("    " + (i+1) + ". " + missingInOrig.get(i));
            if (missingInOrig.size() > 20) System.out.println("    ... 还有 " + (missingInOrig.size()-20) + " 个");
        }
    }

    private static String normalizeApplyTime(String t) {
        if (t == null || t.isEmpty()) return t;
        int dot = t.indexOf('.');
        if (dot > 0) t = t.substring(0, dot);
        t = t.replace('/', '-');
        if (t.length() > 19) t = t.substring(0, 19);
        return t.trim();
    }

    private static boolean compareValues(String origVal, String recallVal) {
        boolean origEmpty = origVal == null || origVal.isEmpty() || "null".equalsIgnoreCase(origVal);
        boolean recallEmpty = recallVal == null || recallVal.isEmpty() || "null".equalsIgnoreCase(recallVal);
        boolean origZero = isZeroOrMissing(origVal);
        boolean recallZero = isZeroOrMissing(recallVal);
        if ((origEmpty || origZero) && (recallEmpty || recallZero)) return true;
        if (origEmpty || recallEmpty) return false;
        try {
            BigDecimal a = new BigDecimal(origVal), b = new BigDecimal(recallVal);
            if (a.scale() <= 0 && b.scale() <= 0) return a.compareTo(b) == 0;
            BigDecimal diff = a.subtract(b).abs();
            BigDecimal tol = BigDecimal.valueOf(TOLERANCE);
            if (diff.compareTo(tol) <= 0) return true;
            BigDecimal maxV = a.abs().max(b.abs());
            if (maxV.compareTo(BigDecimal.ZERO) > 0) return diff.divide(maxV, 10, RoundingMode.HALF_UP).compareTo(tol) <= 0;
            return false;
        } catch (NumberFormatException e) { return origVal.equals(recallVal); }
    }

    private static boolean isZeroOrMissing(String v) {
        if (v == null || v.isEmpty()) return false;
        try {
            BigDecimal n = new BigDecimal(v);
            return n.compareTo(BigDecimal.ZERO) == 0 || n.compareTo(new BigDecimal("-999")) == 0;
        } catch (NumberFormatException e) { return false; }
    }

    private static String[] parseCsvLine(String line) {
        List<String> cols = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean inQuote = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '"') {
                if (inQuote && i + 1 < line.length() && line.charAt(i + 1) == '"') { cur.append('"'); i++; }
                else inQuote = !inQuote;
            } else if (c == ',' && !inQuote) { cols.add(cur.toString()); cur.setLength(0); }
            else cur.append(c);
        }
        cols.add(cur.toString());
        return cols.toArray(new String[0]);
    }

    private static void printSummary(int totalRecords, int matchedRecords, int mismatchedRecords, int notFoundRecords,
            long totalFeatureCompares, long totalMatches, long totalMismatches, int featureCount,
            Map<String, Integer> featureMismatchCount, List<MismatchRecord> mismatchDetails, long totalTime) {
        System.out.println("\n========================================");
        System.out.println("比对结果汇总");
        System.out.println("========================================");
        System.out.println("原始文件记录数: " + totalRecords);
        System.out.println("比对特征数量: " + featureCount);
        System.out.println("完全一致: " + matchedRecords + " (" + String.format("%.2f%%", matchedRecords * 100.0 / Math.max(1, totalRecords)) + ")");
        System.out.println("存在不一致: " + mismatchedRecords + " (" + String.format("%.2f%%", mismatchedRecords * 100.0 / Math.max(1, totalRecords)) + ")");
        System.out.println("回溯中未找到: " + notFoundRecords);
        System.out.println("特征比对: 总=" + totalFeatureCompares + ", 一致=" + totalMatches + ", 不一致=" + totalMismatches);
        System.out.printf("整体一致率: %.4f%%\n", totalFeatureCompares > 0 ? totalMatches * 100.0 / totalFeatureCompares : 0);
        System.out.println("总耗时: " + formatDuration(totalTime));
        System.out.println("========================================");

        if (!featureMismatchCount.isEmpty()) {
            System.out.println("\n不一致次数最多的特征 (Top 50):");
            featureMismatchCount.entrySet().stream()
                    .sorted((a, b) -> b.getValue() - a.getValue())
                    .limit(50)
                    .forEach(e -> System.out.printf("  %-60s : %d 次 (%.2f%%)\n",
                            e.getKey(), e.getValue(), e.getValue() * 100.0 / Math.max(1, totalRecords)));
        }

        if (!mismatchDetails.isEmpty()) {
            System.out.println("\n不一致记录详情 (前" + mismatchDetails.size() + "条):");
            for (MismatchRecord r : mismatchDetails) {
                System.out.println("\n行号: " + r.rowNum + ", applyId: " + r.applyId + ", custNo: " + r.custNo + ", applyTime: " + r.applyTime);
                System.out.println("一致: " + r.matchCount + ", 不一致: " + r.mismatchCount);
                int cnt = Math.min(r.mismatches.size(), 20);
                for (int i = 0; i < cnt; i++) {
                    FeatureMismatch m = r.mismatches.get(i);
                    System.out.printf("  %-55s | 原始: %-15s | 回溯: %-15s\n",
                            m.featureName, truncate(m.originalValue), truncate(m.recallValue));
                }
                if (r.mismatches.size() > 20) System.out.println("  ... 还有 " + (r.mismatches.size() - 20) + " 个");
            }
        }

        System.out.println("\n========================================");
        if (mismatchedRecords == 0 && notFoundRecords == 0)
            System.out.println("✅ 检查通过：所有记录完全一致！");
        else {
            System.out.println("❌ 检查未通过");
            if (mismatchedRecords > 0) System.out.println("   - " + mismatchedRecords + " 条不一致");
            if (notFoundRecords > 0) System.out.println("   - " + notFoundRecords + " 条未找到");
        }
        System.out.println("========================================");
    }

    private static void mergeMismatchStats(Map<String, Integer> total, Map<String, Integer> add) {
        if (add != null) add.forEach((k, v) -> total.merge(k, v, Integer::sum));
    }

    private static void appendMismatchDetails(List<MismatchRecord> total, List<MismatchRecord> add) {
        if (add != null) for (MismatchRecord mr : add) { if (total.size() >= 100) break; total.add(mr); }
    }

    private static void logProgress(int processed, int total, int matched, int mismatched, int notFound, long startTime) {
        long elapsed = System.currentTimeMillis() - startTime;
        System.out.printf("[进度] %d / %d，耗时: %s，一致: %d，不一致: %d，未找到: %d%n",
                processed, total, formatDuration(elapsed), matched, mismatched, notFound);
    }

    private static String truncate(String s) {
        if (s == null) return "";
        return s.length() <= 15 ? s : s.substring(0, 15 - 3) + "...";
    }

    private static String formatDuration(long ms) {
        if (ms < 1000) return ms + "ms";
        if (ms < 60000) return String.format("%.1fs", ms / 1000.0);
        if (ms < 3600000) return String.format("%dm%ds", ms / 60000, (ms % 60000) / 1000);
        return String.format("%dh%dm%ds", ms / 3600000, (ms % 3600000) / 60000, (ms % 60000) / 1000);
    }

    private static String recallFeatureToOriginal(String name) {
        if (name == null || name.isEmpty()) return name;
        String r = name;
        if (r.startsWith(RECALL_FEATURE_PREFIX))
            r = r.substring(RECALL_FEATURE_PREFIX.length());
        if (r.endsWith(RECALL_FEATURE_SUFFIX))
            r = r.substring(0, r.length() - RECALL_FEATURE_SUFFIX.length());
        return r;
    }
}

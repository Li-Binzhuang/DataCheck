// 全局配置和常量
const MAX_OUTPUT_LINES = 10000;  // 最多保留10000行（足够显示完整日志）
const SAMPLE_RATE = 1;           // 采样率设为1，显示所有日志

// 全局状态变量
let outputCounters = {};        // 每个tab的输出计数器
let isExecuting = false;
let isExecutingOnline = false;
let isParsingOnline = false;
let isOnlineParsed = false;     // 标记JSON是否已解析
let scenarioCount = 0;
let onlineScenarioCount = 0;    // 线上灰度落数对比场景计数

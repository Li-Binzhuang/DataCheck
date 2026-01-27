// 全局配置和常量
const MAX_OUTPUT_LINES = 10;    // 最多保留10行
const SAMPLE_RATE = 5;          // 采样率（每5条显示1条）

// 全局状态变量
let outputCounters = {};        // 每个tab的输出计数器
let isExecuting = false;
let isExecutingOnline = false;
let isParsingOnline = false;
let isOnlineParsed = false;     // 标记JSON是否已解析
let scenarioCount = 0;
let onlineScenarioCount = 0;    // 线上灰度落数对比场景计数

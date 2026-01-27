#!/bin/bash
# 测试接口对比执行

echo "测试接口对比执行..."
echo ""

# 创建测试配置
cat > /tmp/test_config.json << 'EOF'
{
  "scenarios": [
    {
      "name": "测试场景",
      "enabled": true,
      "description": "测试执行",
      "csv_file": "test.csv",
      "api_url": "http://example.com/api",
      "api_method": "POST",
      "thread_count": 1,
      "timeout": 10
    }
  ],
  "global_config": {
    "default_thread_count": 1,
    "default_timeout": 10
  }
}
EOF

CONFIG_JSON=$(cat /tmp/test_config.json)

echo "发送请求到 http://localhost:5001/api/execute"
echo ""

# 使用curl测试，设置超时
curl -N -X POST http://localhost:5001/api/execute \
  -H "Content-Type: application/json" \
  -d "{\"config\": $(echo "$CONFIG_JSON" | jq -c .)}" \
  --max-time 30 \
  2>&1

echo ""
echo ""
echo "测试完成"

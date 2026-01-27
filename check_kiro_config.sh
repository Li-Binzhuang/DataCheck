#!/bin/bash
# Kiro配置检查脚本

echo "======================================"
echo "Kiro自动接受配置检查"
echo "======================================"
echo ""

# 检查函数
check_config() {
    local config_file=$1
    local project_name=$2
    
    if [ -f "$config_file" ]; then
        echo "✅ $project_name"
        echo "   配置文件: $config_file"
        
        # 检查是否包含autoAcceptEdits
        if grep -q "kiro.autoAcceptEdits.*true" "$config_file"; then
            echo "   状态: 已启用自动接受"
        else
            echo "   ⚠️  状态: 未启用自动接受"
        fi
        echo ""
    else
        echo "❌ $project_name"
        echo "   配置文件不存在: $config_file"
        echo ""
    fi
}

# 检查所有项目
check_config ".kiro/settings.json" "根目录 (OverseasPython)"
check_config "MyDataCheck/.kiro/settings.json" "MyDataCheck项目"
check_config "CDC/.kiro/settings.json" "CDC项目"
check_config "Mytest/.kiro/settings.json" "Mytest项目"

echo "======================================"
echo "检查完成"
echo "======================================"
echo ""
echo "如需重新加载配置，请执行："
echo "  Cmd+Shift+P → Developer: Reload Window"
echo ""

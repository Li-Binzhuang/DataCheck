#!/bin/bash
# 测试菜单修复脚本

echo "======================================"
echo "侧边栏菜单修复测试"
echo "======================================"
echo ""

# 检查index.html是否存在
if [ ! -f "templates/index.html" ]; then
    echo "❌ 错误: templates/index.html 不存在"
    exit 1
fi

echo "✅ 文件存在: templates/index.html"

# 检查switchPage函数是否存在
if grep -q "function switchPage" templates/index.html; then
    echo "✅ switchPage函数已添加"
else
    echo "❌ 错误: switchPage函数未找到"
    exit 1
fi

# 检查页面元素是否存在
echo ""
echo "检查页面元素..."
for page in "page-api" "page-online" "page-compare" "page-pkl"; do
    if grep -q "id=\"$page\"" templates/index.html; then
        echo "  ✅ $page"
    else
        echo "  ❌ $page 未找到"
    fi
done

# 检查菜单项是否存在
echo ""
echo "检查菜单项..."
if grep -q "onclick=\"switchPage('api')\"" templates/index.html; then
    echo "  ✅ 接口数据对比菜单"
else
    echo "  ❌ 接口数据对比菜单未找到"
fi

if grep -q "onclick=\"switchPage('online')\"" templates/index.html; then
    echo "  ✅ 线上灰度落数对比菜单"
else
    echo "  ❌ 线上灰度落数对比菜单未找到"
fi

if grep -q "onclick=\"switchPage('compare')\"" templates/index.html; then
    echo "  ✅ 数据对比菜单"
else
    echo "  ❌ 数据对比菜单未找到"
fi

if grep -q "onclick=\"switchPage('pkl')\"" templates/index.html; then
    echo "  ✅ PKL文件解析菜单"
else
    echo "  ❌ PKL文件解析菜单未找到"
fi

echo ""
echo "======================================"
echo "检查完成"
echo "======================================"
echo ""
echo "下一步操作："
echo "1. 重启Web服务:"
echo "   ./stop_web.sh && ./start_web.sh"
echo ""
echo "2. 访问页面:"
echo "   http://localhost:5000"
echo ""
echo "3. 打开浏览器Console (F12)"
echo "   查看日志输出"
echo ""
echo "4. 点击左侧菜单测试切换"
echo ""

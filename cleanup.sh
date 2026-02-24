#!/bin/bash

# Algora Bounty Hunter - 完整清理脚本
# 运行此脚本清理所有临时文件和缓存

echo "🧹 开始清理..."

# 1. 清理临时克隆仓库
echo "📁 清理临时仓库..."
rm -rf /tmp/zio-* /tmp/kyo-* /tmp/archestra-* /tmp/mudlet-* /tmp/diffractsim-* /tmp/deskflow-* 2>/dev/null
echo "✅ 临时仓库已清理"

# 2. 清理git缓存（如果有）
echo "🔄 清理Git缓存..."
git gc --prune=now --aggressive 2>/dev/null
echo "✅ Git缓存已清理"

# 3. 清理Claude Code缓存
echo "🤖 清理Claude Code缓存..."
rm -rf ~/.claude/cache 2>/dev/null
rm -rf ~/.cache/claude 2>/dev/null
echo "✅ Claude Code缓存已清理"

# 4. 清理npm/yarn缓存（如果有）
echo "📦 清理npm缓存..."
npm cache clean --force 2>/dev/null
echo "✅ npm缓存已清理"

# 5. 清理SBT缓存（如果有）
echo "🐢 清理SBT缓存..."
rm -rf ~/.sbt/boot 2>/dev/null
rm -rf ~/.ivy2/cache 2>/dev/null
echo "✅ SBT缓存已清理"

# 6. 清理Maven缓存（如果有）
echo "🟣 清理Maven缓存..."
rm -rf ~/.m2/repository 2>/dev/null
echo "✅ Maven缓存已清理"

# 7. 清理Java编译缓存
echo "☕ 清理Java缓存..."
rm -rf ~/.java/deployment/cache 2>/dev/null
echo "✅ Java缓存已清理"

# 8. 显示当前磁盘使用情况
echo ""
echo "📊 磁盘使用情况:"
df -h /tmp | tail -1

echo ""
echo "✨ 清理完成！可以开启新会话了。"

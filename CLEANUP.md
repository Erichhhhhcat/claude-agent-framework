# 完整清理流程

## 方式一：运行清理脚本（推荐）

```bash
cd /home/eric/桌面/workspace/claude-agent-framework
./cleanup.sh
```

## 方式二：手动清理命令

### 1. 清理临时仓库
```bash
rm -rf /tmp/zio-* /tmp/kyo-* /tmp/archestra-* /tmp/mudlet-* /tmp/diffractsim-* /tmp/deskflow-*
```

### 2. 清理Git缓存
```bash
git gc --prune=now --aggressive
```

### 3. 清理Claude Code缓存
```bash
rm -rf ~/.claude/cache
rm -rf ~/.cache/claude
```

### 4. 清理项目内的node_modules（如果有）
```bash
find /home/eric/桌面/workspace/claude-agent-framework -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null
```

### 5. 清理SBT缓存（处理Scala项目后）
```bash
rm -rf ~/.sbt/boot
rm -rf ~/.ivy2/cache
```

### 6. 清理Maven缓存
```bash
rm -rf ~/.m2/repository
```

## 开启新会话前的检查清单

- [ ] 运行清理脚本
- [ ] 确保 task.json 存在且包含待处理赏金
- [ ] 确保 progress.md 是最新的
- [ ] 确保 CLAUDE.md 是最新的
- [ ] 确保 git push 已完成

## 开启新会话命令

```bash
claude -p --dangerously-skip-permissions
```

然后告诉AI：
> "请读取 task.json 获取待处理赏金，然后开始处理。详细流程见 CLAUDE.md"

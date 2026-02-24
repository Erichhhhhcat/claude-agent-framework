# Algora Bounty Hunter - Pure Claude Code Workflow

## 愿景 (Vision)

**一切都在 Claude Code 窗口内完成。**

不需要回终端运行命令。整个赏金猎杀流程通过 prompt 驱动，AI 自己完成所有步骤。

---

## 📚 经验总结 (从实战中学到的经验)

### 1. 克隆加速技巧
- **使用代理**：`git clone https://gh-proxy.org/https://github.com/OWNER/REPO.git`
- **Shallow clone**：`git clone --depth 1 --branch BRANCH URL` 避免克隆整个历史
- **大仓库处理**：ZIO仓库3.3GB，使用shallow clone可以成功

### 2. Git 配置要点
- **必须配置**正确的Git用户信息：
  ```bash
  git config user.name "Erichhhhhcat"
  git config user.email "heyum.yin@gmail.com"
  ```
- **避免CLA签名错误**：确保用户名与GitHub账号一致

### 3. 赏金可行性判断
- **放宽规则**：即使已有获奖PR，也可以尝试（维护者可能选择多个方案）
- **硬性限制**：只有仓库>5GB才跳过
- **软性限制**：赏金被移除、issue关闭才跳过
- **检查issue状态**：`gh api repos/OWNER/REPO/issues/NUMBER --jq '.state'`

### 4. Issue修复策略
- **先学习再动手**：查看issue的已有成功PR，学习它们的解决方案
- **使用subagent**：让专门的issue-fixer处理代码修复
- **学习成功PR**：`gh api repos/OWNER/REPO/pulls/PR_NUMBER --jq '.title, .body'`

### 5. Fork和PR创建
- **无权限时先fork**：`gh repo fork OWNER/REPO`
- **添加remote**：`git remote add fork git@github.com:USER/REPO.git`
- **PR声明**：在PR body中使用 `/claim #ISSUE_NUMBER`

### 6. 网络问题处理
- **代理克隆**：使用gh-proxy.org代理解决访问慢问题
- **推送失败**：本地commit已保存，网络恢复后可推送
- **后台任务**：克隆等耗时操作使用后台任务

---

## 运行方式 (How to Run)

```bash
claude -p --dangerously-skip-permissions
```

**注意：**
- 不要指定 `--allowed-tools`，让 AI 自己决定使用什么工具
- 如果需要用到某个 MCP 但没安装，AI 应该尝试自己安装
- 工具使用由 AI 根据任务需求自主决定

---

## 🛡️ 长时间运行保护机制

为防止 10 小时运行导致上下文腐烂，必须遵循以下规则：

### 1. 任务拆分 (Task Splitting)

**每个赏金是一个独立任务**。处理完一个后：
- 提交当前进度
- 清理不必要的上下文
- 开始下一个任务

### 2. 进度必须及时提交

**每完成一个赏金（无论成功或失败），必须立即提交：**

```bash
git add .
git commit -m "bounty: 处理完 XXX/$Y - status: SUCCESS/FAILED"
git push
```

**禁止**：积累多个任务后再一次性提交。

### 3. 使用 task.json 跟踪任务

task.json 格式：

```json
{
  "project": "Algora Bounty Hunter",
  "description": "自动赏金猎杀",
  "bounties": [
    {
      "id": 1,
      "repository": "owner/repo",
      "issueNumber": "bounty": "123",
      "$150",
      "title": "Issue 标题",
      "status": "pending",
      "attempts": 0,
      "reason": ""
    }
  ],
  "currentIndex": 0,
  "completed": 0,
  "failed": 0,
  "skipped": 0
}
```

**每次开始新任务前，读取 task.json 获取下一个任务**

### 4. 定期摘要和重启

每处理 5 个赏金：
1. 创建一个总结 commit
2. 列出所有已创建的 PR
3. 报告当前状态

---

## MANDATORY: 工作流程 (Agent Workflow)

### Step 0: 初始化 (只执行一次)

```bash
cd /home/eric/桌面/workspace/claude-agent-framework

# 确保 task.json 存在
cat > task.json << 'EOF'
{
  "project": "Algora Bounty Hunter",
  "description": "自动赏金猎杀",
  "bounties": [],
  "currentIndex": 0,
  "completed": 0,
  "failed": 0,
  "skipped": 0
}
EOF
```

### Step 1: 获取赏金列表

1. 使用 Playwright 导航到 https://algora.io/bounties
2. 提取所有可用赏金
3. 更新 task.json 中的 bounties 数组

### Step 2: 获取下一个任务

读取 task.json，找到 `status: "pending"` 的任务。

### Step 3: 快速可行性检查

**在花费时间克隆之前，快速判断是否可行：**

- **仓库大小 <= 5GB**（使用 GitHub API 检查） - 唯一硬性限制
- Issue 描述是否清晰？
- 是否有代码示例？

**放宽的规则**：
- ✅ 即使已有获奖的PR，也应该尝试
- ✅ 即使已有多个尝试者，也应该尝试
- ✅ 不需要验证issue是否已被修复，直接尝试
- ❌ 只有以下情况才跳过：
  - 仓库大小超过5GB
  - Issue 已关闭（state: closed）
  - Algora 上不再显示该赏金任务

**跳过条件**：
```bash
# 检查仓库大小
gh api repos/OWNER/REPO --jq '.size'  # 单位KB

# 检查issue状态
gh api repos/OWNER/REPO/issues/NUMBER --jq '.state'
```

如果不可行，标记为 skipped，继续下一个。

### Step 4: 克隆仓库

1. 检查仓库大小（GitHub API）
2. 克隆到 /tmp/（使用代理加速：git clone https://gh-proxy.org/https://github.com/OWNER/REPO.git）
3. 配置 Git 用户（user.name: Erichhhhhcat, user.email: heyum.yin@gmail.com）

### Step 5: 修复 Issue (核心步骤)

**在开始修复前，先分析 Issue 和学习已有成功方案：**

1. **获取 Issue 详情**：
```bash
gh api repos/OWNER/REPO/issues/NUMBER --jq '.title, .body, .state'
```

2. **检查已有的成功PR**：
```bash
gh api repos/OWNER/REPO/issues/NUMBER/comments --jq '.[].body' | grep -i "reward\|#.*PR" | head -20
```

3. **如果有成功的PR，学习它们的解决方案**：
```bash
# 查看PR内容
gh api repos/OWNER/REPO/pulls/PR_NUMBER --jq '.title, .body, .diff_url'
# 如果可以，克隆并查看PR的代码改动
```

4. **在嵌套会话中传递这些信息给 subagent**

**启动嵌套 Claude Code 会话（使用 issue-fixer subagent）**：

```bash
cd /tmp/REPO

# 使用正确的嵌套方式 + issue-fixer agent
env -u CLAUDECODE claude -p --dangerously-skip-permissions \
  --add-git-context # 添加 git 历史 \
  --max-turns 100 << 'PROMPT'
请修复这个 GitHub Issue:
- URL: https://github.com/OWNER/REPO/issues/123
- 标题: Issue 标题
- 描述: Issue 内容
- 赏金: $150

要求：
1. 只修复这个 issue
2. 运行测试确保代码正确
3. 提交更改
4. 如果没有 push 权限，先 fork 仓库再推送
5. 如需要创建 PR，使用 /claim #ISSUE_NUMBER
PROMPT
```

**何时使用 issue-fixer subagent**:
- 当需要修复 GitHub Issue 时
- 当需要分析代码库并实现修复时
- 当需要运行测试验证修复时
- 这是默认的修复方式

### Step 6: 提交并推送

**立即执行提交和推送，不要等待！**

```bash
cd /tmp/REPO
git status
git add .
git commit -m "fix: Issue #123 - $150 bounty"
git push origin main
```

### Step 7: 更新 progress.md

每次完成赏金后，更新 progress.md 总结文档：
- 添加新的 PR 链接
- 更新完成统计

### Step 8: 更新 task.json

```bash
# 更新当前任务状态
jq '.bounties[INDEX].status = "completed"' task.json > tmp.json && mv tmp.json task.json
jq '.completed += 1' task.json > tmp.json && mv tmp.json task.json

# 提交进度
git add task.json progress.md
git commit -m "progress: completed X bounties"
git push
```

### Step 9: 检查是否继续

- 还有 pending 的赏金吗？
- 达到 5 个里程碑了吗？
- 用户要求停止了吗？

如果继续，返回 Step 2。

---

## 📋 任务状态

| 状态 | 含义 | 处理 |
|-----|------|-----|
| pending | 待处理 | 下一个处理 |
| analyzing | 分析中 | 快速决定是否可行 |
| cloning | 克隆中 | 等待克隆完成 |
| fixing | 修复中 | 嵌套 Claude Code |
| completed | 已完成 | ✅ 记录并继续 |
| failed | 失败 | 记录原因，继续 |
| skipped | 跳过 | 不可行，继续 |

---

## ⚠️ 阻塞处理 (Blocking Issues)

**如果任务无法完成，需要人工介入时：**

### 需要停止的情况：

1. **网络完全不可用**：
   - 无法访问 GitHub
   - 多次重试失败

2. **GitHub 权限问题**：
   - 没有 push 权限
   - Token 失效

3. **仓库问题**：
   - 仓库不存在
   - 仓库被删除

### 阻塞时的操作：

**DO NOT（禁止）：**
- ❌ 假装任务完成
- ❌ 提交空更改

**DO（必须）：**
- ✅ 在 progress.txt 记录阻塞原因
- ✅ 更新 task.json 标记为 failed
- ✅ 提交并推送
- ✅ 继续下一个任务

### 阻塞信息格式：

```
🚫 任务阻塞 - 自动跳过

**当前任务**: owner/repo #123 - $150

**阻塞原因**:
- [具体说明为什么无法继续]

**已尝试**:
- [尝试过的方法]

**处理方式**: 标记为 failed，继续下一个
```

---

## 🔬 测试要求 (Testing)

对于代码修复任务：

### 必须验证：
1. **代码编译**：
   ```bash
   npm run build  # 或对应项目的构建命令
   ```

2. **测试通过**（如果有）：
   ```bash
   npm test
   ```

3. **lint 通过**（如果有）：
   ```bash
   npm run lint
   ```

### 测试清单：
- [ ] 代码编译成功
- [ ] 测试通过（如果有）
- [ ] lint 通过（如果有）
- [ ] 功能正常

---

## 重要规则 (Important Rules)

### ⏰ 时间分配

- 单个赏金最大时间: 2 小时
- 超过则标记为 failed，继续下一个

### 🔄 嵌套会话

```bash
# 正确
env -u CLAUDECODE claude -p --dangerously-skip-permissions << 'EOF'
任务描述
EOF
```

### 📝 提交规范

每次提交格式：
```
bounty: 处理完 owner/repo#$123 - $150 - SUCCESS/FAILED/SKIPPED
```

### 🛡️ 上下文保护

1. **不要**在内存中积累所有历史
2. **总是**从 task.json 读取状态
3. **每次**完成任务后立即提交
4. **定期**推送进度到远程

---

## 里程碑报告 (每 5 个赏金)

生成报告：

```markdown
## 里程碑报告 - 第 X 轮

### 统计
- 已完成: N
- 失败: N
- 跳过: N

### 成功的 PR
- [PR 链接 1]
- [PR 链接 2]

### 失败的赏金
- repo#123 - 原因
- repo#456 - 原因

### 网络状态
- [当前网络是否正常]
```

---

## 故障排除

| 问题 | 解决方案 |
|-----|---------|
| 嵌套报错 | 检查 env -u CLAUDECODE |
| 克隆超时 | 标记 failed，继续 |
| 上下文太大 | 立即提交，推送，重新开始 |
| MCP 不可用 | 检查 Playwright MCP 配置 |
| Git push 失败 | 检查 token 权限 |

---

## 目标

- **完全自动化**：只需要一开始的 prompt
- **自我循环**：自动处理下一个赏金
- **防崩溃**：每步都提交，进程可恢复
- **无上下文腐烂**：task.json 是唯一真相来源
- **明确阻塞处理**：不可行时快速跳过

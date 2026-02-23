# Algora Bounty Hunter Agent - 设计文档

## 项目概述

构建一个自动化编程 Agent，能够从 GitHub 搜索赏金 Issues，进行可行性分析，并尝试解决这些问题。

## 核心流程

1. **获取 Issue**：从 GitHub 搜索带有 bounty 标签的 Issues
2. **可行性分析**（混合方式）：
   - 先用规则快速过滤（Issue 描述清晰度、项目有 README、技术栈常见）
   - 再用 AI 深度分析，给出可行性评分
3. **执行任务**：
   - 克隆仓库到临时目录
   - 尝试解决 Issue
   - 成功 → commit & push
   - 超时（基于复杂度 + 10次 commit 失败）→ 跳过
4. **清理**：定时清理临时目录

## 关键配置

- 时间阈值：基于 Issue 复杂度动态调整
- commit 失败阈值：10次（可配置）
- 执行方式：串行处理
- GitHub：公开访问

---

## 架构设计

### 多 Subagent 协同架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Main Agent (Coordinator)                  │
│  - 任务调度                                                  │
│  - 状态管理                                                  │
│  - 结果汇总                                                  │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌───────────┬───────────┬───────────┬───────────┐
        ▼           ▼           ▼           ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│  Issue    │ │   Rule   │ │    AI    │ │   Code    │
│ Fetcher   │ │  Filter  │ │  Analyst  │ │  Agent    │
│ Subagent  │ │ Subagent  │ │ Subagent  │ │  for Issue│
└───────────┘ └───────────┘ └───────────┘ └───────────┘
                                                  │
                                                  ▼
                                          ┌───────────┐
                                          │   Code     │
                                          │  Agent     │
                                          │ for Commit │
                                          └───────────┘
```

### Subagent 职责

| Subagent | 职责 | 输入 | 输出 |
|----------|------|------|------|
| Issue Fetcher | 搜索 GitHub Issues | 搜索关键词 | Issue 列表 |
| Rule Filter | 规则快速过滤 | Issue 列表 | 过滤后的 Issue |
| AI Analyst | AI 深度分析 | Issue 详情 | 可行性评分和建议 |
| Code Agent for Issue | 解决 Issue | Issue 描述 | 代码改动 |
| Code Agent for Commit | Git 提交 | 代码改动 | commit 结果 |

---

## 数据结构

### Issue 数据结构

```typescript
interface BountyIssue {
  id: string;
  url: string;
  title: string;
  description: string;
  repository: string;
  repositoryUrl: string;
  labels: string[];
  createdAt: string;
  updatedAt: string;
  bounty?: string;
}
```

### 可行性分析结果

```typescript
interface FeasibilityAnalysis {
  issueId: string;
  ruleScore: number;           // 0-100
  aiScore: number;             // 0-100
  totalScore: number;          // 综合评分
  estimatedTime: number;       // 预估时间（分钟）
  complexity: 'simple' | 'medium' | 'complex';
  reasons: string[];
  recommended: boolean;
}
```

### 任务状态

```typescript
interface Task {
  id: string;
  issue: BountyIssue;
  analysis: FeasibilityAnalysis;
  status: 'pending' | 'analyzing' | 'working' | 'completed' | 'failed' | 'skipped';
  startTime?: string;
  endTime?: string;
  commits: number;
  error?: string;
}
```

---

## 配置文件

```json
{
  "github": {
    "searchKeywords": ["bounty", "reward", "paid", "hackathon"],
    "sort": "updated",
    "perPage": 30
  },
  "analysis": {
    "minRuleScore": 30,
    "minAiScore": 50,
    "minTotalScore": 60
  },
  "execution": {
    "timeLimits": {
      "simple": 15,
      "medium": 45,
      "complex": 90
    },
    "maxCommitsWithoutProgress": 10,
    "tempDir": "/tmp/bounty-hunter"
  },
  "logging": {
    "enabled": true,
    "dir": "./logs"
  }
}
```

---

## 文件结构

```
claude-agent-framework/
├── docs/
│   └── plans/
│       └── 2026-02-23-algora-bounty-hunter-design.md
├── src/
│   ├── agents/
│   │   ├── issue-fetcher.ts
│   │   ├── rule-filter.ts
│   │   ├── ai-analyst.ts
│   │   ├── code-agent-for-issue.ts
│   │   └── code-agent-for-commit.ts
│   ├── config/
│   │   └── config.ts
│   ├── types/
│   │   └── index.ts
│   ├── utils/
│   │   ├── github.ts
│   │   └── logger.ts
│   └── coordinator.ts
├── config.json
├── task.json
├── progress.txt
└── CLAUDE.md
```

---

## 实现计划

### Phase 1: 基础架构
1. 创建项目结构和类型定义
2. 实现配置文件加载
3. 实现基础工具函数

### Phase 2: Subagent 实现
1. Issue Fetcher - GitHub API 集成
2. Rule Filter - 规则引擎
3. AI Analyst - LLM 分析集成
4. Code Agent for Issue - 代码解决
5. Code Agent for Commit - Git 操作

### Phase 3: 协调器
1. Main Coordinator 实现
2. 任务队列管理
3. 超时和进度检测

### Phase 4: 集成测试
1. 端到端流程测试
2. 清理机制
3. 日志完善

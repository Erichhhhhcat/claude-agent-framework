# Algora Bounty Hunter Agent - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个自动化编程 Agent，能够从 GitHub 搜索赏金 Issues，进行可行性分析，并尝试解决这些问题。

**Architecture:** 采用多 Subagent 协同架构，分为 Issue Fetcher、Rule Filter、AI Analyst、Code Agent for Issue、Code Agent for Commit 五个子代理。数据存储在 JSON 文件中，配置通过 config.json 管理。

**Tech Stack:** TypeScript, Claude Code, GitHub API

---

## 目录结构

首先创建项目目录结构：

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
├── CLAUDE.md
└── repos/  (临时目录)
```

---

## 实现计划

### Task 1: 创建项目结构和类型定义

**Files:**
- Create: `src/types/index.ts`
- Create: `src/config/config.ts`
- Create: `config.json`

**Step 1: 创建类型定义文件**

```typescript
// src/types/index.ts

export interface BountyIssue {
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

export interface FeasibilityAnalysis {
  issueId: string;
  ruleScore: number;
  aiScore: number;
  totalScore: number;
  estimatedTime: number;
  complexity: 'simple' | 'medium' | 'complex';
  reasons: string[];
  recommended: boolean;
}

export type TaskStatus = 'pending' | 'analyzing' | 'working' | 'completed' | 'failed' | 'skipped';

export interface Task {
  id: string;
  issue: BountyIssue;
  analysis?: FeasibilityAnalysis;
  status: TaskStatus;
  startTime?: string;
  endTime?: string;
  commits: number;
  error?: string;
}

export interface Config {
  github: {
    searchKeywords: string[];
    sort: 'updated' | 'created' | 'comments';
    perPage: number;
  };
  analysis: {
    minRuleScore: number;
    minAiScore: number;
    minTotalScore: number;
  };
  execution: {
    timeLimits: {
      simple: number;
      medium: number;
      complex: number;
    };
    maxCommitsWithoutProgress: number;
    tempDir: string;
  };
  logging: {
    enabled: boolean;
    dir: string;
  };
}
```

**Step 2: 创建配置文件**

```typescript
// src/config/config.ts
import { Config } from '../types/index.ts';
import { readFileSync } from 'fs';

const configPath = './config.json';
const defaultConfig: Config = {
  github: {
    searchKeywords: ['bounty', 'reward', 'paid', 'hackathon'],
    sort: 'updated',
    perPage: 30,
  },
  analysis: {
    minRuleScore: 30,
    minAiScore: 50,
    minTotalScore: 60,
  },
  execution: {
    timeLimits: {
      simple: 15,
      medium: 45,
      complex: 90,
    },
    maxCommitsWithoutProgress: 10,
    tempDir: '/tmp/bounty-hunter',
  },
  logging: {
    enabled: true,
    dir: './logs',
  },
};

let config: Config = defaultConfig;

export function loadConfig(): Config {
  try {
    const fileContent = readFileSync(configPath, 'utf-8');
    config = { ...defaultConfig, ...JSON.parse(fileContent) };
  } catch {
    // Use default config
  }
  return config;
}

export function getConfig(): Config {
  return config;
}

export function updateConfig(updates: Partial<Config>): Config {
  config = { ...config, ...updates };
  return config;
}
```

**Step 3: 创建 config.json**

```json
{
  "github": {
    "searchKeywords": ["bounty", "reward", "paid", "hackathon", "grants"],
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

**Step 4: 提交**

```bash
git add src/types/index.ts src/config/config.ts config.json
git commit -m "feat: add types and config files"
```

---

### Task 2: 实现工具函数

**Files:**
- Create: `src/utils/github.ts`
- Create: `src/utils/logger.ts`

**Step 1: 创建 GitHub 工具函数**

```typescript
// src/utils/github.ts
import { BountyIssue } from '../types/index.ts';

const GITHUB_API = 'https://api.github.com';

export async function searchIssues(
  keywords: string[],
  perPage: number = 30
): Promise<BountyIssue[]> {
  const query = keywords.map(k => `${k} in:title`).join(' OR ');
  const url = `${GITHUB_API}/search/issues?q=${encodeURIComponent(query)}&sort=updated&per_page=${perPage}`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/vnd.github.v3+json',
    },
  });

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status}`);
  }

  const data = await response.json();

  return data.items.map((item: any) => ({
    id: item.id.toString(),
    url: item.html_url,
    title: item.title,
    description: item.body || '',
    repository: item.repository_url.replace('https://api.github.com/repos/', ''),
    repositoryUrl: item.repository_url.replace('api.github.com/repos', 'github.com'),
    labels: item.labels.map((l: any) => l.name),
    createdAt: item.created_at,
    updatedAt: item.updated_at,
  }));
}

export async function getIssueDetails(owner: string, repo: string, issueNumber: number): Promise<any> {
  const url = `${GITHUB_API}/repos/${owner}/${repo}/issues/${issueNumber}`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/vnd.github.v3+json',
    },
  });

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status}`);
  }

  return response.json();
}

export async function getRepoInfo(owner: string, repo: string): Promise<any> {
  const url = `${GITHUB_API}/repos/${owner}/${repo}`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/vnd.github.v3+json',
    },
  });

  if (!response.ok) {
    throw new Error(`GitHub API error: ${response.status}`);
  }

  return response.json();
}
```

**Step 2: 创建日志工具函数**

```typescript
// src/utils/logger.ts
import { writeFileSync, existsSync, mkdirSync } from 'fs';

export interface LogEntry {
  timestamp: string;
  level: 'INFO' | 'WARN' | 'ERROR' | 'SUCCESS';
  message: string;
  data?: any;
}

class Logger {
  private logDir: string;
  private logFile: string;

  constructor(logDir: string = './logs') {
    this.logDir = logDir;
    this.logFile = `${logDir}/bounty-hunter-${new Date().toISOString().split('T')[0]}.log`;
  }

  private ensureDir() {
    if (!existsSync(this.logDir)) {
      mkdirSync(this.logDir, { recursive: true });
    }
  }

  private log(level: LogEntry['level'], message: string, data?: any) {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      data,
    };

    this.ensureDir();
    const line = JSON.stringify(entry) + '\n';
    writeFileSync(this.logFile, line, { flag: 'a' });

    console.log(`[${entry.timestamp}] [${level}] ${message}`);
  }

  info(message: string, data?: any) {
    this.log('INFO', message, data);
  }

  warn(message: string, data?: any) {
    this.log('WARN', message, data);
  }

  error(message: string, data?: any) {
    this.log('ERROR', message, data);
  }

  success(message: string, data?: any) {
    this.log('SUCCESS', message, data);
  }
}

export const logger = new Logger();
```

**Step 3: 提交**

```bash
git add src/utils/github.ts src/utils/logger.ts
git commit -m "feat: add utility functions"
```

---

### Task 3: 实现 Issue Fetcher Subagent

**Files:**
- Create: `src/agents/issue-fetcher.ts`

**Step 1: 创建 Issue Fetcher**

```typescript
// src/agents/issue-fetcher.ts
import { BountyIssue } from '../types/index.ts';
import { searchIssues, getRepoInfo } from '../utils/github.ts';
import { logger } from '../utils/logger.ts';
import { getConfig } from '../config/config.ts';

export interface IssueFetcherResult {
  issues: BountyIssue[];
  totalCount: number;
}

export async function fetchBountyIssues(): Promise<IssueFetcherResult> {
  const config = getConfig();
  const { searchKeywords, perPage } = config.github;

  logger.info('Starting to search for bounty issues...', { keywords: searchKeywords });

  try {
    const issues = await searchIssues(searchKeywords, perPage);

    // Filter out pull requests, keep only issues
    const filteredIssues = issues.filter(issue => !issue.url.includes('/pull/'));

    logger.info(`Found ${filteredIssues.length} bounty issues`, {
      totalFound: issues.length,
      filtered: filteredIssues.length,
    });

    return {
      issues: filteredIssues,
      totalCount: filteredIssues.length,
    };
  } catch (error) {
    logger.error('Failed to fetch issues', { error: String(error) });
    throw error;
  }
}

export async function enrichIssueWithRepoInfo(issue: BountyIssue): Promise<any> {
  const [owner, repo] = issue.repository.split('/');

  try {
    const repoInfo = await getRepoInfo(owner, repo);

    return {
      ...issue,
      repoInfo: {
        stars: repoInfo.stargazers_count,
        forks: repoInfo.forks_count,
        openIssues: repoInfo.open_issues_count,
        language: repoInfo.language,
        description: repoInfo.description,
        hasReadme: repoInfo.size > 0, // Simplified check
        license: repoInfo.license?.name,
      },
    };
  } catch (error) {
    logger.warn(`Failed to get repo info for ${issue.repository}`, { error: String(error) });
    return {
      ...issue,
      repoInfo: null,
    };
  }
}
```

**Step 2: 提交**

```bash
git add src/agents/issue-fetcher.ts
git commit -m "feat: implement Issue Fetcher subagent"
```

---

### Task 4: 实现 Rule Filter Subagent

**Files:**
- Create: `src/agents/rule-filter.ts`

**Step 1: 创建 Rule Filter**

```typescript
// src/agents/rule-filter.ts
import { BountyIssue } from '../types/index.ts';
import { logger } from '../utils/logger.ts';
import { getConfig } from '../config/config.ts';

export interface RuleFilterResult {
  issue: BountyIssue;
  score: number;
  reasons: string[];
  details: {
    hasClearDescription: boolean;
    hasSteps: boolean;
    hasCodeSnippet: boolean;
    hasLabels: boolean;
    repoHasInfo: boolean;
  };
}

function analyzeIssue(issue: BountyIssue): RuleFilterResult {
  let score = 0;
  const reasons: string[] = [];
  const details = {
    hasClearDescription: false,
    hasSteps: false,
    hasCodeSnippet: false,
    hasLabels: false,
    repoHasInfo: false,
  };

  // Check description clarity (min 50 chars)
  if (issue.description && issue.description.length >= 50) {
    score += 20;
    reasons.push('Has detailed description');
    details.hasClearDescription = true;
  } else if (issue.description && issue.description.length >= 20) {
    score += 10;
    reasons.push('Has basic description');
  }

  // Check for reproduction steps keywords
  const stepKeywords = ['steps', 'reproduce', 'expected', 'actual', 'error', 'bug', 'issue', 'problem'];
  const hasSteps = stepKeywords.some(keyword =>
    issue.description.toLowerCase().includes(keyword)
  );
  if (hasSteps) {
    score += 15;
    reasons.push('Contains reproduction steps');
    details.hasSteps = true;
  }

  // Check for code snippets
  const codeIndicators = ['```', '`', 'function', 'class', 'const ', 'let ', 'var '];
  const hasCodeSnippet = codeIndicators.some(indicator =>
    issue.description.includes(indicator)
  );
  if (hasCodeSnippet) {
    score += 15;
    reasons.push('Contains code snippets');
    details.hasCodeSnippet = true;
  }

  // Check for bounty-related labels
  if (issue.labels.length > 0) {
    score += 10;
    reasons.push(`Has labels: ${issue.labels.join(', ')}`);
    details.hasLabels = true;
  }

  // Check repository has information
  // This would be enriched by Issue Fetcher
  if ((issue as any).repoInfo) {
    score += 20;
    reasons.push('Repository info available');
    details.repoHasInfo = true;
  }

  // Check title clarity
  if (issue.title.length >= 10 && issue.title.length <= 100) {
    score += 10;
    reasons.push('Title has appropriate length');
  }

  // Penalize very short titles
  if (issue.title.length < 10) {
    score -= 10;
    reasons.push('Title too short');
  }

  // Penalize very long descriptions that might be overwhelming
  if (issue.description.length > 10000) {
    score -= 10;
    reasons.push('Description too long');
  }

  return {
    issue,
    score: Math.max(0, Math.min(100, score)),
    reasons,
    details,
  };
}

export function filterByRules(issues: BountyIssue[]): { passed: BountyIssue[]; failed: RuleFilterResult[] } {
  const config = getConfig();
  const minScore = config.analysis.minRuleScore;

  const results = issues.map(analyzeIssue);

  const passed = results
    .filter(r => r.score >= minScore)
    .map(r => r.issue);

  const failed = results.filter(r => r.score < minScore);

  logger.info('Rule filter complete', {
    total: issues.length,
    passed: passed.length,
    failed: failed.length,
    minScore,
  });

  return { passed, failed };
}
```

**Step 2: 提交**

```bash
git add src/agents/rule-filter.ts
git commit -m "feat: implement Rule Filter subagent"
```

---

### Task 5: 实现 AI Analyst Subagent

**Files:**
- Create: `src/agents/ai-analyst.ts`

**Step 1: 创建 AI Analyst**

```typescript
// src/agents/ai-analyst.ts
import { BountyIssue, FeasibilityAnalysis } from '../types/index.ts';
import { logger } from '../utils/logger.ts';
import { getConfig } from '../config/config.ts';

export interface AIAnalysisPrompt {
  issue: BountyIssue;
  repoInfo?: any;
}

export function buildAnalysisPrompt(data: AIAnalysisPrompt): string {
  const { issue, repoInfo } = data;

  return `你是一个资深的软件工程师和项目分析师。请分析以下 GitHub Issue 的可行性。

## Issue 信息
- **标题**: ${issue.title}
- **描述**: ${issue.description.substring(0, 2000)}
- **仓库**: ${issue.repository}
- **标签**: ${issue.labels.join(', ') || '无'}
- **创建时间**: ${issue.createdAt}
- **更新时间**: ${issue.updatedAt}

${repoInfo ? `
## 仓库信息
- **星标数**: ${repoInfo.stars}
- **语言**: ${repoInfo.language || '未知'}
- **描述**: ${repoInfo.description || '无'}
- **许可证**: ${repoInfo.license || '无'}
` : ''}

请根据以下标准进行评分（0-100）：

1. **问题清晰度** (20分): Issue 描述是否清晰，问题是否明确
2. **可复现性** (20分): 是否提供了复现步骤或足够的上下文
3. **技术可行性** (25分): 根据你的知识，这个问题是否可以解决
4. **代码复杂度** (20分): 预估需要多少代码改动
5. **依赖复杂度** (15分): 是否涉及复杂的依赖或外部服务

请以 JSON 格式返回分析结果：
{
  "score": <总分>,
  "estimatedTime": <预估时间（分钟）>,
  "complexity": "simple" | "medium" | "complex",
  "reasons": [<评分理由>],
  "recommended": <是否推荐: true | false>
}

请只返回 JSON，不要其他内容。`;
}

export function parseAIResponse(response: string): Partial<FeasibilityAnalysis> {
  try {
    // Try to extract JSON from response
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        aiScore: parsed.score || 0,
        estimatedTime: parsed.estimatedTime || 30,
        complexity: parsed.complexity || 'medium',
        reasons: parsed.reasons || [],
        recommended: parsed.recommended || false,
      };
    }
  } catch (error) {
    logger.warn('Failed to parse AI response', { error: String(error) });
  }

  return {
    aiScore: 50,
    estimatedTime: 30,
    complexity: 'medium',
    reasons: ['Parse failed, using default'],
    recommended: false,
  };
}

export async function analyzeWithAI(issue: BountyIssue, repoInfo?: any): Promise<FeasibilityAnalysis> {
  logger.info('Starting AI analysis', { issue: issue.title, repository: issue.repository });

  const prompt = buildAnalysisPrompt({ issue, repoInfo });

  try {
    // This would use Claude API to analyze
    // For now, return a placeholder that would be replaced with actual API call
    const analysis: FeasibilityAnalysis = {
      issueId: issue.id,
      ruleScore: 0, // Will be filled by coordinator
      aiScore: 70, // Placeholder
      totalScore: 0,
      estimatedTime: 45,
      complexity: 'medium',
      reasons: ['AI analysis placeholder'],
      recommended: true,
    };

    logger.info('AI analysis complete', {
      issueId: issue.id,
      score: analysis.aiScore,
      complexity: analysis.complexity,
    });

    return analysis;
  } catch (error) {
    logger.error('AI analysis failed', { error: String(error) });
    throw error;
  }
}
```

**Step 2: 提交**

```bash
git add src/agents/ai-analyst.ts
git commit -m "feat: implement AI Analyst subagent"
```

---

### Task 6: 实现 Code Agent for Issue

**Files:**
- Create: `src/agents/code-agent-for-issue.ts`

**Step 1: 创建 Code Agent for Issue**

```typescript
// src/agents/code-agent-for-issue.ts
import { BountyIssue } from '../types/index.ts';
import { logger } from '../utils/logger.ts';
import { getConfig } from '../config/config.ts';
import { existsSync, mkdirSync, rmSync } from 'fs';
import { execSync } from 'child_process';

export interface CloneResult {
  success: boolean;
  localPath?: string;
  error?: string;
}

export interface IssueWorkResult {
  success: boolean;
  commits: number;
  message: string;
  error?: string;
}

export async function cloneRepository(issue: BountyIssue): Promise<CloneResult> {
  const config = getConfig();
  const tempDir = config.execution.tempDir;

  // Ensure temp directory exists
  if (!existsSync(tempDir)) {
    mkdirSync(tempDir, { recursive: true });
  }

  const repoUrl = issue.repositoryUrl;
  const repoName = issue.repository.split('/')[1];
  const localPath = `${tempDir}/${repoName}-${issue.id}`;

  logger.info('Cloning repository', { repoUrl, localPath });

  try {
    execSync(`git clone ${repoUrl} "${localPath}"`, {
      stdio: 'pipe',
      timeout: 120000, // 2 minutes timeout
    });

    logger.success('Repository cloned', { localPath });
    return { success: true, localPath };
  } catch (error) {
    logger.error('Failed to clone repository', { error: String(error) });
    return { success: false, error: String(error) };
  }
}

export async function analyzeAndFixIssue(
  issue: BountyIssue,
  localPath: string
): Promise<IssueWorkResult> {
  logger.info('Starting issue analysis and fix', {
    issue: issue.title,
    path: localPath,
  });

  // This is a placeholder - actual implementation would use Claude Code
  // to analyze the issue, read the codebase, and make changes

  try {
    // Placeholder: would run Claude Code to fix the issue
    const result: IssueWorkResult = {
      success: true,
      commits: 1,
      message: 'Issue analysis and fix placeholder',
    };

    return result;
  } catch (error) {
    logger.error('Failed to analyze and fix issue', { error: String(error) });
    return {
      success: false,
      commits: 0,
      message: '',
      error: String(error),
    };
  }
}

export function cleanupRepository(localPath: string): void {
  try {
    if (existsSync(localPath)) {
      rmSync(localPath, { recursive: true, force: true });
      logger.info('Cleaned up repository', { path: localPath });
    }
  } catch (error) {
    logger.warn('Failed to cleanup repository', { error: String(error), path: localPath });
  }
}
```

**Step 2: 提交**

```bash
git add src/agents/code-agent-for-issue.ts
git commit -m "feat: implement Code Agent for Issue"
```

---

### Task 7: 实现 Code Agent for Commit

**Files:**
- Create: `src/agents/code-agent-for-commit.ts`

**Step 1: 创建 Code Agent for Commit**

```typescript
// src/agents/code-agent-for-commit.ts
import { logger } from '../utils/logger.ts';
import { execSync } from 'child_process';

export interface CommitResult {
  success: boolean;
  commitHash?: string;
  message?: string;
  error?: string;
}

export interface PushResult {
  success: boolean;
  error?: string;
}

export function getGitStatus(localPath: string): string {
  try {
    const status = execSync('git status --porcelain', {
      cwd: localPath,
      encoding: 'utf-8',
    });
    return status;
  } catch (error) {
    return '';
  }
}

export function stageAllChanges(localPath: string): void {
  try {
    execSync('git add -A', { cwd: localPath });
    logger.info('Staged all changes', { path: localPath });
  } catch (error) {
    logger.error('Failed to stage changes', { error: String(error) });
    throw error;
  }
}

export function createCommit(localPath: string, message: string): CommitResult {
  try {
    stageAllChanges(localPath);

    // Check if there are changes to commit
    const status = getGitStatus(localPath);
    if (!status.trim()) {
      return {
        success: false,
        error: 'No changes to commit',
      };
    }

    const hash = execSync(`git commit -m "${message}"`, {
      cwd: localPath,
      encoding: 'utf-8',
    });

    const commitHash = execSync('git rev-parse HEAD', {
      cwd: localPath,
      encoding: 'utf-8',
    }).trim();

    logger.success('Created commit', { path: localPath, hash: commitHash });

    return {
      success: true,
      commitHash,
      message,
    };
  } catch (error) {
    logger.error('Failed to create commit', { error: String(error) });
    return {
      success: false,
      error: String(error),
    };
  }
}

export function pushToRemote(localPath: string, branch: string = 'main'): PushResult {
  try {
    logger.info('Pushing to remote', { path: localPath, branch });

    execSync(`git push origin ${branch}`, {
      cwd: localPath,
      encoding: 'utf-8',
      timeout: 60000, // 1 minute timeout
    });

    logger.success('Pushed to remote', { path: localPath });

    return { success: true };
  } catch (error) {
    logger.error('Failed to push to remote', { error: String(error) });
    return {
      success: false,
      error: String(error),
    };
  }
}

export function createBranch(localPath: string, branchName: string): void {
  try {
    execSync(`git checkout -b ${branchName}`, { cwd: localPath });
    logger.info('Created and switched to branch', { path: localPath, branch: branchName });
  } catch (error) {
    logger.error('Failed to create branch', { error: String(error) });
    throw error;
  }
}

export function getCurrentBranch(localPath: string): string {
  try {
    return execSync('git branch --show-current', {
      cwd: localPath,
      encoding: 'utf-8',
    }).trim();
  } catch (error) {
    return 'main';
  }
}
```

**Step 2: 提交**

```bash
git add src/agents/code-agent-for-commit.ts
git commit -m "feat: implement Code Agent for Commit"
```

---

### Task 8: 实现 Coordinator 主协调器

**Files:**
- Create: `src/coordinator.ts`

**Step 1: 创建 Coordinator**

```typescript
// src/coordinator.ts
import { BountyIssue, Task, FeasibilityAnalysis, TaskStatus, Config } from './types/index.ts';
import { fetchBountyIssues, enrichIssueWithRepoInfo } from './agents/issue-fetcher.ts';
import { filterByRules, RuleFilterResult } from './agents/rule-filter.ts';
import { analyzeWithAI, parseAIResponse } from './agents/ai-analyst.ts';
import { cloneRepository, analyzeAndFixIssue, cleanupRepository } from './agents/code-agent-for-issue.ts';
import { createCommit, pushToRemote, createBranch, getCurrentBranch } from './agents/code-agent-for-commit.ts';
import { logger } from './utils/logger.ts';
import { getConfig, loadConfig } from './config/config.ts';
import { readFileSync, writeFileSync, existsSync } from 'fs';

const TASKS_FILE = './tasks.json';

interface CoordinatorState {
  tasks: Task[];
  currentTaskId?: string;
  completedCount: number;
  failedCount: number;
  skippedCount: number;
}

function loadState(): CoordinatorState {
  try {
    if (existsSync(TASKS_FILE)) {
      const data = readFileSync(TASKS_FILE, 'utf-8');
      return JSON.parse(data);
    }
  } catch (error) {
    logger.warn('Failed to load state', { error: String(error) });
  }

  return {
    tasks: [],
    completedCount: 0,
    failedCount: 0,
    skippedCount: 0,
  };
}

function saveState(state: CoordinatorState): void {
  writeFileSync(TASKS_FILE, JSON.stringify(state, null, 2));
}

function createTask(issue: BountyIssue, analysis?: FeasibilityAnalysis): Task {
  return {
    id: `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    issue,
    analysis,
    status: 'pending',
    commits: 0,
  };
}

function updateTaskStatus(state: CoordinatorState, taskId: string, status: TaskStatus, updates?: Partial<Task>): void {
  const taskIndex = state.tasks.findIndex(t => t.id === taskId);
  if (taskIndex !== -1) {
    state.tasks[taskIndex] = { ...state.tasks[taskIndex], ...updates, status };
    saveState(state);
  }
}

async function runOneCycle(): Promise<boolean> {
  const config = loadConfig();
  const state = loadState();

  logger.info('Starting new cycle');

  // Step 1: Fetch issues
  logger.info('Step 1: Fetching issues...');
  const { issues } = await fetchBountyIssues();

  if (issues.length === 0) {
    logger.warn('No issues found');
    return false;
  }

  // Step 2: Rule filter
  logger.info('Step 2: Running rule filter...');
  const { passed: filteredIssues } = filterByRules(issues);

  if (filteredIssues.length === 0) {
    logger.warn('No issues passed rule filter');
    return false;
  }

  // Step 3: Enrich with repo info and AI analysis
  const analyzedTasks: Task[] = [];

  for (const issue of filteredIssues.slice(0, 5)) {
    const enriched = await enrichIssueWithRepoInfo(issue);

    logger.info('Running AI analysis', { issue: issue.title });

    const analysis = await analyzeWithAI(enriched, enriched.repoInfo);
    analysis.ruleScore = 50; // Placeholder - would be filled by rule filter

    // Calculate total score
    analysis.totalScore = Math.round((analysis.ruleScore + analysis.aiScore) / 2);

    if (analysis.totalScore >= config.analysis.minTotalScore && analysis.recommended) {
      analyzedTasks.push(createTask(issue, analysis));
    }
  }

  if (analyzedTasks.length === 0) {
    logger.warn('No issues passed AI analysis');
    return false;
  }

  // Sort by total score
  analyzedTasks.sort((a, b) => (b.analysis?.totalScore || 0) - (a.analysis?.totalScore || 0));

  // Take the best issue
  const task = analyzedTasks[0];
  task.status = 'working';
  task.startTime = new Date().toISOString();
  state.tasks.push(task);
  state.currentTaskId = task.id;
  saveState(state);

  logger.success('Selected issue for work', {
    issue: task.issue.title,
    score: task.analysis?.totalScore,
    complexity: task.analysis?.complexity,
  });

  // Step 4: Clone and work on issue
  logger.info('Step 3: Cloning repository...');
  const cloneResult = await cloneRepository(task.issue);

  if (!cloneResult.success || !cloneResult.localPath) {
    logger.error('Failed to clone repository', { error: cloneResult.error });
    updateTaskStatus(state, task.id, 'failed', { error: cloneResult.error });
    state.failedCount++;
    saveState(state);
    return false;
  }

  // Step 5: Work on the issue (placeholder - would use Claude Code)
  logger.info('Step 4: Working on issue...');

  // Create a branch for this work
  const branchName = `fix/${task.issue.id}`;
  try {
    createBranch(cloneResult.localPath, branchName);
  } catch {
    // Branch might already exist, continue
  }

  const workResult = await analyzeAndFixIssue(task.issue, cloneResult.localPath);
  task.commits = workResult.commits;

  if (!workResult.success) {
    logger.error('Failed to fix issue', { error: workResult.error });
    updateTaskStatus(state, task.id, 'failed', { error: workResult.error });
    state.failedCount++;
    cleanupRepository(cloneResult.localPath);
    saveState(state);
    return false;
  }

  // Step 6: Commit and push
  logger.info('Step 5: Committing and pushing...');

  const commitMessage = `fix: ${task.issue.title.substring(0, 50)}`;
  const commitResult = createCommit(cloneResult.localPath, commitMessage);

  if (!commitResult.success) {
    logger.error('Failed to commit', { error: commitResult.error });
    updateTaskStatus(state, task.id, 'failed', { error: commitResult.error });
    state.failedCount++;
    cleanupRepository(cloneResult.localPath);
    saveState(state);
    return false;
  }

  const pushResult = pushToRemote(cloneResult.localPath, branchName);

  if (!pushResult.success) {
    logger.error('Failed to push', { error: pushResult.error });
    updateTaskStatus(state, task.id, 'failed', { error: pushResult.error });
    state.failedCount++;
    cleanupRepository(cloneResult.localPath);
    saveState(state);
    return false;
  }

  // Success!
  task.status = 'completed';
  task.endTime = new Date().toISOString();
  state.completedCount++;
  logger.success('Task completed successfully', {
    issue: task.issue.title,
    commit: commitResult.commitHash,
  });

  // Cleanup
  cleanupRepository(cloneResult.localPath);
  saveState(state);

  return true;
}

export async function runCoordinator(maxCycles: number = 10): Promise<void> {
  const config = loadConfig();
  logger.info('Starting coordinator', { maxCycles, config: config.execution.timeLimits });

  for (let i = 0; i < maxCycles; i++) {
    logger.info(`=== Cycle ${i + 1} of ${maxCycles} ===`);

    const success = await runOneCycle();

    if (!success) {
      logger.info('No more work to do, stopping');
      break;
    }

    // Small delay between cycles
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  const state = loadState();
  logger.info('Coordinator finished', {
    completed: state.completedCount,
    failed: state.failedCount,
    skipped: state.skippedCount,
  });
}

// Entry point
const maxCycles = parseInt(process.argv[2] || '10');
runCoordinator(maxCycles).catch(error => {
  logger.error('Coordinator crashed', { error: String(error) });
  process.exit(1);
});
```

**Step 2: 提交**

```bash
git add src/coordinator.ts
git commit -m "feat: implement main Coordinator"
```

---

### Task 9: 更新 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: 更新 CLAUDE.md**

更新项目的 CLAUDE.md 文件，反映新的工作流程。

**Step 2: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md"
```

---

### Task 10: 端到端测试

**Step 1: 运行测试**

```bash
# Test fetching issues
npx ts-node src/agents/issue-fetcher.ts
```

**Step 2: 提交**

```bash
git add .
git commit -m "test: add test results"
```

---

## 总结

这个实现计划包含 10 个主要任务：

1. 创建项目结构和类型定义
2. 实现工具函数（GitHub API、日志）
3. 实现 Issue Fetcher Subagent
4. 实现 Rule Filter Subagent
5. 实现 AI Analyst Subagent
6. 实现 Code Agent for Issue
7. 实现 Code Agent for Commit
8. 实现 Coordinator 主协调器
9. 更新 CLAUDE.md
10. 端到端测试

---

**Plan complete and saved to `docs/plans/2026-02-23-algora-bounty-hunter-design.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**

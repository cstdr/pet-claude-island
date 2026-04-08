# Claude Island

<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Claude Island</h3>
  <p align="center">
    一款 macOS 菜单栏应用，在灵动岛上展示可爱的动画猫咪
    <br />
    使用像素风格猫咪（Gulu 和 Yiyi）追踪 Claude Code 会话 🐱
    <br />
    <br />
    <a href="https://github.com/cstdr/cat-claude-island/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/cstdr/cat-claude-island?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
  </p>
</div>

## 功能特点

- **动画猫咪图标** — 像素风格猫咪（Gulu & Yiyi）在菜单栏灵动岛上动画展示
  - 空闲状态：睡觉的猫咪
  - 等待状态：坐着的猫咪，尾巴摇摆
  - 运行状态：奔跑的猫咪动画
  - 审批状态：举爪的猫咪
- **灵动岛界面** — 从 MacBook 灵动岛展开的动画悬浮层
- **实时会话监控** — 实时追踪多个 Claude Code 会话
- **权限审批** — 可直接从灵动岛批准或拒绝工具执行
- **聊天历史** — 查看完整的对话历史，支持 Markdown 渲染
- **自动设置** — 首次启动时自动安装钩子

## 系统要求

- macOS 15.6+
- Claude Code CLI

## 安装

下载最新版本或从源码构建：

```bash
xcodebuild -scheme ClaudeIsland -configuration Release build
```

## 工作原理

Claude Island 在 `~/.claude/hooks/` 中安装钩子，通过 Unix 套接字通信会话状态。应用监听事件并在灵动岛悬浮层中显示。

当 Claude 需要运行工具的权限时，灵动岛会展开并显示批准/拒绝按钮——无需切换到终端。

## 分析统计

Claude Island 使用 Mixpanel 收集匿名使用数据：

- **应用启动** — 应用版本、构建号、macOS 版本
- **会话开始** — 检测到新 Claude Code 会话时

不收集任何个人数据或对话内容。

## 许可证

Apache 2.0

# MoonContext

MoonContext 是一个用 MoonBit 编写的上下文构建审计工具。它不要求团队
换掉现有的 Markdown、Mustache 或其他模板库，而是在内容真正送入模型前，
检查最终文本是否满足预算、必需内容和可发布性约束。

## 为什么需要审计上下文

上下文问题经常发生在模板渲染之后：系统提示词被改漏，测试变量残留在
输出中，知识库内容超过模型限制，或者多人维护的 Markdown 出现重复标题。
这些问题通常不会让模板引擎报错，却会直接改变模型行为。把“能否生成文本”
和“这份文本能否进入生产请求”分开检查，才能在 CI 中尽早发现上下文回归。

MoonContext 的输入是已经组装好的 Markdown 或纯文本，输出是稳定的人类可读
报告或 JSON 报告。它检查字符预算、必需标记、未解析的变量占位符和重复
Markdown 标题，并为每个问题给出代码、行列号和退出状态。同一份输入与策略
总是得到相同结果，适合本地开发、发布门禁和代码审查。

## 快速开始

从仓库根目录运行：

~~~text
moon update
moon run cmd/main -- audit examples/audit/context.md \
  --budget 1800 \
  --require "System rules" \
  --require "Evidence"
~~~

需要机器读取时：

~~~text
moon run cmd/main -- audit examples/audit/context.md \
  --budget 1800 --json --report _build/context-audit.json
~~~

命令退出码为：0 表示通过，1 表示发现上下文问题，2 表示参数、输入文件
或报告输出不可用。必需标记可以重复传入，策略不绑定任何模型供应商或
模板语法。

## 项目边界

MoonContext 不重新实现模板渲染器，也不发明新的上下文 DSL。模板引擎负责
把数据渲染成文本，MoonContext 负责审计渲染结果是否可以进入模型调用。这
种边界让它能够与现有应用逐步集成：先在本地运行，再作为 CI 检查，最后将
报告保存到发布构建物中。

仓库中保留了早期的确定性上下文编译流水线，用于实验和兼容已有示例；当前
项目主接口是 audit 命令，后续会围绕策略文件、来源追踪和 CI 集成继续完善。

## 文档

- [审计规则与报告格式](docs/audit.md)
- [可运行示例](docs/examples.md)
- [诊断设计](docs/diagnostics.md)
- [发布流程](docs/releasing.md)

## 全新环境验证

~~~text
moon update
moon fmt --check
moon check --deny-warn
moon test
moon run cmd/main -- audit examples/audit/context.md --budget 1800
~~~

## 许可证

Apache-2.0

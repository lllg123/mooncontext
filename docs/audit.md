# Context audit contract

audit 检查的是已经生成的 Markdown 或纯文本，不关心它由哪一种模板引擎
产生。它把模型请求前最容易被忽略的约束变成可以放进 CI 的门禁。

## 命令

~~~text
moon run cmd/main -- audit <context.md> (--policy <policy.json> | --budget N) [options]
~~~

`audit` 后可以传入多个位置参数，例如：

~~~sh
moon run cmd/main -- audit \
  examples/audit/context.md examples/audit/context-minimal.md \
  --policy examples/audit/policy.json --json \
  --report _build/context-audit-batch.json
~~~

多文件 JSON 报告使用 `artifacts`、`errors` 和 `summary` 三个字段；每个
artifact 保留原有报告结构与指纹，summary 汇总总数、通过数、警告数、失败数
和读取错误数。命令会继续处理后续输入；只要有一个路径无法读取，最终退出码
为 2。

## 比较两次审计报告

~~~text
moon run cmd/main -- diff <before.json> <after.json> [--json] [--report <path>]
~~~

diff 同时接受单文件 audit JSON 和批量报告。它按 artifact 的 path 对齐两份报告，
并把内容指纹或问题代码变化列为 changed；只出现在后一份报告中的路径列为 added，
只出现在前一份报告中的路径列为 removed，其余列为 unchanged。批量报告中的读取
错误也按路径分别列入 errors_added 和 errors_removed。

文本输出显示路径和指纹变化，适合代码审查；加上 json 后会写出稳定的机器可读
对象，包含六个分类数组、summary 计数和 status（changed 或 unchanged）。没有
任何变化时退出码为 0，发现变化时为 1，输入不是有效审计报告或无法读写文件时为 2。
因此可以把 diff 接在发布流水线中，要求审计结果变化必须经过人工确认。

policy path 加载版本化 JSON 策略，budget N 是 Unicode 字符数上限。两者
同时出现时，命令行预算覆盖文件预算；require marker 与 forbid marker 会
追加到文件规则，deny-warnings 只能开启严格模式，不能关闭策略已有的严格
模式。report path 把报告写入文件；json 选择稳定的机器可读格式。命令不会
修改输入文件或策略文件。

## JSON 策略

~~~json
{
  "version": 1,
  "char_budget": 12000,
  "required_markers": ["Safety rules"],
  "forbidden_markers": ["sk-", "TODO"],
  "deny_warnings": true
}
~~~

version 和 char_budget 是必填字段；其余字段分别默认为空数组、空数组和
false。当前只接受 version 1。解析器拒绝未知字段、错误类型、非正预算和空
标记，防止拼写错误或无效配置绕过发布门禁。

## 检查项目

- A1001：文本超过字符预算；
- A1002：缺少必需标记；
- A1003：存在未解析的变量占位符；
- A1004：存在未解析的模板标记；
- A1005：发现禁止出现在发布文本中的标记；
- A2001：Markdown 一级或二级标题重复（警告，不单独导致失败）；
- A0001、A0002、A0003：审计策略本身无效。

报告同时给出内容指纹、字符数、标题数、文件路径、行列号和最终状态。内容
指纹格式为 `sha256:<hex>`，仅由实际审计文本的 UTF-8 字节计算，不包含文件
路径或策略；因此同一内容移动到不同路径后指纹不变，而换行符等任意字节变化
都会产生新指纹。错误使命令返回 1，输入或参数错误返回 2，方便 CI 区分
“内容不合格”和“任务没有正确运行”。该指纹用于构建物关联和完整性比较，
不替代数字签名或来源认证。

## 与模板库的关系

模板库解决“如何从数据生成文本”，审计工具解决“生成的文本是否可以发布”。
二者可以独立升级：应用仍然可以使用 Mustache、Markdown 插值或自己的渲染
代码，只需把最终字符串交给 audit。MoonContext 不执行模板中的函数，不读
隐式环境变量，也不访问网络，因此审计结果只由输入文本和显式策略决定。

## CI 门禁示例

下面的策略同时检查上下文完整性和敏感内容泄漏；它不依赖某个模板引擎，
适用于代码审查、知识库发布和多环境客服流水线：

~~~sh
moon run cmd/main -- audit build/context.md \
  --policy audit-policy.json \
  --json --report _build/context-audit.json
~~~

这样可以把“渲染成功”和“允许进入模型请求”分成两个明确的质量门，
并将报告作为构建物保存，便于代码审查和发布追溯。

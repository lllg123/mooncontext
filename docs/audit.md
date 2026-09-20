# Context audit contract

audit 检查的是已经生成的 Markdown 或纯文本，不关心它由哪一种模板引擎
产生。它把模型请求前最容易被忽略的约束变成可以放进 CI 的门禁。

## 命令

~~~text
moon run cmd/main -- audit <context.md> (--policy <policy.json> | --budget N) [options]
~~~

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

报告同时给出字符数、标题数、文件路径、行列号和最终状态。错误使命令
返回 1，输入或参数错误返回 2，方便 CI 区分“内容不合格”和“任务没有
正确运行”。

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

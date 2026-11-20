# 月鉴 · Yuejian

面向 MoonBit 工具开发者的离线 OSV 版本影响判定库。输入已安装的包清单和指定的漏洞公告，输出逐项判定、原始字段位置和 CI 退出码。

目前为 **0.1.0 源码初版**，尚未发布到 Mooncakes。核心能力、命令和边界均在本仓库内实现；后续计划见 [路线](docs/roadmap.md)。

## 运行真实数据示例

安装 [MoonBit 稳定工具链](https://www.moonbitlang.com/download/)，在仓库根目录执行：

```sh
moon update
moon run lib/cli -- check samples/installed.json samples/RUSTSEC-2020-0071.json
```

这条命令预期退出 **1**，JSON 中有两个结果：`time@0.2.22` 为 `affected`，`time@0.2.23` 为 `not_matched`。样例公告来自 RustSec，输入清单由本项目编写；[来源及摘要](samples/SOURCES.md)记录了获取位置与许可。

这里检查的是公告中的版本范围。该公告还描述了操作系统、函数和构建条件；月鉴保留原文，但不计算这些条件，不能据此推断实际可利用性。

用仅包含修复边界版本的清单检查，预期退出 **0**：

```sh
moon run lib/cli -- check samples/fixed.json samples/RUSTSEC-2020-0071.json
```

输入文件均可替换为自己的数据，不需要账户、API 密钥、数据库或在线漏洞服务。依赖安装完成后，检查和重放均可断网运行。

## 作为库采用

公开包为 `cn-nnzy/mtyuejian`。本仓库提供[独立消费模块](examples/consumer)，通过 `moon.work` 解析本地源码依赖：

```sh
moon -C examples/consumer run . --target wasm --deny-warn
```

该示例会调用公开 API、断言判定结果并打印 JSON。源码版本号不表示已完成注册表发布。需要在自己的模块中集成时，可参照其 `moon.mod`、`moon.pkg` 和 `moon.work`；可执行的 API 示例见 [lib/README.mbt.md](lib/README.mbt.md)。

库的工作流是：

1. `Package::new` 或 `read_inventory` 构造包清单。
2. `read_advisory` 读取 OSV 公告，`Snapshot::new` 固定所选公告版本。
3. `assess` 返回评估，`outcomes`、`to_json`、`exit_code` 提供结果。
4. `Snapshot::to_json` 与 `read_snapshot` 保存和恢复原始输入。

核心库无文件、网络和时钟操作。生成的 [接口文件](lib/pkg.generated.mbti)列出准确的公开签名。

## 文件格式与命令

清单采用封闭的 `inventory-v1` 格式，未知字段和重复 `id` 会报错：

```json
{"schema_version":1,"packages":[{"id":"app/time","ecosystem":"crates.io","name":"time","version":"0.2.22"}]}
```

`id` 由调用方提供，用于区分同名包的多个安装实例。`ecosystem` 和 `name` 精确匹配，不猜测别名、大小写或 PURL 等价关系。

```text
moon run lib/cli -- check INVENTORY.json ADVISORY.json [ADVISORY.json ...]
moon run lib/cli -- snapshot ADVISORY.json [ADVISORY.json ...]
moon run lib/cli -- replay INVENTORY.json SNAPSHOT.json
moon run lib/cli -- capture INVENTORY.json ADVISORY.json [ADVISORY.json ...]
moon run lib/cli -- verify DELIVERY.json
moon run lib/cli -- changes BEFORE.delivery.json CURRENT.delivery.json
moon run lib/cli -- check-cdx BOM.json ADVISORY.json [ADVISORY.json ...]
moon run lib/cli -- sarif DELIVERY.json INVENTORY_URI
moon run lib/cli -- sarif-cdx BOM.json BOM_URI ADVISORY.json [ADVISORY.json ...]
moon run lib/cli -- help
```

`snapshot` 把来源标记和原始公告作为 JSON 文本封装输出。保存该输出为文件后，即可用 `replay` 重新检查任意清单。快照保留未知字段、数字原始 token 和空白；它不提供签名或来源认证。

需要交付完整评估时，用 `capture` 生成包含清单、快照、报告和 SHA-256 摘要的交付包；`verify` 无需原始路径即可重算报告并核对内容。[交付工作流](docs/delivery.md)说明了文件保存、退出码和信任边界。生成交付包成功返回 0，验证则返回报告本身的退出码。

`changes` 验证两份交付包后，列出新增命中、版本或公告变化、证据消失和不确定项。变化门禁与当前评估门禁分别保留，已有漏洞不会因为变化门禁通过而消失，详见[评估变化](docs/changes.md)。

`check-cdx` 接入现有 CycloneDX 1.5/1.6 清单，当前仅精确解析默认 crates.io 的 Cargo PURL。其他组件、缺失身份和冲突字段均保留为未解析项，阻止不完整清单通过。可直接运行[三组 BOM 示例](docs/cyclonedx.md)，无需先手写本项目的清单格式。

`sarif` 与 `sarif-cdx` 输出 SARIF 2.1.0，分别读取已核验交付包和 BOM。报告区分版本命中、未命中与证据缺失，保留完整报告和原始公告快照；退出码仍沿用评估门禁。运行方式、稳定标识及格式校验见 [SARIF 工作流](docs/sarif.md)。

报告与快照写到 stdout，错误诊断写到 stderr。工具只读取输入文件，不修改它们。

| 退出码 | 含义 |
|---|---|
| 0 | 所有相关判定均为 `not_matched`，仅适用于所提供的快照 |
| 1 | 至少有一个已知版本命中；同时保留其他不完整证据 |
| 2 | 输入、格式、资源限制、文件读取或命令用法错误 |
| 3 | 没有已知命中，但存在无法判定、已撤回、缺少公告或缺少包身份的证据 |

没有匹配公告的包返回 `no_advisory`，不能因为数据库缺少记录而得到通过。公告 ID 的别名保留在报告中，不把多个别名统计成多个独立漏洞。

## 当前支持范围

- OSV schema 1.0.0 至 1.9.2 的版本评估子集；这不是完整 OSV JSON Schema 校验器。
- 严格 SemVer 2.0.0：预发布标识符按 ASCII 规则比较，构建元数据不参与范围排序，数字组件不转换为浮点数或固定宽度整数。
- `introduced`、`fixed`、`last_affected`、`limit`，包括 `introduced: "0"`、`limit: "*"`、多个区间和多个 limit 的 OR 语义。
- 原始事件可以无序，报告仍引用原文索引。存在矛盾或无法消歧的转换时拒绝输入。
- `versions` 按原始字符串精确匹配，与可解释范围取并集。同一个 affected 条目含 GIT 范围时，不把其中的版本枚举当作可靠的包版本。
- `ECOSYSTEM`、`GIT` 及未知范围保留为不完整证据。已知正向命中仍报告 `affected`，并保留 `incomplete` 标记。

不支持 Git 图遍历、生态专有版本排序、在线数据库同步、锁文件发现、自动升级建议、VEX 豁免或实际可利用性分析。没有 Mooncakes 公告数据源时，不能把本项目描述为 Mooncakes 全生态漏洞扫描器。

资源限制、错误规则和完整语义见 [评估约定](docs/profile.md)。与已有 MoonBit 包的关系见 [生态边界](docs/ecosystem.md)。

## 验证

当前开发工具链为 `moon 0.1.20261119`、`moonc 0.10.22+124d61d05`。CLI 入口使用工具链提供的 core async，文件适配使用兼容的 `moonbitlang/async@0.22.10`。CI 在 Linux、macOS、Windows 上安装当前稳定版并记录版本。

```sh
moon fmt --check
moon info --target all
moon check --target all --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon run scripts/e2e.mbtx wasm
moon run scripts/e2e.mbtx native
```

核心库以四个后端为验证目标。文件 CLI 支持 Moonrun Wasm 与 native；JavaScript 核心测试需要 Node.js，Windows native 构建需要 MSVC 工具及 Windows SDK。未在对应运行环境执行的检查，不计作运行成功。

测试覆盖真实公告的文件工作流、SemVer 标准排序、生成边界用例、畸形输入、确定性报告、快照往返和失败后的恢复。

## 许可

源码采用 [Apache-2.0](LICENSE)。外部规范、样例公告和依赖的出处与许可单独记录在 [THIRD_PARTY.md](THIRD_PARTY.md)。

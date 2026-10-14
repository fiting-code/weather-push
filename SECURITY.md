# 安全策略

## 支持的版本

| 版本 | 是否维护 |
|---|---|
| 1.0.x | ✅ 是 |

## 报告漏洞

请不要在公开 Issue 中描述安全漏洞。请通过仓库的 **Security → Report a vulnerability** 私下提交，
或在 GitHub 上直接联系维护者。

通常在 3 个工作日内会给出首次回复；确认后 7 个工作日内提供修复方案。

## 密钥泄露处理

本项目**任何情况下都不应包含真实密钥**。若你不慎把密钥提交进了仓库：

1. **立刻到对应平台吊销/重置该密钥**（和风天气控制台、PushPlus、企业微信、Server酱各自后台），
   这一步优先于清理历史 —— 因为 GitHub 的提交历史在被 fork 后无法彻底删除；
2. 从代码中移除密钥，改为环境变量注入；
3. 用 `git filter-repo` 或 BFG 清理提交历史后强推：
   ```bash
   git filter-repo --path .env --invert-paths
   git push --force-with-lease
   ```
4. 确认 `.env`、`*.pem` 已在 `.gitignore` 中（本仓库已配置）。

## 内置的安全设计

- 密钥只通过环境变量读取，代码与示例文件中均为 `YOUR_XXX_HERE` 占位符；
- 日志输出前自动脱敏：URL 查询参数中的 `key`/`token`/`secret`/`access_token` 一律替换为 `***`；
- JWT 私钥通过**文件路径**引用（`WEATHER_JWT_KEY_PATH`），不写入 `.env` 内容；
- Docker 镜像刻意不 `COPY .env`，密钥通过 `--env-file` 注入，不残留在镜像层；
- 项目零第三方依赖，无供应链投毒面。

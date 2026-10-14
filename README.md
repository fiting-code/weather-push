# 每日天气推送到微信（07:00 Asia/Shanghai）

![Node.js](https://img.shields.io/badge/Node.js-%E2%89%A518-brightgreen)

![依赖数量](https://img.shields.io/badge/dependencies-0-brightgreen)

![License](https://img.shields.io/badge/license-MIT-blue)

![Cron](https://img.shields.io/badge/cron-0%2007%20*%20*%20*%20\(Asia%2FShanghai\)-orange)

一个零第三方依赖、可直接上生产的 Node.js 定时任务：每天北京时间 07:00 拉取当日天气预报，  
整理成一条在手机端换行正常、可读性好的简报，推送到微信。

**技术特点**：Node 18+ 原生 `fetch` / `crypto` / `Intl`，**无任何 npm 依赖**（`npm install` 秒完成，  
供应链风险为 0）；天气数据源与推送渠道均为可插拔设计，换供应商只需改环境变量与一处常量。

> 仓库中不含任何密钥或个人信息，所有敏感项均为 `YOUR_XXX_HERE` 占位符，可安全公开。

---

## 一、推送效果预览（手机端）

```
☀️ 深圳 · 2026-10-14 天气简报        ← 标题

📍 深圳　2026-10-14 星期三
────────────────
🌤 白天：多云
🌙 夜间：阴
🌡 气温：24℃ ~ 30℃
🌬 风力：东北风 3-4级
☔ 降水概率：60%
💧 相对湿度：79%
🍃 空气：AQI 42（优）
👔 穿衣：短袖短裤等清凉夏装；降水概率高, 外出记得带伞

—— 由每日天气推送服务自动发送
```

> 换行靠 `\n` + 渠道的 `txt` 模板生效（详见 [第七节](#七推送渠道对比与选择) 的换行要点）。

---

## 二、目录结构

```
weather-push/
├── package.json                 # 依赖清单(零依赖) + npm scripts
├── .env.example                 # 环境变量样例(复制为 .env 后填写)
├── .gitignore                   # 已排除 .env / *.pem / 日志
├── LICENSE                      # MIT
├── SECURITY.md                  # 漏洞报告与密钥泄露处置
├── README.md
├── .github/
│   └── workflows/
│       └── weather-push.yml     # ★ GitHub Actions 定时推送(UTC 23:00 = 北京 07:00)
├── src/
│   ├── index.js                 # 入口: 拉天气 -> 渲染 -> 推送 -> 落日志
│   ├── config.js                # ★ 集中常量: 城市/接收人/文案模板/接口地址/密钥
│   ├── http.js                  # fetch 封装: 超时中断 + 日志脱敏 + 错误归一化
│   ├── retry.js                 # ★ 指数退避重试(1s → 2s → 4s, 最多 3 次)
│   ├── logger.js                # JSON 结构化日志, 按天切分到 logs/
│   ├── formatter.js             # ★ 文案渲染 + 长度裁剪(字符/字节双模式)
│   ├── weather/
│   │   ├── index.js             # 数据源工厂(多城市, 单城失败不影响其他城)
│   │   ├── qweather.js          # 数据源A: 和风天气(字段最全)
│   │   ├── openmeteo.js         # 数据源B: Open-Meteo(免密钥, 便于调试/兜底)
│   │   └── utils.js             # 归一化: 风向/风级/WMO中文/AQI等级/穿衣规则
│   └── push/
│       ├── index.js             # 渠道工厂 + 推送重试
│       ├── pushplus.js          # 渠道A: PushPlus(默认)
│       ├── wecom.js             # 渠道B: 企业微信应用消息
│       └── serverchan.js        # 渠道C: Server酱 Turbo
├── deploy/
│   ├── weather-push.service     # systemd 服务单元
│   ├── weather-push.timer       # ★ systemd 定时器(显式 TimeZone=Asia/Shanghai)
│   └── crontab.example          # crontab 方案
├── Dockerfile                   # 容器内 crond 定时方案
├── scripts/
│   └── selftest.cjs             # 自检: 重试次数/长度裁剪/渲染降级(11 项断言)
└── logs/
    └── .gitkeep                 # 运行时日志目录(日志本身已 gitignore)
```

---

## 三、依赖清单

| 类别     | 名称      | 版本                        | 说明                                             |
| ------ | ------- | ------------------------- | ---------------------------------------------- |
| 运行时    | Node.js | **≥ 18.0**（推荐 20 LTS）     | 依赖内置 `fetch`、`AbortController`、`crypto`、`Intl` |
| npm 依赖 | —       | **零依赖**                   | `dependencies` 为空；`npm install` 仅做校验           |
| 外部服务   | 天气数据源   | 和风天气 / Open-Meteo         | 见第五节                                           |
| 外部服务   | 推送渠道    | PushPlus / 企业微信 / Server酱 | 见第七节                                           |

> 为什么坚持零依赖：定时任务最怕"某天 npm 装不上了 / 某个包被投毒"。  
> 本项目用标准库覆盖了 JSON 请求、JWT 签名（Ed25519）、时区日期计算、日志、重试，全部功能自足。

---

## 四、快速开始（本地 5 分钟跑通）

无需申请任何密钥，用免密钥数据源先跑通全链路：

```bash
cd weather-push

# 1) 复制环境变量模板（先用 open-meteo, 不需要任何密钥）
cp .env.example .env
#    编辑 .env: WEATHER_PROVIDER=open-meteo

# 2) 配置自检（不联网, 检查城市/渠道/密钥是否齐备）
node src/index.js --check

# 3) 预览: 真实请求天气接口, 但【不真正推送】, 打印最终排版
node src/index.js --dry-run
#   等价: npm run dry-run

# 4) 逻辑自检（重试次数 / 长度裁剪 / 字段降级, 11 项断言）
npm test
```

确认排版满意后，再填入真实密钥（见第五、第七节）执行 `node src/index.js` 真正推送。

**命令行参数**

| 参数                      | 作用                 |
| ----------------------- | ------------------ |
| `--dry-run`             | 只渲染并打印，不发送（本地调试首选） |
| `--check`               | 只做配置自检，不联网         |
| `--provider=open-meteo` | 临时覆盖数据源            |
| `--channel=pushplus`    | 临时覆盖推送渠道           |

**退出码**：`0` 成功 / `1` 失败 —— cron、systemd、云函数、CI 均可据此判定任务成败并告警。

---

## 五、环境变量说明

复制 `.env.example` 为 `.env` 后填写。**进程级环境变量优先级高于 `.env` 文件**，  
因此生产环境用 CI Secrets / Docker `--env-file` 注入更安全（密钥不落盘）。

### 5.1 运行时

| 变量          | 默认值             | 说明                                  |
| ----------- | --------------- | ----------------------------------- |
| `TZ`        | `Asia/Shanghai` | 时区，决定"今天"的判定与所有日期展示                 |
| `LOG_LEVEL` | `info`          | `debug` / `info` / `warn` / `error` |

### 5.2 天气数据源

| 变量                     | 默认值                                         | 说明                                   |
| ---------------------- | ------------------------------------------- | ------------------------------------ |
| `WEATHER_PROVIDER`     | `qweather`                                  | `qweather`（字段最全）或 `open-meteo`（免密钥）  |
| `WEATHER_API_BASE`     | `https://devapi.qweather.com/v7`            | 和风接口地址，换地域/自建网关时改这里                  |
| `WEATHER_API_KEY`      | 空                                           | 和风控制台创建的凭据 KEY                       |
| `WEATHER_JWT_KEY_ID`   | 空                                           | 和风 JWT 凭据的 `kid`（选填）                 |
| `WEATHER_JWT_SUB`      | 空                                           | 和风 JWT 凭据的 `sub`（选填）                 |
| `WEATHER_JWT_KEY_PATH` | 空                                           | Ed25519 私钥**文件路径**（不要把私钥内容写进 `.env`） |
| `OPEN_METEO_BASE`      | `https://api.open-meteo.com/v1`             | Open-Meteo 预报接口                      |
| `OPEN_METEO_AIR_BASE`  | `https://air-quality-api.open-meteo.com/v1` | Open-Meteo 空气质量接口                    |

> **鉴权自动降级**：三个 JWT 变量全填 → 走 `Authorization: Bearer <EdDSA JWT>`（代码内自动签名并缓存）；  
> 否则走 `?key=xxx`。切换只需改环境变量，业务代码零改动。

### 5.3 推送渠道

| 变量                                                       | 默认值        | 说明                                                     |
| -------------------------------------------------------- | ---------- | ------------------------------------------------------ |
| `PUSH_CHANNEL`                                           | `pushplus` | `pushplus` / `wecom` / `serverchan`                    |
| `PUSHPLUS_TOKEN`                                         | 空          | PushPlus token                                         |
| `PUSHPLUS_TEMPLATE`                                      | `txt`      | **保持 `txt` 才能用 `\n` 正常换行**；另有 `html`/`json`/`markdown` |
| `PUSHPLUS_TOPIC`                                         | 空          | 群组编码，留空 = 一对一推送                                        |
| `WECOM_CORP_ID` / `WECOM_CORP_SECRET` / `WECOM_AGENT_ID` | 空          | 企业微信自建应用三件套                                            |
| `WECOM_TO_USER`                                          | `@all`     | 接收成员，`userid1\|userid2` 或 `@all`                       |
| `SERVERCHAN_SEND_KEY`                                    | 空          | Server酱 Turbo 的 SendKey（`SCT` 开头）                      |

### 5.4 重试与长度

| 变量                    | 默认值     | 说明                                 |
| --------------------- | ------- | ---------------------------------- |
| `MAX_RETRIES`         | `3`     | 最大重试次数（不含首次，即最多 4 次尝试）             |
| `RETRY_BASE_DELAY_MS` | `1000`  | 退避基数，实际间隔 1s → 2s → 4s（含 0~30% 抖动） |
| `REQUEST_TIMEOUT_MS`  | `10000` | 单次 HTTP 超时，防定时任务卡死                 |
| `MAX_MESSAGE_CHARS`   | `800`   | 自定义长度上限，与渠道硬限制取**小值**              |

---

## 六、定时触发：每天 07:00（Asia/Shanghai）

代码本身**不内置调度器**——定时任务交给平台调度是更可靠的做法（避免常驻进程内存泄漏、  
避免进程被杀后彻底不跑）。下面给出五种可落地方案，按推荐度排序。

### 方案 A：systemd timer（Linux 服务器，推荐 ✅）

`OnCalendar` + 显式 `TimeZone`，语义最清晰，且天然具备：开机补跑、失败重试、日志进 journald。

```bash
sudo useradd -r -s /usr/sbin/nologin weather          # 专用低权限用户
sudo mkdir -p /opt/weather-push && sudo cp -r . /opt/weather-push/
sudo cp deploy/weather-push.service deploy/weather-push.timer /etc/systemd/system/
sudo chown -R weather:weather /opt/weather-push

sudo systemctl daemon-reload
sudo systemctl enable --now weather-push.timer        # 开机自启 + 立即生效

# 常用运维命令
systemctl list-timers weather-push.timer              # 查看下次触发时间
systemctl start weather-push.service                  # 手动立即跑一次
journalctl -u weather-push -f                         # 实时日志
```

关键配置（`deploy/weather-push.timer`）：

```ini
[Timer]
OnCalendar=*-*-* 07:00:00
TimeZone=Asia/Shanghai       # ★ 显式时区, 不受服务器本地时区影响
RandomizedDelaySec=60        # 随机延迟 0~60s, 避免多机同秒打爆接口配额
Persistent=true              # 07:00 关机则开机后补跑
```

### 方案 B：crontab（最简单）

```bash
crontab deploy/crontab.example
# 或手工添加:
# TZ=Asia/Shanghai
# 0 7 * * * cd /opt/weather-push && /usr/bin/node src/index.js >> logs/cron.out 2>&1
```

⚠️ 注意：cron 环境不带 `PATH`，必须写 node 绝对路径；部分发行版需在 crontab 顶部声明 `TZ=Asia/Shanghai`  
并 `systemctl restart cron` 才生效。

### 方案 C：Docker（容器内 crond）

```bash
docker build -t weather-push:1.0 .
docker run -d --name weather-push --restart unless-stopped \
  --env-file .env \
  -e TZ=Asia/Shanghai \
  weather-push:1.0

docker exec weather-push node src/index.js --dry-run   # 容器内调试
docker logs -f weather-push
```

镜像**刻意不 COPY `.env`**，密钥通过 `--env-file` 或 `-e` 注入，不会留在镜像层里。

### 方案 D：GitHub Actions（零服务器）

工作流位于 `.github/workflows/weather-push.yml`，密钥配置到  
`Settings → Secrets and variables → Actions`：

| Secret 名称         | 用途                                                          |
| ----------------- | ----------------------------------------------------------- |
| `WEATHER_API_KEY` | 和风天气凭据（用 `open-meteo` 数据源时可不配）                              |
| `PUSHPLUS_TOKEN`  | PushPlus token（换渠道时改为对应的 `WECOM_*` / `SERVERCHAN_SEND_KEY`） |

```yaml
- cron: '0 23 * * *'   # ★ GitHub 固定用 UTC: 23:00 UTC = 次日 07:00 北京时间
```

工作流特点：手动触发时可勾选 `dry_run` 只预览不推送；执行前先跑 `npm run check` 做配置自检，  
密钥缺失会在这一步就明确报错；已配置 `permissions: contents: read` 最小权限。

⚠️ 局限：高峰期可能延迟 5~20 分钟；公共仓库 60 天无活动会自动停用定时触发器。  
追求准点请选方案 A。

### 方案 E：云函数（腾讯云 SCF / 阿里云 FC）

定时触发器 Cron 表达式（**7 位，含秒，默认北京时间**）：

```
0 0 7 * * * *     # 每天 07:00:00
```

入口填 `src/index.js` 的 `main`，环境变量在控制台配置。  
适合"完全不想管服务器"，注意配置超时时间 > 接口超时 × 重试次数（建议 60s）。

---

## 七、推送渠道对比与选择

| 渠道                | 每日条数                                | 是否需认证                                  | 是否需绑定设备 | 到达位置       | 其他限制                                                                 |
| ----------------- | ----------------------------------- | -------------------------------------- | ------- | ---------- | -------------------------------------------------------------------- |
| **PushPlus**（默认）  | 免费版约 **200 条/天**                    | **否** — 微信扫码登录即可获取 token，无需公众号/企业认证    | **否**   | 微信公众号（服务号） | 一对一免费；一对多「群组」推送需开通会员；`content` 上限约 2000 字符                           |
| **企业微信应用消息**      | 无明确每日条数上限，但有**接口级频率限制**（勿对同一成员高频发送） | **否** — 免费注册企业微信即可发应用消息（未认证企业部分高级接口受限） | **否**   | 企业微信 App   | 需新建自建应用；需把出口 IP 配到「企业可信IP」；接收人须在应用可见范围内；文本消息 ≤ **2048 字节**（约 682 汉字） |
| **Server酱 Turbo** | 免费版约 **5 条/天**                      | **否**                                  | **否**   | 微信公众号（服务号） | 标题 ≤ 32 字符（代码已自动裁剪）；超出条数需开通会员                                        |

> 表中配额与限制以各平台官方文档为准，可能随运营策略调整；代码内已按上述数值预留安全余量。

**怎么选**

- 个人自用、想立刻用起来 → **PushPlus**（200 条/天对 1 天 1 条绰绰有余）
- 团队/公司内部通知，且已在用企业微信 → **企业微信应用消息**（免费、稳定、可 `@all`）
- 已有 Server酱 账号且只需 1 条/天 → **Server酱**

**手机端换行要点**（最容易踩的坑）

- PushPlus：`.env` 里 `PUSHPLUS_TEMPLATE=txt`，`content` 中的 `\n` 会正常换行；  
  若改成 `html` 模板，则必须把 `\n` 换成 `<br/>`，否则微信里会挤成一坨。
- 企业微信：文本消息原生支持 `\n`，天然换行，但要盯住 2048 字节上限。
- Server酱：`desp` 支持 Markdown，`\n` 换行即可，标题超 32 字符会被截断。

---

## 八、健壮性设计

**1）指数退避重试（`src/retry.js`）**

- 最多 **3 次重试**（即最多 4 次尝试），间隔 `1s → 2s → 4s`（`base × 2^n`），叠加 0~30% 随机抖动防惊群；
- 只对**值得重试**的错误重试：网络错误、超时（`AbortController` 中断）、`5xx`、`429` 限流；  
  `401/403`（密钥错）、`400`（参数错）等**立即失败**，不浪费配额；
- 尊重服务端 `Retry-After` 头；
- 天气、推送两条链路**各自独立重试**；多城市场景下**单城失败不影响其他城市**。

**2）失败即留痕**

- 全链路 JSON 结构化日志，同时写 stdout 与 `logs/YYYY-MM-DD.log`；
- 日志自动**脱敏**：URL 中 `key`/`token`/`secret`/`access_token` 一律替换为 `***`，密钥不会进日志；
- 天气全失败时**仍推送一条"获取失败"简报**（含失败原因与重试次数），而不是静默什么都不发；
- 任何未捕获异常都会打印可读错误 + 非零退出码，便于调度器告警。

**3）长度控制（`src/formatter.js`）**

- 渠道硬限制与 `MAX_MESSAGE_CHARS` 取**小值**；
- 企业微信按 **UTF-8 字节**裁剪（中文 3 字节，不能按字符数算），其余按字符数；
- 超限优先**从尾部整行丢弃**次要信息（落款 → 穿衣 → 湿度 → …），核心天气行永远保留；
- 仍超限才硬截断并加 `…`，保证服务端不会再二次截断或报错。

**4）降级不崩**

- 空气质量、穿衣指数、逐小时降水概率属于"增强信息"，任一接口失败只降级为占位符/本地规则，  
  不影响主流程推送；
- 所有数值字段缺失统一渲染为 `暂无`，绝不出现 `undefined` / `NaN`（自检脚本有断言覆盖）。

---

## 九、常见排错

| 现象                             | 原因与处理                                                              |
| ------------------------------ | ------------------------------------------------------------------ |
| `配置自检未通过: 未配置 WEATHER_API_KEY` | 填 KEY，或临时设 `WEATHER_PROVIDER=open-meteo` 先用免密钥数据源                  |
| `HTTP 401 / 和风 code=401`       | KEY 无效或 JWT 凭据三件套不匹配；JWT 模式检查私钥路径与 `kid`/`sub`                     |
| `和风 code=402`                  | 当日调用配额耗尽（免费版 1000 次/天）；已用尽配额不再重试，避免雪上加霜                            |
| 微信里收到消息但**没有换行**               | `PUSHPLUS_TEMPLATE` 被设成了 `html`；改回 `txt`                           |
| 企业微信 `errcode=60020`           | 出口 IP 未加入应用「企业可信IP」白名单                                             |
| 企业微信 `errcode=81013`           | `touser` 不在应用可见范围内，或 `agentid` 填错                                  |
| 定时任务没在 07:00 触发                | 用 `systemctl list-timers` 核对下次触发时间；crontab 场景核对 `TZ` 是否生效          |
| 时区差 8 小时                       | 确认 `.env` 的 `TZ=Asia/Shanghai` 已加载（systemd 用 `EnvironmentFile` 注入） |



---

## 十、安全与隐私

- 仓库与示例代码中**不含任何真实密钥、token、企业 ID 或个人手机号**，全部为 `YOUR_XXX_HERE` 占位符；
  若发生密钥泄露，按 [SECURITY.md](SECURITY.md) 的流程处置；
- `.env`、`*.pem`、`logs/` 均已加入 `.gitignore`；
- 密钥**只走环境变量**（CI Secrets / Docker `--env-file` / systemd `EnvironmentFile`），不写入源码或镜像层；
- 日志输出前自动脱敏，URL 查询参数中的凭据不会落盘；
- 集中常量（`src/config.js`）中的城市、接收人均为可替换的通用示例值。

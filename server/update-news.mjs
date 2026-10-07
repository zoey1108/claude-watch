// 抓取 Claude 相关新闻 → 用 Claude 改写成手表卡片 → 写入 docs/cards.json
// 由 GitHub Actions 每 3 小时运行一次。本地试跑：node server/update-news.mjs --dry（不调用 Claude）
// 改写方式：有 ANTHROPIC_API_KEY 走 API；有 CLAUDE_CODE_OAUTH_TOKEN 走 Claude 订阅；都没有则保留英文原标题
import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import Anthropic from "@anthropic-ai/sdk";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CARDS_FILE = path.join(ROOT, "docs/cards.json");
const STATE_FILE = path.join(ROOT, "server/state.json");
const DRY = process.argv.includes("--dry");
const MODEL = process.env.CLAUDE_MODEL || "claude-opus-5-5";
const MAX_NEW_PER_RUN = 6;   // 每次最多处理几条，控制费用
const KEEP_CARDS = 40;       // cards.json 保留的新闻条数
const FIRST_RUN_TAKE = 3;    // 首次运行每个来源只取最新几条

const today = () => new Date().toISOString().slice(0, 10);

async function readJSON(file, fallback) {
  try { return JSON.parse(await fs.readFile(file, "utf8")); } catch { return fallback; }
}

async function getText(url) {
  const res = await fetch(url, { headers: { "user-agent": "claude-watch-news/1.0" }, signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`${url} → HTTP ${res.status}`);
  return res.text();
}

function htmlToText(html) {
  return html
    .replace(/<(script|style|noscript|svg)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&#x27;|&#39;/g, "'").replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

const meta = (html, name) =>
  html.match(new RegExp(`<meta[^>]+(?:property|name)="${name}"[^>]+content="([^"]*)"`, "i"))?.[1];

// ---------- 来源 ----------

/** Anthropic 官网新闻 */
async function anthropicNews() {
  const html = await getText("https://www.anthropic.com/news");
  const slugs = [...new Set([...html.matchAll(/href="\/news\/([a-z0-9-]+)"/g)].map((m) => m[1]))].slice(0, 10);
  return slugs.map((slug) => ({
    key: `news:${slug}`,
    url: `https://www.anthropic.com/news/${slug}`,
    async load() {
      const page = await getText(this.url);
      const title = meta(page, "og:title") || page.match(/<title>([^<]*)<\/title>/i)?.[1] || slug;
      const desc = meta(page, "og:description") || meta(page, "description") || "";
      const body = htmlToText(page.match(/<article[\s\S]*?<\/article>/i)?.[0] || page).slice(0, 8000);
      return { source: "Anthropic 官网新闻", title, text: `${desc}\n\n${body}` };
    },
  }));
}

/** Claude Code 更新日志（每个版本一条） */
async function claudeCodeChangelog() {
  const md = await getText("https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md");
  const sections = md.split(/^## /m).slice(1, 6);
  return sections.map((sec) => {
    const version = sec.split("\n", 1)[0].trim();
    return {
      key: `cc:${version}`,
      url: "https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md",
      async load() {
        return { source: "Claude Code 更新日志", title: `Claude Code ${version}`, text: sec.slice(0, 8000) };
      },
    };
  });
}

// ---------- 改写成卡片 ----------

const SYSTEM = `你负责为一个 Apple Watch 小应用写「Claude 新闻卡片」，读者是普通中文用户。
把给你的英文原文改写成一张中文卡片：
- title：不超过 14 个汉字，说清楚发生了什么，不要标点结尾
- body：不超过 50 个汉字，讲对用户有什么用或影响；不要照搬原文句子，不要营销腔
- tag：从 "Claude Code"、"Claude App"、"API"、"Anthropic" 中选最贴切的一个
- skip：如果内容和 Claude 用户关系不大（如纯招聘、纯安全修复、纯内部细节），设为 true
更新日志只挑用户最能感知的 1–2 个变化来写，忽略 bug 修复。`;

const SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    body: { type: "string" },
    tag: { type: "string", enum: ["Claude Code", "Claude App", "API", "Anthropic"] },
    skip: { type: "boolean" },
  },
  required: ["title", "body", "tag", "skip"],
  additionalProperties: false,
};

// 三种改写方式：API Key → Claude API；订阅令牌 → Claude Code 命令行；都没有 → 直接用英文原标题
const MODE = DRY ? "dry"
  : process.env.ANTHROPIC_API_KEY ? "api"
  : process.env.CLAUDE_CODE_OAUTH_TOKEN ? "subscription"
  : "plain";
const client = MODE === "api" ? new Anthropic() : null;

const userPrompt = (item, raw) =>
  `来源：${raw.source}\n标题：${raw.title}\n链接：${item.url}\n\n<原文>\n${raw.text}\n</原文>`;

/** 按单词截断，结尾补省略号 */
function clip(text, max) {
  text = text.replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  return cut.slice(0, Math.max(cut.lastIndexOf(" "), max * 0.6)).replace(/[\s,.;:—-]+$/, "") + "…";
}

/** 不用 AI 时的卡片：新闻取标题+摘要首句，更新日志挑第一条新功能 */
function plainCard(item, raw) {
  if (item.key.startsWith("cc:")) {
    const bullets = raw.text.split("\n").filter((l) => l.startsWith("- ")).map((l) => l.slice(2));
    const pick = bullets.find((b) => /^(Added|New|Introduced)/i.test(b)) || bullets[0] || "";
    const extra = bullets.length > 1 ? ` (+${bullets.length - 1} more)` : "";
    return { title: `${raw.title} 更新`, body: clip(pick.replace(/`/g, ""), 110 - extra.length) + extra,
             tag: "Claude Code", skip: !pick };
  }
  const first = raw.text.split(/(?<=[.!?])\s/)[0] || raw.text;
  return { title: clip(raw.title, 50), body: clip(first, 110), tag: "Anthropic", skip: false };
}

/** 用 Claude 订阅（claude setup-token 生成的令牌）通过 Claude Code 命令行改写 */
async function viaClaudeCode(item, raw) {
  const args = ["-p", "--output-format", "json", "--tools", "",
    "--system-prompt", SYSTEM, "--json-schema", JSON.stringify(SCHEMA)];
  if (process.env.CLAUDE_MODEL) args.push("--model", process.env.CLAUDE_MODEL);
  const stdout = await new Promise((resolve, reject) => {
    const child = execFile("claude", args, { maxBuffer: 10 * 1024 * 1024, timeout: 180_000 },
      (err, out, errOut) => (err ? reject(new Error(errOut || err.message)) : resolve(out)));
    child.stdin.end(userPrompt(item, raw));
  });
  const result = JSON.parse(stdout);
  if (result.is_error) throw new Error(result.result || "claude 返回错误");
  if (result.structured_output) return result.structured_output;
  const json = String(result.result).match(/\{[\s\S]*\}/)?.[0];
  return json ? JSON.parse(json) : null;
}

async function toCard(item, raw) {
  if (MODE === "dry" || MODE === "plain") return plainCard(item, raw);
  if (MODE === "subscription") return viaClaudeCode(item, raw);
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 2000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
    system: SYSTEM,
    messages: [{ role: "user", content: userPrompt(item, raw) }],
  });
  if (response.stop_reason !== "end_turn") {
    console.warn(`  跳过 ${item.key}：stop_reason=${response.stop_reason}`);
    return null;
  }
  const text = response.content.find((b) => b.type === "text")?.text;
  return text ? JSON.parse(text) : null;
}

// ---------- 主流程 ----------

async function main() {
  const state = await readJSON(STATE_FILE, { seen: [] });
  const feed = await readJSON(CARDS_FILE, { updated: null, cards: [] });
  const seen = new Set(state.seen);
  const firstRun = seen.size === 0;

  const sources = await Promise.allSettled([anthropicNews(), claudeCodeChangelog()]);
  let candidates = [];
  for (const s of sources) {
    if (s.status === "rejected") { console.warn("来源失败：", s.reason.message); continue; }
    const fresh = s.value.filter((item) => !seen.has(item.key));
    if (firstRun) {
      // 首次运行：只处理每个来源最新几条，其余直接记为已处理
      fresh.slice(FIRST_RUN_TAKE).forEach((item) => seen.add(item.key));
      candidates.push(...fresh.slice(0, FIRST_RUN_TAKE));
    } else {
      candidates.push(...fresh);
    }
  }
  candidates = candidates.slice(0, MAX_NEW_PER_RUN);
  console.log(`待处理 ${candidates.length} 条（方式 ${MODE}${MODE === "api" ? " / " + MODEL : ""}）`);

  const added = [];
  for (const item of candidates) {
    try {
      const raw = await item.load();
      const card = await toCard(item, raw);
      seen.add(item.key);
      if (!card || card.skip) { console.log(`  略过 ${item.key}`); continue; }
      added.push({
        id: item.key.replace(/[^a-z0-9.-]+/gi, "-"),
        type: "news",
        title: card.title,
        body: card.body,
        tag: card.tag,
        url: item.url,
        date: today(),
      });
      console.log(`  ✓ ${card.title}`);
    } catch (err) {
      console.warn(`  失败 ${item.key}：${err.message}`); // 不记为已处理，下次重试
    }
  }

  // 英文原标题模式不记录处理状态：以后配好令牌，同一条会用中文版重写并替换
  if (!DRY && MODE !== "plain") {
    await fs.writeFile(STATE_FILE, JSON.stringify({ seen: [...seen].slice(-500) }, null, 1) + "\n");
  }
  const replaced = new Set(added.map((c) => c.id));
  const cards = [...added, ...feed.cards.filter((c) => !replaced.has(c.id))].slice(0, KEEP_CARDS);
  // 内容没变就不写文件，避免每次都产生空提交
  const changed = !feed.updated || JSON.stringify(cards) !== JSON.stringify(feed.cards);
  if (changed) {
    const out = JSON.stringify({ updated: new Date().toISOString(), cards }, null, 1) + "\n";
    if (DRY) console.log(out.slice(0, 1500));
    else await fs.writeFile(CARDS_FILE, out);
  }
  console.log(`新增 ${added.length} 条`);
}

main().catch((err) => { console.error(err); process.exit(1); });

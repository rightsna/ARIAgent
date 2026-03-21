import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { chromium } from "playwright";
import { logger } from "../infra/logger";

export const webFetchTool: AgentTool = {
  name: "web_fetch",
  label: "웹 페이지 정보 가져오기",
  description: "특정 URL의 웹 페이지 내용을 텍스트 형식으로 긁어옵니다. 최신 뉴스, 블로그 기사 등을 읽을 때 사용합니다.",
  parameters: Type.Object({
    url: Type.String({ description: "정보를 가져올 웹 페이지 URL" }),
    render_js: Type.Optional(
      Type.Boolean({
        description: "자바스크립트 렌더링이 필요한지 여부 (기본값: true)",
        default: true,
      }),
    ),
  }),
  execute: async (_toolCallId, params) => {
    const { url, render_js = true } = params as any;
    let browser = null;

    try {
      logger.info(`[WebFetch] Fetching ${url} (JS=${render_js})`);

      browser = await chromium.launch({ headless: true });
      const context = await browser.newContext({
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      });
      const page = await context.newPage();

      // 속도 향상을 위해 이미지/미디어 로딩 차단
      await page.route("**/*.{png,jpg,jpeg,gif,webp,svg,ico,mp4,webm,ogg}", (route) => route.abort());

      // networkidle은 너무 오래 걸릴 수 있으므로 'load' 사용
      await page.goto(url, { waitUntil: render_js ? "load" : "domcontentloaded", timeout: 20000 });

      const title = await page.title();

      // 가독성을 위해 불필요한 태그 제거 (script, style, nav, footer 등)
      await page.evaluate(() => {
        const toRemove = ["script", "style", "nav", "footer", "header", "aside", "noscript", "iframe"];
        toRemove.forEach((tag) => {
          // @ts-ignore: document is available in browser context
          const nodes = document.querySelectorAll(tag);
          nodes.forEach((node: any) => node.remove());
        });
      });

      const content = await page.innerText("body");
      const cleanContent = content
        .replace(/\n\s*\n/g, "\n\n") // 여러 줄 공백 제거
        .trim();

      await browser.close();

      return {
        content: [
          {
            type: "text",
            text: `✅ [${title}] 페이지에서 내용을 성공적으로 가져왔습니다.\n\n${cleanContent.substring(0, 5000)}${cleanContent.length > 5000 ? "..." : ""}`,
          },
        ],
        details: { ok: true, url, title, length: cleanContent.length },
      };
    } catch (error: any) {
      if (browser) await browser.close();
      logger.error(`[WebFetch] Failed to fetch ${url}:`, error);
      return {
        content: [{ type: "text", text: `❌ 웹 페이지 정보를 가져오는데 실패했습니다: ${error.message}` }],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const TOOLS = [webFetchTool];

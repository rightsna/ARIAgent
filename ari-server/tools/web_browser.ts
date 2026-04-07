import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { chromium, Browser, Page, BrowserContext } from "playwright";
import { logger } from "../infra/logger.js";

let activeBrowser: Browser | null = null;
let activeContext: BrowserContext | null = null;
let activePage: Page | null = null;

async function getOrLaunchBrowser(headed: boolean = true) {
  // 브라우저가 없거나 연결이 끊겼는지 확인
  if (!activeBrowser || !activeBrowser.isConnected()) {
    activeBrowser = await chromium.launch({ headless: !headed });
    activeContext = await activeBrowser.newContext();
    activePage = await activeContext.newPage();

    // 사용자가 창을 닫았을 때 상태 초기화
    activeBrowser.on("disconnected", () => {
      activeBrowser = null;
      activeContext = null;
      activePage = null;
    });
  }

  // 페이지가 닫혔다면 새 페이지 생성
  if (!activePage || activePage.isClosed()) {
    activePage = await activeContext!.newPage();
  }

  return { browser: activeBrowser, context: activeContext!, page: activePage! };
}

export const webBrowseTool: AgentTool = {
  name: "web_browse",
  label: "웹 브라우저 제어",
  description: "Playwright를 사용하여 웹사이트를 열고, 내용을 읽거나, 클릭 및 입력을 수행합니다.",
  parameters: Type.Object({
    action: Type.String({
      description: "수행할 동작 (navigate, click, click_text, type, fill, text_content, screenshot, press, wait, close)",
    }),
    url: Type.Optional(Type.String({ description: "이동할 URL (navigate 시 필수)" })),
    selector: Type.Optional(Type.String({ description: "대상 요소의 CSS 셀렉터 (click, fill, screenshot 시 선택적)" })),
    value: Type.Optional(Type.String({ description: "입력할 값 (fill, press 시 필수)" })),
    wait_for: Type.Optional(Type.String({ description: "동작 후 대기할 셀렉터" })),
  }),
  execute: async (_toolCallId, params) => {
    const { action, url, selector, value, wait_for } = params as any;

    try {
      const { page } = await getOrLaunchBrowser(true); // 항상 창이 뜨도록 설정 (headed: true)

      let resultText = "";

      switch (action) {
        case "navigate":
          if (!url) throw new Error("URL이 필요합니다.");
          await page.goto(url, { waitUntil: "load", timeout: 20000 });
          // 페이지 이동 후 안정화를 위해 잠시 추가 대기
          await page.waitForTimeout(2000);
          resultText = `${url}로 성공적으로 이동했습니다.`;
          break;

        case "click":
          if (!selector) throw new Error("셀렉터가 필요합니다.");
          await page.click(selector, { timeout: 10000 });
          resultText = `${selector} 요소를 클릭했습니다.`;
          break;

        case "click_text":
          if (!value) throw new Error("클릭할 텍스트(value)가 필요합니다.");
          await page.click(`text="${value}"`, { timeout: 10000 });
          resultText = `"${value}" 텍스트가 포함된 요소를 클릭했습니다.`;
          break;

        case "type":
          if (!value) throw new Error("타이핑할 값(value)이 필요합니다.");
          await page.keyboard.type(value, { delay: 50 });
          resultText = `"${value}" 내용을 키보드로 직접 입력했습니다.`;
          break;

        case "fill":
          if (!selector || value === undefined) throw new Error("셀렉터와 값이 필요합니다.");
          await page.fill(selector, value, { timeout: 10000 });
          resultText = `${selector}에 값을 입력했습니다.`;
          break;

        case "press":
          if (!value) throw new Error("누를 키(Enter, Tab 등)가 필요합니다.");
          await page.press(selector || "body", value, { timeout: 10000 });
          resultText = `${selector || "body"}에서 ${value} 키를 눌렀습니다.`;
          break;

        case "wait":
          const ms = parseInt(value || "2000", 10);
          await new Promise((r) => setTimeout(r, ms));
          resultText = `${ms}ms 동안 대기했습니다.`;
          break;

        case "screenshot":
          const buffer = await page.screenshot();
          const base64 = buffer.toString("base64");
          resultText = "페이지 스크린샷을 캡처했습니다.";
          return {
            content: [
              { type: "text", text: `✅ 스크린샷 캡처 완료` },
              { type: "image", data: base64, mimeType: "image/png" },
            ],
            details: { ok: true, action: "screenshot" },
          };

        case "text_content":
          // 페이지의 전체 텍스트를 간략하게 가져옵니다.
          const title = await page.title();
          const bodyText = await page.innerText("body", { timeout: 10000 });
          resultText = `페이지 제목: ${title}\n내용 요약: ${bodyText.substring(0, 1000)}...`;
          break;

        case "close":
          if (activeBrowser) {
            await activeBrowser.close();
            activeBrowser = null;
            activeContext = null;
            activePage = null;
          }
          resultText = "브라우저를 닫았습니다.";
          break;
      }

      if (wait_for) {
        await page.waitForSelector(wait_for, { timeout: 5000 }).catch(() => {});
      }

      return {
        content: [{ type: "text", text: `✅ [${action}] 수행 완료: ${resultText}` }],
        details: { ok: true, action, current_url: page.url() },
      };
    } catch (error: any) {
      logger.error(`[WebBrowser] Action ${action} failed:`, error);

      let responseContent: any[] = [{ type: "text", text: `❌ 브라우저 동작 실패: ${error.message}` }];

      // 실패 시 현재 화면 스크린샷 및 입력 필드 정보 캡처 (디버깅용)
      if (activePage) {
        try {
          // 입력 필드 목록 추출 로직 추가
          const inputs = await activePage
            .$$eval("input", (els) =>
              els.map((el) => ({
                name: el.getAttribute("name"),
                placeholder: el.getAttribute("placeholder"),
                type: el.getAttribute("type"),
                id: el.getAttribute("id"),
              })),
            )
            .catch(() => []);

          if (inputs.length > 0) {
            responseContent.push({ type: "text", text: `현재 페이지에서 발견된 입력 필드 목록: ${JSON.stringify(inputs, null, 2)}` });
          }

          const buffer = await activePage.screenshot();
          responseContent.push({ type: "text", text: "실패 시점의 화면입니다. 위 입력 필드 목록을 참고하여 셀렉터를 수정하세요:" });
          responseContent.push({
            type: "image",
            data: buffer.toString("base64"),
            mimeType: "image/png",
          });
        } catch (screenshotError) {
          logger.warn("[WebBrowser] Failed to take debug info:", screenshotError);
        }
      }

      return {
        content: responseContent,
        details: { ok: false, error: error.message, action },
      };
    }
  },
};

export const TOOLS = [webBrowseTool];

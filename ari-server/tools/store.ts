import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import axios from "axios";
import { logger } from "../infra/logger";

import os from "os";

interface AppInfo {
  app_id: string;
  name: string;
  description: string;
  github_url?: string;
  category?: string;
  mac_download_uri?: string;
  win_download_uri?: string;
}

const CLOUDFRONT_BASE_URL = "https://d34z72svq84n71.cloudfront.net";

export const searchStoreAppTool: AgentTool = {
  name: "search_store_app",
  label: "스토어 앱 검색",
  description: "ARI 앱 스토어에서 써드파티 앱을 검색하고 식별자와 설치 다운로드 URL을 얻어옵니다. 사용자가 특정 목적의 앱(예: 주식앱, 날씨앱) 설치를 요청할 때 필수적으로 먼저 호출해야 합니다.",
  parameters: Type.Object({
    searchTerm: Type.String({ description: "검색어 (예: 주식, 날씨, 메모 등)" }),
  }),
  execute: async (_toolCallId, params) => {
    const { searchTerm } = params as { searchTerm: string };
    try {
      logger.info(`[StoreTool] Searching apps with query: "${searchTerm}"`);
      
      const apiUrl = `https://ariwith.me/api/search-apps?q=${encodeURIComponent(searchTerm)}`;
      const { data } = await axios.get(apiUrl);

      if (!data.success) {
        throw new Error(data.error);
      }

      const apps: AppInfo[] = data.data || [];
      if (apps.length === 0) {
         return {
           content: [{ type: "text", text: `❌ '${searchTerm}'에 대한 앱 검색 결과가 없습니다.` }],
           details: { searchTerm, apps: [] }
         }
      }

      const isMac = process.platform === "darwin";

      const results = apps.map(app => {
        let zipUrl = undefined;
        let uri = isMac ? app.mac_download_uri : app.win_download_uri;
        
        if (uri) {
           zipUrl = `${CLOUDFRONT_BASE_URL}/${uri.replace(/^\//, '')}`;
        }
        
        return {
          app_id: app.app_id,
          name: app.name,
          description: app.description,
          zip_download_url: zipUrl
        };
      });

      return {
         content: [{
           type: "text",
           text: `✅ 스토어 검색 결과 (${results.length}건):
${JSON.stringify(results, null, 2)}
이 중 원하는 앱을 설치하려면 'install_app' 도구를 호출할 때 'url' 파라미터로 위 내용 중 'zip_download_url'을 전달하세요.`
         }],
         details: { searchTerm, results }
      }

    } catch (error: any) {
      logger.error(`[StoreTool] Error searching apps: ${error.message}`);
      return {
        content: [{ type: "text", text: `❌ 스토어 통신 도중 오류가 발생했습니다: ${error.message}` }],
        details: { ok: false, error: error.message }
      };
    }
  }
};

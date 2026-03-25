import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { exec } from "child_process";
import { promisify } from "util";
import axios from "axios";

const execAsync = promisify(exec);

export const HACredentialPrompt = "You can manage Home Assistant credentials with the setHACredentials tool.";

interface HAContext {
  url: string;
  token: string;
}

// ------------------------------------------------------------------
// 1. 키체인 접근 유틸 (macOS / Windows 호환)
// ------------------------------------------------------------------
export async function saveHACredentials(url: string, token: string): Promise<void> {
  const accountName = "ariAgentHACreds";
  const jsonToken = JSON.stringify({ url, token });
  
  try {
    if (process.platform === "darwin") {
      await execAsync(`security add-generic-password -a "${accountName}" -s "ARIAgentHA" -w '${jsonToken}' -U`);
    } else if (process.platform === "win32") {
      const escapedToken = jsonToken.replace(/"/g, '""');
      await execAsync(`cmdkey /generic:"ARIAgentHA" /user:"${accountName}" /pass:"${escapedToken}"`);
    } else {
      throw new Error(`Platform ${process.platform} is not supported securely in this example`);
    }
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to save HA credentials to system keychain: ${error.message}`);
    }
    throw error;
  }
}

export async function getHACredentials(): Promise<HAContext> {
  const accountName = "ariAgentHACreds";
  try {
    let result = "";
    if (process.platform === "darwin") {
      const { stdout } = await execAsync(`security find-generic-password -a "${accountName}" -s "ARIAgentHA" -w`);
      result = stdout;
    } else if (process.platform === "win32") {
      const script = `$credential = [System.Management.Automation.PSCredential]::new("${accountName}", (Get-Content -Path "vault:ARIAgentHA")); $credential.GetNetworkCredential().Password`;
      const { stdout } = await execAsync(`powershell -Command "${script}"`);
      result = stdout;
    } else {
      throw new Error("Unsupported platform");
    }
    return JSON.parse(result.trim()) as HAContext;
  } catch (error) {
    throw new Error("Could not retrieve Home Assistant credentials. Please set them first using setHACredentials.");
  }
}

// ------------------------------------------------------------------
// 2. HA 연동 Tools 정의
// ------------------------------------------------------------------

export const setHACredentialsTool: AgentTool = {
  name: "setHACredentials",
  label: "Home Assistant 자격증명 저장",
  description: "Home Assistant 서버의 URL과 Long-Lived Access Token을 안전하게 저장합니다.",
  parameters: Type.Object({
    url: Type.String({ description: "HA 서버 베이스 URL (예: http://192.168.1.100:8123)" }),
    token: Type.String({ description: "HA 프로필에서 발급받은 Long-Lived Access Token" })
  }),
  execute: async (_toolCallId, params) => {
    try {
      const { url, token } = params as any;
      const sanitizedUrl = url.endsWith("/") ? url.slice(0, -1) : url;

      await saveHACredentials(sanitizedUrl, token);
      
      try {
        await axios.get(`${sanitizedUrl}/api/config`, {
          headers: { Authorization: `Bearer ${token}` }
        });
        return {
          content: [{ type: "text", text: `Success: Home Assistant 연결 및 자격증명 저장이 완료되었습니다.` }],
          details: { ok: true }
        };
      } catch (netErr) {
        return {
          content: [{ type: "text", text: `Credentials saved, but connection failed. Please ensure HA URL is reachable and token is valid.` }],
          details: { ok: false, error: "Connection Failed" }
        };
      }
    } catch (error) {
      return {
        content: [{ type: "text", text: `Error: ${error instanceof Error ? error.message : "Unknown error"}` }],
        details: { ok: false, error: String(error) }
      };
    }
  },
};

export const listHADevicesTool: AgentTool = {
  name: "listHADevices",
  label: "HA 기기 목록 조회",
  description: "연동된 Home Assistant 서버에 등록된 제어 가능한 스마트 기기(light, switch, climate 등) 목록을 가져옵니다.",
  parameters: Type.Object({}),
  execute: async (_toolCallId, params) => {
    try {
      const config = await getHACredentials();
      
      const response = await axios.get(`${config.url}/api/states`, {
        headers: { Authorization: `Bearer ${config.token}` }
      });

      const entities = response.data as any[];
      const devices = entities.filter(e => 
        e.entity_id.startsWith("light.") || 
        e.entity_id.startsWith("switch.") || 
        e.entity_id.startsWith("climate.") ||
        e.entity_id.startsWith("fan.") ||
        e.entity_id.startsWith("cover.") ||
        e.entity_id.startsWith("media_player.")
      ).map(e => ({
        id: e.entity_id,
        name: e.attributes.friendly_name || e.entity_id,
        state: e.state,
      }));

      return {
        content: [{ type: "text", text: JSON.stringify(devices, null, 2) }],
        details: { ok: true, deviceCount: devices.length }
      };
    } catch (error: any) {
      if (axios.isAxiosError(error) && error.response) {
        return {
          content: [{ type: "text", text: `Failed to fetch devices from HA: ${error.response.statusText}` }],
          details: { ok: false, error: error.response.statusText }
        };
      }
      return {
        content: [{ type: "text", text: `Error: ${error.message || String(error)}` }],
        details: { ok: false, error: String(error) }
      };
    }
  },
};

export const controlHADeviceTool: AgentTool = {
  name: "controlHADevice",
  label: "HA 기기 제어",
  description: "Home Assistant 서버에 연결된 기기를 제어합니다 (켜기/끄기/토글).",
  parameters: Type.Object({
    entity_id: Type.String({ description: "제어할 기기의 고유 Entity ID (예: light.living_room_bulb)" }),
    service: Type.String({ description: "호출할 서비스 명령 ('turn_on', 'turn_off', 'toggle' 등)" }),
    domain: Type.Optional(Type.String({ description: "호출할 도메인(light, switch, homeassistant 등). 기본값은 모든 기기에 통용되는 'homeassistant'." }))
  }),
  execute: async (_toolCallId, params) => {
    try {
      const config = await getHACredentials();
      const { entity_id, service, domain = "homeassistant" } = params as any;

      const payload = { entity_id };

      const response = await axios.post(
        `${config.url}/api/services/${domain}/${service}`,
        payload,
        { headers: { Authorization: `Bearer ${config.token}` } }
      );

      return {
        content: [{ type: "text", text: `Successfully called ${domain}.${service} on ${entity_id}` }],
        details: { ok: true, response: response.data }
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Control error: ${error instanceof Error ? error.message : "Unknown error"}` }],
        details: { ok: false, error: String(error) }
      };
    }
  },
};

export const TOOLS: AgentTool[] = [
  setHACredentialsTool,
  listHADevicesTool,
  controlHADeviceTool,
];

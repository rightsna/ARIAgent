import { router } from "../system/router";
import { saveHACredentials, getHACredentials } from "../tools/homeassistant";
import axios from "axios";

router.on("/GET_HA_CREDENTIALS", async (ws, params) => {
  try {
    const creds = await getHACredentials();
    ws.send("/GET_HA_CREDENTIALS", {
      ok: true,
      data: creds,
    });
  } catch (error: any) {
    ws.send("/GET_HA_CREDENTIALS", {
      ok: false,
      error: error.message,
    });
  }
});

router.on("/GET_HA_DEVICES", async (ws, params) => {
  try {
    const creds = await getHACredentials();
    const response = await axios.get(`${creds.url}/api/states`, {
      headers: { Authorization: `Bearer ${creds.token}` },
      timeout: 5000,
    });

    const entities = response.data as any[];
    const devices = entities
      .filter(
        (e) =>
          e.entity_id.startsWith("light.") ||
          e.entity_id.startsWith("switch.") ||
          e.entity_id.startsWith("climate.") ||
          e.entity_id.startsWith("fan.") ||
          e.entity_id.startsWith("cover.") ||
          e.entity_id.startsWith("media_player."),
      )
      .map((e) => ({
        id: e.entity_id,
        name: e.attributes.friendly_name || e.entity_id,
        state: e.state,
        type: e.entity_id.split(".")[0],
      }));

    ws.send("/GET_HA_DEVICES", {
      ok: true,
      data: { devices },
    });
  } catch (error: any) {
    ws.send("/GET_HA_DEVICES", {
      ok: false,
      error: error.message,
    });
  }
});

router.on("/SET_HA_CREDENTIALS", async (ws, params) => {
  const { url, token } = params as { url: string; token: string };

  if (!url || !token) {
    return ws.send("/SET_HA_CREDENTIALS", {
      ok: false,
      error: "URL and Token are required",
    });
  }

  try {
    const sanitizedUrl = url.endsWith("/") ? url.slice(0, -1) : url;

    // 1. Verify connection first
    try {
      await axios.get(`${sanitizedUrl}/api/config`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 5000,
      });
    } catch (netErr: any) {
      return ws.send("/SET_HA_CREDENTIALS", {
        ok: false,
        error: `서버 연결 실패: ${netErr.message}. URL과 토큰을 확인해 주세요.`,
      });
    }

    // 2. Save to keychain
    await saveHACredentials(sanitizedUrl, token);

    ws.send("/SET_HA_CREDENTIALS", {
      ok: true,
      data: { success: true },
    });
  } catch (error: any) {
    ws.send("/SET_HA_CREDENTIALS", {
      ok: false,
      error: `오류 발생: ${error.message}`,
    });
  }
});

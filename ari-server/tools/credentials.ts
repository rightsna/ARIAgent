import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { exec } from "child_process";
import { promisify } from "util";
import { logger } from "../infra/logger.js";

const execAsync = promisify(exec);

/**
 * 보안을 위해 쉘 인자에서 특수 문자를 이스케이프합니다.
 */
function escapeShellArg(arg: string): string {
  return `'${arg.replace(/'/g, "'\\''")}'`;
}

export const setCredentialTool: AgentTool = {
  name: "set_credential",
  label: "자격 증명 저장",
  description: "서비스 이름과 계정명, 비밀번호를 macOS 키체인에 안전하게 저장합니다. 이미 존재하는 경우 업데이트합니다.",
  parameters: Type.Object({
    service: Type.String({ description: "서비스 이름 (예: facebook.com, github.com)" }),
    account: Type.String({ description: "사용자 계정 (아이디 또는 이메일)" }),
    password: Type.String({ description: "비밀번호" }),
  }),
  execute: async (_toolCallId, params) => {
    const { service, account, password } = params as any;
    try {
      if (process.platform === "darwin") {
        const cmd = `security add-generic-password -a ${escapeShellArg(account)} -s ${escapeShellArg(service)} -w ${escapeShellArg(password)} -U`;
        await execAsync(cmd);
      } else if (process.platform === "win32") {
        // Windows Credential Manager (requires cmdkey)
        const cmd = `cmdkey /generic:${escapeShellArg(service)} /user:${escapeShellArg(account)} /pass:${escapeShellArg(password)}`;
        await execAsync(cmd);
      } else {
        throw new Error(`지원하지 않는 운영체제입니다: ${process.platform}`);
      }

      logger.info(`[Credentials] Saved credential for ${service} (${account}) on ${process.platform}`);
      return {
        content: [{ type: "text", text: `✅ [${service}]의 [${account}] 자격 증명이 시스템 보안 저장소에 안전하게 저장되었습니다.` }],
        details: { ok: true, service, account, platform: process.platform },
      };
    } catch (error: any) {
      logger.error("[Credentials] Failed to set credential:", error);
      return {
        content: [{ type: "text", text: `❌ 자격 증명 저장 실패: ${error.message}` }],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const getCredentialTool: AgentTool = {
  name: "get_credential",
  label: "자격 증명 조회",
  description: "macOS 키체인이나 Windows 자격 증명 관리자에서 특정 서비스의 비밀번호를 가져옵니다. 계정명(account)을 모르면 서비스명만으로도 조회가 가능합니다.",
  parameters: Type.Object({
    service: Type.String({ description: "서비스 이름" }),
    account: Type.Optional(Type.String({ description: "사용자 계정 (생략 시 해당 서비스의 첫 번째 계정 조회)" })),
  }),
  execute: async (_toolCallId, params) => {
    const { service, account } = params as any;
    try {
      let password = "";
      let foundAccount = account;

      if (process.platform === "darwin") {
        const accountPart = account ? `-a ${escapeShellArg(account)}` : "";
        const cmd = `security find-generic-password ${accountPart} -s ${escapeShellArg(service)} -w`;

        if (!account) {
          // 계정명을 모를 경우, 먼저 계정명을 알아내기 위해 -w 없이 실행
          const findCmd = `security find-generic-password -s ${escapeShellArg(service)}`;
          const { stdout: attrOutput } = await execAsync(findCmd);
          const acctMatch = attrOutput.match(/"acct"<blob>="([^"]+)"/);
          if (acctMatch) foundAccount = acctMatch[1];
        }

        const { stdout } = await execAsync(cmd);
        password = stdout.trim();
      } else if (process.platform === "win32") {
        let targetAccount = account;
        if (!targetAccount) {
          // Windows: list current credentials for this service
          const { stdout: listOut } = await execAsync(`cmdkey /list:${service}`);
          const match = listOut.match(/사용자: ([^\r\n]+)/);
          if (match) targetAccount = match[1].trim();
          foundAccount = targetAccount;
        }

        if (!targetAccount) throw new Error("계정 정보를 찾을 수 없습니다.");

        const script = `
          $vault = New-Object -TypeName Microsoft.Windows.Security.Credentials.PasswordVault;
          $cred = $vault.RetrieveAll() | Where-Object { $_.Resource -eq '${service}' -and $_.UserName -eq '${targetAccount}' };
          if ($cred) { $cred.RetrievePassword(); $cred.Password }
        `;
        const { stdout } = await execAsync(`powershell -Command "${script.replace(/\n/g, "")}"`);
        password = stdout.trim();
      } else {
        throw new Error(`지원하지 않는 운영체제입니다: ${process.platform}`);
      }

      logger.info(`[Credentials] Retrieved credential for ${service} (${foundAccount})`);
      return {
        content: [{ type: "text", text: `✅ [${service}]의 [${foundAccount}] 비밀번호를 성공적으로 가져왔습니다.` }],
        details: { ok: true, password, account: foundAccount },
      };
    } catch (error: any) {
      logger.warn(`[Credentials] Credential not found for ${service} (${account}) on ${process.platform}: ${error.message}`);
      return {
        content: [{ type: "text", text: `⚠️ [${service}]의 [${account}] 자격 증명을 찾을 수 없거나 접근 권한이 없습니다.` }],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const deleteCredentialTool: AgentTool = {
  name: "delete_credential",
  label: "자격 증명 삭제",
  description: "macOS 키체인에서 특정 서비스 및 계정의 자격 증명을 삭제합니다.",
  parameters: Type.Object({
    service: Type.String({ description: "서비스 이름" }),
    account: Type.String({ description: "사용자 계정" }),
  }),
  execute: async (_toolCallId, params) => {
    const { service, account } = params as any;
    try {
      if (process.platform === "darwin") {
        const cmd = `security delete-generic-password -a ${escapeShellArg(account)} -s ${escapeShellArg(service)}`;
        await execAsync(cmd);
      } else if (process.platform === "win32") {
        const cmd = `cmdkey /delete:${escapeShellArg(service)}`;
        await execAsync(cmd);
      } else {
        throw new Error(`지원하지 않는 운영체제입니다: ${process.platform}`);
      }

      logger.info(`[Credentials] Deleted credential for ${service} (${account})`);
      return {
        content: [{ type: "text", text: `✅ [${service}]의 [${account}] 자격 증명이 삭제되었습니다.` }],
        details: { ok: true, service, account },
      };
    } catch (error: any) {
      return {
        content: [{ type: "text", text: `⚠️ 삭제 실패 (항목이 없을 수 있음): ${error.message}` }],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const listCredentialsTool: AgentTool = {
  name: "list_credentials",
  label: "자격 증명 목록 조회",
  description: "특정 서비스에 저장된 모든 계정명 목록을 가져옵니다.",
  parameters: Type.Object({
    service: Type.String({ description: "서비스 이름 (예: threads.net)" }),
  }),
  execute: async (_toolCallId, params) => {
    const { service } = params as any;
    try {
      const accounts: string[] = [];
      if (process.platform === "darwin") {
        // security find-generic-password -s <service> 는 하나만 보여주므로 덤프 활용
        const { stdout } = await execAsync(`security find-generic-password -s ${escapeShellArg(service)} 2>&1 || true`);
        const matches = stdout.matchAll(/"acct"<blob>="([^"]+)"/g);
        for (const match of matches) {
          if (!accounts.includes(match[1])) accounts.push(match[1]);
        }
      } else if (process.platform === "win32") {
        const { stdout } = await execAsync(`cmdkey /list:${service}`);
        const matches = stdout.matchAll(/사용자: ([^\r\n]+)/g);
        for (const match of matches) {
          const acc = match[1].trim();
          if (!accounts.includes(acc)) accounts.push(acc);
        }
      }

      return {
        content: [{ type: "text", text: `✅ [${service}]에 대해 ${accounts.length}개의 계정을 찾았습니다: ${accounts.join(", ") || "없음"}` }],
        details: { ok: true, accounts },
      };
    } catch (error: any) {
      return {
        content: [{ type: "text", text: `❌ 목록 조회 실패: ${error.message}` }],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const TOOLS = [setCredentialTool, getCredentialTool, deleteCredentialTool, listCredentialsTool];

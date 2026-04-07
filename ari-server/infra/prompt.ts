import handlebars, { type TemplateDelegate } from "handlebars";
import * as fs from "fs";
import * as path from "path";
import { fileExistsSync, readTextSync } from "./data.js";
import { logger } from "./logger.js";
import { resolveServerPath } from "./runtime_paths.js";

export namespace Prompt {
  // 🔑 캐시: 템플릿 이름 → 마지막 수정 시각과 컴파일된 핸들바 함수
  const cache = new Map<string, { fullPath: string; mtimeMs: number; compiled: TemplateDelegate }>();

  function resolveTemplatePath(templateName: string): string {
    const candidates = [
      resolveServerPath("template", templateName),
      path.join(process.cwd(), "template", templateName),
      path.join(process.cwd(), "ari-server", "template", templateName),
    ];

    for (const candidate of candidates) {
      if (fileExistsSync(candidate)) {
        return candidate;
      }
    }

    return candidates[0];
  }

  /*
      사용 예시:
      const queryAri = await Prompt.load('a.hbs', { lang: 'ko' });
  */
  export const load = async (templateName: string, param: any = {}): Promise<string> => {
    try {
      // 캐시에 이미 있으면 바로 사용
      const fullPath = resolveTemplatePath(templateName);

      if (!fileExistsSync(fullPath)) {
        throw new Error(`템플릿 파일을 찾을 수 없습니다: ${fullPath}`);
      }

      const stat = fs.statSync(fullPath);
      const cached = cache.get(templateName);
      if (cached && cached.fullPath === fullPath && cached.mtimeMs === stat.mtimeMs) {
        return cached.compiled(param);
      }

      const content = readTextSync(fullPath);
      const compiled = handlebars.compile(content);

      // 캐시에 저장
      cache.set(templateName, {
        fullPath,
        mtimeMs: stat.mtimeMs,
        compiled,
      });

      return compiled(param);
    } catch (err) {
      logger.error(`템플릿 로딩 실패: ${(err as Error).message}`);
      throw err;
    }
  };
}

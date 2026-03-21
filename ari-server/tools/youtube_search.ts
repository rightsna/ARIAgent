import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import https from "https";
import { logger } from "../infra/logger";

function isLikelyUrl(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

function buildYoutubeUrl(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error("재생할 유튜브 URL 또는 검색어가 필요합니다.");
  }

  if (isLikelyUrl(trimmed)) {
    return trimmed;
  }

  const query = encodeURIComponent(trimmed);
  return `https://www.youtube.com/results?search_query=${query}`;
}

function fetchText(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = https.get(
      url,
      {
        headers: {
          "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
          "Accept-Language": "ko,en-US;q=0.9,en;q=0.8",
        },
      },
      (res) => {
        const statusCode = res.statusCode ?? 0;
        if (statusCode >= 300 && statusCode < 400 && res.headers.location) {
          res.resume();
          resolve(fetchText(res.headers.location));
          return;
        }

        if (statusCode < 200 || statusCode >= 300) {
          res.resume();
          reject(new Error(`YouTube 요청 실패 (${statusCode})`));
          return;
        }

        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => {
          body += chunk;
        });
        res.on("end", () => resolve(body));
      },
    );

    req.on("error", reject);
  });
}

function extractInitialData(html: string): unknown {
  const patterns = [/var ytInitialData = (.*?);<\/script>/s, /window\["ytInitialData"\] = (.*?);<\/script>/s, /ytInitialData"\] = (.*?);<\/script>/s];

  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (!match?.[1]) {
      continue;
    }

    try {
      return JSON.parse(match[1]);
    } catch {
      // 다음 패턴 시도
    }
  }

  throw new Error("YouTube 초기 데이터를 찾지 못했습니다.");
}

type YoutubeVideoItem = {
  title: string;
  videoId: string;
  url: string;
  thumbnailUrl?: string;
  channelName?: string;
  durationText?: string;
};

const recentPlayedVideoIds: string[] = [];
const recentPlayedLimit = 12;

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function getTextFromRuns(value: unknown): string {
  if (!isRecord(value)) {
    return "";
  }

  if (typeof value.simpleText === "string") {
    return value.simpleText;
  }

  if (Array.isArray(value.runs)) {
    return value.runs
      .map((run) => (isRecord(run) && typeof run.text === "string" ? run.text : ""))
      .join("")
      .trim();
  }

  return "";
}

function collectVideoRenderers(node: unknown, acc: YoutubeVideoItem[]): void {
  if (Array.isArray(node)) {
    for (const item of node) {
      collectVideoRenderers(item, acc);
    }
    return;
  }

  if (!isRecord(node)) {
    return;
  }

  const videoRenderer = node.videoRenderer;
  if (isRecord(videoRenderer) && typeof videoRenderer.videoId === "string") {
    const videoId = videoRenderer.videoId;
    const thumbnails = isRecord(videoRenderer.thumbnail) && Array.isArray(videoRenderer.thumbnail.thumbnails) ? videoRenderer.thumbnail.thumbnails : [];
    const lastThumbnail = thumbnails.length > 0 ? thumbnails[thumbnails.length - 1] : undefined;
    const thumbnailUrl = isRecord(lastThumbnail) && typeof lastThumbnail.url === "string" ? lastThumbnail.url : undefined;

    acc.push({
      title: getTextFromRuns(videoRenderer.title),
      videoId,
      url: `https://www.youtube.com/watch?v=${videoId}`,
      thumbnailUrl,
      channelName: getTextFromRuns(videoRenderer.ownerText),
      durationText: getTextFromRuns(videoRenderer.lengthText),
    });
  }

  for (const value of Object.values(node)) {
    collectVideoRenderers(value, acc);
  }
}

async function searchYoutubeVideos(query: string, limit: number): Promise<YoutubeVideoItem[]> {
  const trimmed = query.trim();
  if (!trimmed) {
    throw new Error("검색어가 필요합니다.");
  }

  const searchUrl = buildYoutubeUrl(trimmed);
  const html = await fetchText(searchUrl);
  const initialData = extractInitialData(html);
  const items: YoutubeVideoItem[] = [];
  collectVideoRenderers(initialData, items);

  const uniqueItems = items.filter((item, index) => !!item.title && items.findIndex((candidate) => candidate.videoId === item.videoId) === index);

  return uniqueItems.slice(0, limit);
}

function pickShuffledItems<T>(items: T[], count: number): T[] {
  const shuffled = [...items];
  for (let i = shuffled.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }

  return shuffled.slice(0, Math.min(count, shuffled.length));
}

function filterRecentItems(items: YoutubeVideoItem[]): YoutubeVideoItem[] {
  const recentSet = new Set(recentPlayedVideoIds);
  const freshItems = items.filter((item) => !recentSet.has(item.videoId));
  return freshItems.length > 0 ? freshItems : items;
}

function rememberPlayedVideoIds(videoIds: string[]): void {
  for (const videoId of videoIds) {
    const existingIndex = recentPlayedVideoIds.indexOf(videoId);
    if (existingIndex >= 0) {
      recentPlayedVideoIds.splice(existingIndex, 1);
    }

    recentPlayedVideoIds.push(videoId);
    if (recentPlayedVideoIds.length > recentPlayedLimit) {
      recentPlayedVideoIds.shift();
    }
  }
}

function getTimeMoodKeyword(now = new Date()): string {
  const hour = now.getHours();
  if (hour >= 5 && hour < 11) {
    return "아침";
  }
  if (hour >= 11 && hour < 17) {
    return "오후";
  }
  if (hour >= 17 && hour < 22) {
    return "저녁";
  }
  return "새벽";
}

function buildPlaylistQueryVariants(query: string): string[] {
  const trimmed = query.trim();
  const timeMood = getTimeMoodKeyword();
  const variants = [trimmed, `${timeMood} ${trimmed}`, `${trimmed} 플레이리스트`, `${timeMood} 듣기 좋은 ${trimmed} 플레이리스트`, `${trimmed} 믹스`, `${trimmed} 모음`];

  return variants.filter((value, index) => value && variants.indexOf(value) === index);
}

async function searchExpandedPlaylistCandidates(query: string, perQueryLimit: number, maxItems: number): Promise<YoutubeVideoItem[]> {
  const variants = buildPlaylistQueryVariants(query);
  const merged: YoutubeVideoItem[] = [];
  const seenVideoIds = new Set<string>();

  for (const variant of variants) {
    const items = await searchYoutubeVideos(variant, perQueryLimit);
    for (const item of items) {
      if (seenVideoIds.has(item.videoId)) {
        continue;
      }
      seenVideoIds.add(item.videoId);
      merged.push(item);
      if (merged.length >= maxItems) {
        return merged;
      }
    }
  }

  return merged;
}

export const youtubePlayPlaylistTool: AgentTool = {
  name: "youtube_play_playlist",
  label: "YouTube 플레이리스트 재생",
  description: "분위기/장르 검색어를 받아 로컬 YouTube 플레이어에서 바로 재생한다.",
  parameters: Type.Object({
    query: Type.String({
      description: "플레이리스트를 찾기 위한 검색어 (예: '감성적인 음악', '집중용 재즈', 'lofi playlist')",
    }),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { query } = params as {
      query: string;
    };

    const hasQuery = !!query?.trim();

    if (!hasQuery) {
      throw new Error("query 파라미터가 필요합니다.");
    }

    const normalizedQuery = query.trim();
    logger.info(`▶️ Tool[youtube_play_playlist]: ${normalizedQuery}`);
    const candidateItems = await searchExpandedPlaylistCandidates(normalizedQuery, 6, 18);
    const items = pickShuffledItems(filterRecentItems(candidateItems), 5);

    if (items.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: `⚠️ "${normalizedQuery}"에 대한 재생할 곡을 찾지 못했습니다.`,
          },
        ],
        details: { query: normalizedQuery, videoIds: [], items: [] },
      };
    }

    const videoIds = items.map((item) => item.videoId);
    rememberPlayedVideoIds(videoIds);

    return {
      content: [
        {
          type: "text" as const,
          text: `✅ 시스템 메시지: 재생 준비 완료 (${items.length}곡).\n이제 반드시 'launch_app' 도구를 사용하여 'youtubeplayer' 앱을 실행하시오.\n(파라미터 env: { YOUTUBEPLAYER_PLAYLIST: "${videoIds.join(",")}" })`,
        },
      ],
      details: {
        query: normalizedQuery,
        videoIds,
        items,
      },
    };
  },
};

export const youtubeSearchVideosTool: AgentTool = {
  name: "youtube_search_videos",
  label: "YouTube 영상 검색",
  description: "검색어를 받아 YouTube 영상 검색 결과를 구조화된 목록으로 반환한다. Flutter 내장 플레이어에 넘길 재생 후보 목록을 만들 때 사용한다.",
  parameters: Type.Object({
    query: Type.String({
      description: "검색어 (예: '감성적인 노래', 'lofi hip hop', '집중 음악')",
    }),
    limit: Type.Optional(
      Type.Number({
        description: "최대 반환 개수. 기본값 5, 최대 10.",
      }),
    ),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { query, limit } = params as { query: string; limit?: number };
    const normalizedLimit = Math.max(1, Math.min(10, Math.floor(limit ?? 5)));

    logger.info(`🔎 Tool[youtube_search_videos]: ${query} (limit=${normalizedLimit})`);
    const items = await searchYoutubeVideos(query, normalizedLimit);

    if (items.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: `⚠️ "${query.trim()}"에 대한 YouTube 검색 결과를 찾지 못했습니다.`,
          },
        ],
        details: { query: query.trim(), items: [] },
      };
    }

    return {
      content: [
        {
          type: "text" as const,
          text: `✅ "${query.trim()}" 검색 결과 ${items.length}개를 찾았습니다.`,
        },
      ],
      details: {
        query: query.trim(),
        items,
      },
    };
  },
};

export const TOOLS = [youtubePlayPlaylistTool, youtubeSearchVideosTool];

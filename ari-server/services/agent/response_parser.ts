import { Agent } from "@mariozechner/pi-agent-core";

export function extractFinalResponseText(agent: Agent): string {
  const messages = agent.state.messages;
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role !== "assistant" || !Array.isArray((message as any).content)) {
      continue;
    }

    const text = (message as any).content
      .filter((block: any) => block.type === "text")
      .map((block: any) => block.text)
      .join("");

    if (text) {
      return text;
    }
  }

  return "";
}

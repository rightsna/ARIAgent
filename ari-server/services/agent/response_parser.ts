import { Agent } from "@mariozechner/pi-agent-core";

function extractTextFromContent(content: unknown): string {
  if (typeof content === "string") {
    return content;
  }

  if (Array.isArray(content)) {
    return content.map((item) => extractTextFromContent(item)).join("");
  }

  if (!content || typeof content !== "object") {
    return "";
  }

  const candidate = content as {
    type?: unknown;
    text?: unknown;
    value?: unknown;
    content?: unknown;
    output_text?: unknown;
  };

  if (typeof candidate.text === "string") {
    return candidate.text;
  }

  if (typeof candidate.output_text === "string") {
    return candidate.output_text;
  }

  if (typeof candidate.value === "string") {
    return candidate.value;
  }

  if (candidate.type === "text" || candidate.type === "output_text") {
    return (
      extractTextFromContent(candidate.text) ||
      extractTextFromContent(candidate.output_text) ||
      extractTextFromContent(candidate.value)
    );
  }

  return extractTextFromContent(candidate.content);
}

export function extractTextFromAgentMessage(message: unknown): string {
  if (!message || typeof message !== "object") {
    return "";
  }

  const assistantMessage = message as {
    role?: unknown;
    content?: unknown;
  };

  if (assistantMessage.role !== "assistant") {
    return "";
  }

  return extractTextFromContent(assistantMessage.content).trim();
}

export function extractFinalResponseText(agent: Agent): string {
  const messages = agent.state.messages;
  for (let i = messages.length - 1; i >= 0; i--) {
    const text = extractTextFromAgentMessage(messages[i]);
    if (text) {
      return text;
    }
  }

  return "";
}

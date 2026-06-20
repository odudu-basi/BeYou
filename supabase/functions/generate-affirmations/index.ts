// Edge Function to generate personalized affirmations using Claude Haiku (primary) or GPT-4o-mini (fallback)
// Called during the intervention flow to create mood-aware, personalized affirmations

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function buildPrompts(mood: string, feeling: string | undefined, name: string, religion: string | undefined, count: number) {
  let systemPrompt = `You generate short, powerful affirmations for a screen time wellness app called BeYou.
Each affirmation should be 1-2 sentences max, written in first person ("I am...", "I choose...", "I deserve...").
They should feel personal, warm, and empowering — not generic or preachy.
If a name is provided, include the user's name naturally in some (not all) affirmations — e.g. "You've got this, {name}" or "I, {name}, am worthy of...".
Return ONLY a JSON array of strings, no other text.`;

  if (religion && religion !== "general" && religion !== "none") {
    systemPrompt += `\nThe user follows ${religion}. At least one affirmation MUST include faith-aligned language specific to ${religion} (e.g. referencing God, scripture, prayer, or spiritual concepts from ${religion}). The others can be secular but keep the religious one natural and heartfelt, not forced.`;
  }

  const userPrompt = `Generate ${count} personalized affirmations for ${name}.

Current mood: ${mood}${feeling ? `\nSpecific feeling: ${feeling}` : ""}

Make them directly relevant to how they're feeling right now. Be specific to their emotional state, not generic.`;

  return { systemPrompt, userPrompt };
}

function buildMeditationPrompts(mood: string, topic: string, name: string, religion: string | undefined, count: number) {
  let systemPrompt = `You generate short, powerful meditation affirmations for a mindfulness app called BeYou.
The user is about to meditate. Your affirmations should be calming, grounding, and reflective — suited for a quiet, meditative moment.
They should feel like gentle truths the user can breathe into, not energizing or hype-like.
Each affirmation should be 1-2 sentences max, written in first person ("I am...", "I release...", "I allow...").
If a name is provided, include the user's name naturally in some (not all) affirmations.
Return ONLY a JSON array of strings, no other text.`;

  if (religion && religion !== "general" && religion !== "none") {
    systemPrompt += `\nThe user follows ${religion}. At least one affirmation MUST include faith-aligned language specific to ${religion} (e.g. referencing God, scripture, prayer, or spiritual concepts from ${religion}). Keep it natural and heartfelt.`;
  }

  const userPrompt = `Generate ${count} meditation affirmations for ${name}.

Focus topic: ${topic}
Current mood: ${mood}

Make them deeply relevant to the topic "${topic}" and aware of how they're feeling (${mood}). These will be read during a meditation session, so keep the tone peaceful and introspective.`;

  return { systemPrompt, userPrompt };
}

function parseAffirmations(text: string): string[] | null {
  try {
    return JSON.parse(text);
  } catch {
    const match = text.match(/\[[\s\S]*\]/);
    if (match) {
      try {
        return JSON.parse(match[0]);
      } catch {
        return null;
      }
    }
    return null;
  }
}

async function tryAnthropic(systemPrompt: string, userPrompt: string): Promise<string[] | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": CLAUDE_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 300,
        system: systemPrompt,
        messages: [{ role: "user", content: userPrompt }],
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Anthropic error: ${response.status} - ${errorText}`);
      return null;
    }

    const data = await response.json();
    const text = data.content[0].text.trim();
    return parseAffirmations(text);
  } catch (e) {
    console.error(`Anthropic failed: ${e}`);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function tryOpenAI(systemPrompt: string, userPrompt: string): Promise<string[] | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: "gpt-4o-mini",
        max_tokens: 300,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`OpenAI error: ${response.status} - ${errorText}`);
      return null;
    }

    const data = await response.json();
    const text = data.choices[0].message.content.trim();
    return parseAffirmations(text);
  } catch (e) {
    console.error(`OpenAI failed: ${e}`);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { mood, feeling, name, religion, count, topic, meditation } = await req.json();

    if (!mood) {
      return new Response(
        JSON.stringify({ error: "mood is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const affirmationCount = count || 3;
    const userName = name || "friend";
    const { systemPrompt, userPrompt } = meditation
      ? buildMeditationPrompts(mood, topic || "Self-love", userName, religion, affirmationCount)
      : buildPrompts(mood, feeling, userName, religion, affirmationCount);

    // Try Anthropic first, fall back to OpenAI
    let affirmations = await tryAnthropic(systemPrompt, userPrompt);

    if (!affirmations) {
      console.log("Anthropic failed, trying OpenAI fallback...");
      affirmations = await tryOpenAI(systemPrompt, userPrompt);
    }

    if (!affirmations) {
      return new Response(
        JSON.stringify({ error: "AI generation failed" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ affirmations }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge Function error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

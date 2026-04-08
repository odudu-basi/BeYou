// Edge Function to generate personalized affirmations using Claude Haiku
// Called during the intervention flow to create mood-aware, personalized affirmations

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { mood, feeling, name, religion, count } = await req.json();

    if (!mood) {
      return new Response(
        JSON.stringify({ error: "mood is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const affirmationCount = count || 3;
    const userName = name || "friend";

    // Build the prompt
    let systemPrompt = `You generate short, powerful affirmations for a screen time wellness app called BeYou.
Each affirmation should be 1-2 sentences max, written in first person ("I am...", "I choose...", "I deserve...").
They should feel personal, warm, and empowering — not generic or preachy.
If a name is provided, include the user's name naturally in some (not all) affirmations — e.g. "You've got this, {name}" or "I, {name}, am worthy of...".
Return ONLY a JSON array of strings, no other text.`;

    if (religion && religion !== "general" && religion !== "none") {
      systemPrompt += `\nThe user follows ${religion}. You may include subtle faith-aligned language where natural, but keep it gentle — not every affirmation needs to reference faith.`;
    }

    const userPrompt = `Generate ${affirmationCount} personalized affirmations for ${userName}.

Current mood: ${mood}${feeling ? `\nSpecific feeling: ${feeling}` : ""}

Make them directly relevant to how they're feeling right now. Be specific to their emotional state, not generic.`;

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": CLAUDE_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-3-haiku-20240307",
        max_tokens: 300,
        system: systemPrompt,
        messages: [{ role: "user", content: userPrompt }],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Claude API error: ${response.status} - ${errorText}`);
      return new Response(
        JSON.stringify({ error: "AI generation failed" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const text = data.content[0].text.trim();

    // Parse the JSON array from Claude's response
    let affirmations: string[];
    try {
      affirmations = JSON.parse(text);
    } catch {
      // If Claude didn't return valid JSON, try to extract array from the response
      const match = text.match(/\[[\s\S]*\]/);
      if (match) {
        affirmations = JSON.parse(match[0]);
      } else {
        console.error(`Failed to parse Claude response: ${text}`);
        return new Response(
          JSON.stringify({ error: "Failed to parse AI response" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
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

// Verifies a wake-up mission photo with OpenAI vision (gpt-4o-mini).
// Returns { pass: boolean, reason: string }. Fails OPEN (pass=true) on any error
// so a groggy user is never trapped by a network/AI failure.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function instruction(mission: string, target?: string): string {
  switch (mission) {
    case "Item Search":
      return `The user must photograph a specific object to prove they're up and moving. Target object: "${target ?? "the item"}". Pass if a real ${target ?? "item"} is clearly visible in the photo (it does not need to be centered). Fail if the object is absent or the photo is a screenshot/of a screen.`;
    case "Picture of Sky":
      return `The user must photograph the sky. Pass for any genuine photo showing the sky (day or night, clouds, sunrise, etc.). Fail if it's clearly indoors with no sky, or a photo of a screen.`;
    case "Make Your Bed":
      return `The user must photograph their bed after tidying it. Be LENIENT: pass if the bed looks even somewhat made, organized, or tidied — e.g. the duvet or sheets are roughly pulled up, flattened, or straightened, even if it's not perfect or some wrinkles/items remain. When in doubt, pass. Only fail if the bed is clearly very messy (blankets in a crumpled heap, obviously slept-in and untouched) or the photo is not a bed at all.`;
    case "Touch Grass":
      return `The user must step outside. Pass for any genuine outdoor photo showing grass, plants, trees, or nature. Fail if clearly indoors or a photo of a screen.`;
    default:
      return `Decide whether this photo satisfies the task "${mission}".`;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const ok = (pass: boolean, reason: string) =>
    new Response(JSON.stringify({ pass, reason }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const { mission, target, imageBase64 } = await req.json();
    if (!imageBase64) return ok(true, "no image"); // fail open

    const body = {
      model: "gpt-4o-mini",
      temperature: 0,
      max_tokens: 120,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            `You verify wake-up alarm mission photos. ${instruction(mission, target)} ` +
            `Respond ONLY with JSON: {"pass": boolean, "reason": string}. ` +
            `"reason" is a short, friendly, user-facing message (max ~10 words).`,
        },
        {
          role: "user",
          content: [
            { type: "text", text: "Verify this photo." },
            {
              type: "image_url",
              image_url: { url: `data:image/jpeg;base64,${imageBase64}`, detail: "low" },
            },
          ],
        },
      ],
    };

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) return ok(true, "verification unavailable"); // fail open

    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    let parsed: { pass?: boolean; reason?: string } = {};
    try {
      parsed = JSON.parse(content);
    } catch {
      return ok(true, "could not parse"); // fail open
    }

    // Only an explicit false fails.
    return ok(parsed.pass !== false, parsed.reason ?? "");
  } catch (_e) {
    return ok(true, "error"); // fail open
  }
});

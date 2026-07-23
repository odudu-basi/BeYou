// Verifies a wake-up EXERCISE mission (Push Ups / Squats) with OpenAI vision (gpt-4o-mini).
// The client records a short video, samples a handful of frames, and sends them here.
// Returns { pass: boolean, reason: string }. Fails OPEN (pass=true) on any error so a groggy
// user is never trapped by a network/AI failure — same policy as verify-mission-photo.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function instruction(mission: string): string {
  switch (mission) {
    case "Push Ups":
      return `The user must do PUSH-UPS facing the camera. The images are frames sampled from a short video. ` +
        `Pass if the frames show a real person performing push-ups — i.e. a plank/prone position on hands (and toes/knees) ` +
        `with the body lowering toward and pushing away from the floor across the frames. Be LENIENT: if it plausibly looks ` +
        `like the person is doing push-ups (or clearly in a push-up position mid-motion), pass. ` +
        `Only fail if there is clearly NO person exercising — e.g. an empty room, a person just sitting/standing still, ` +
        `or a photo of a screen.`;
    case "Squats":
      return `The user must do SQUATS facing the camera. The images are frames sampled from a short video. ` +
        `Pass if the frames show a real person performing squats — i.e. standing and bending the knees to lower the hips ` +
        `and rising back up across the frames. Be LENIENT: if it plausibly looks like the person is doing squats ` +
        `(or clearly mid-squat), pass. Only fail if there is clearly NO person exercising — e.g. an empty room, ` +
        `a person just sitting/standing still, or a photo of a screen.`;
    default:
      return `Decide whether these frames show a person performing the exercise "${mission}". Be lenient; when in doubt, pass.`;
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
    const { mission, framesBase64 } = await req.json();
    const frames: string[] = Array.isArray(framesBase64) ? framesBase64.filter((f) => typeof f === "string" && f.length > 0) : [];
    if (frames.length === 0) return ok(true, "no frames"); // fail open

    // Cap the number of frames we forward (cost/latency); keep an even spread.
    const maxFrames = 6;
    const chosen = frames.length <= maxFrames
      ? frames
      : Array.from({ length: maxFrames }, (_, i) => frames[Math.floor(i * (frames.length - 1) / (maxFrames - 1))]);

    const imageContent = chosen.map((b64) => ({
      type: "image_url",
      image_url: { url: `data:image/jpeg;base64,${b64}`, detail: "low" },
    }));

    const body = {
      model: "gpt-4o-mini",
      temperature: 0,
      max_tokens: 120,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            `You verify wake-up alarm exercise videos from sampled frames. ${instruction(mission)} ` +
            `Respond ONLY with JSON: {"pass": boolean, "reason": string}. ` +
            `"reason" is a short, friendly, user-facing message (max ~10 words).`,
        },
        {
          role: "user",
          content: [
            { type: "text", text: `These frames are sampled in order from the video. Verify the ${mission}.` },
            ...imageContent,
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

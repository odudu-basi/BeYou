// Edge Function to send APNs push notification when user taps Continue on shield
// This wakes up the BeYou app and shows the intervention flow

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

// Environment variables - set these in Supabase dashboard
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = "com.odudu.BeYou"; // Your app's bundle identifier
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT") || "development"; // "development" or "production"

// APNs server URLs
const APNS_URLS = {
  development: "https://api.sandbox.push.apple.com",
  production: "https://api.push.apple.com"
};

/**
 * Generates a JWT token for APNs authentication
 * APNs requires ES256 algorithm with your Apple Push Key
 */
async function generateAPNsJWT(): Promise<string> {
  try {
    console.log("🔑 Generating APNs JWT token...");

    // JWT Header
    const header = {
      alg: "ES256",
      kid: APNS_KEY_ID,
      typ: "JWT"
    };

    // JWT Payload
    const payload = {
      iss: APNS_TEAM_ID,
      iat: Math.floor(Date.now() / 1000)
    };

  // Base64URL encode header and payload
  const encodeBase64Url = (obj: object): string => {
    const jsonString = JSON.stringify(obj);
    const base64 = btoa(jsonString);
    return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  };

  const encodedHeader = encodeBase64Url(header);
  const encodedPayload = encodeBase64Url(payload);
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  // Import the private key
  const privateKeyPEM = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const privateKeyDER = Uint8Array.from(atob(privateKeyPEM), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyDER,
    {
      name: "ECDSA",
      namedCurve: "P-256"
    },
    false,
    ["sign"]
  );

  // Sign the JWT
  const signature = await crypto.subtle.sign(
    {
      name: "ECDSA",
      hash: "SHA-256"
    },
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  // Convert signature to base64url
  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const signatureBase64Url = signatureBase64
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

    const jwt = `${signingInput}.${signatureBase64Url}`;
    console.log("✅ JWT generated successfully");
    return jwt;
  } catch (error) {
    console.error("❌ JWT generation failed:");
    console.error(`   Error: ${error instanceof Error ? error.message : String(error)}`);
    throw error;
  }
}

/**
 * Sends a push notification via APNs
 */
async function sendAPNsPush(deviceToken: string, appName: string): Promise<boolean> {
  console.log(`📤 Sending push notification for app: ${appName}`);
  console.log(`📱 Device token: ${deviceToken.substring(0, 20)}...`);

  try {
    // Generate JWT for authentication
    console.log("🔐 Generating JWT...");
    const jwt = await generateAPNsJWT();
    console.log("✅ JWT generated successfully");

    // Create the APNs payload
    const payload = {
      aps: {
        alert: {
          title: "Ready to unlock the app?",
          body: "Tap to complete your mindful moment"
        },
        sound: "default",
        badge: 1,
        "content-available": 1 // Wake app in background
      },
      // Custom data
      appName: appName,
      type: "unlockRequest",
      action: "openIntervention"
    };

    // APNs URL
    const apnsUrl = `${APNS_URLS[APNS_ENVIRONMENT as keyof typeof APNS_URLS]}/3/device/${deviceToken}`;
    console.log(`📡 APNs URL: ${apnsUrl}`);

    // Send request to APNs
    const response = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10", // High priority
        "content-type": "application/json"
      },
      body: JSON.stringify(payload)
    });

    console.log(`📊 APNs response status: ${response.status}`);

    if (response.ok) {
      console.log("✅ Push notification sent successfully!");
      return true;
    } else {
      const errorText = await response.text();
      console.error(`❌ APNs error response:`);
      console.error(`   Status: ${response.status}`);
      console.error(`   Body: ${errorText}`);
      console.error(`   Headers: ${JSON.stringify(Object.fromEntries(response.headers))}`);
      return false;
    }
  } catch (error) {
    console.error("❌ Error sending push notification:");
    console.error(`   Error type: ${error?.constructor?.name}`);
    console.error(`   Error message: ${error instanceof Error ? error.message : String(error)}`);
    console.error(`   Error stack: ${error instanceof Error ? error.stack : "No stack"}`);
    return false;
  }
}

/**
 * Main Edge Function handler
 */
serve(async (req) => {
  console.log("🚀 Edge Function invoked: send-unlock-push");

  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Parse request body
    const { deviceToken, appName, userID } = await req.json();

    console.log(`📥 Request received:`);
    console.log(`   - App: ${appName}`);
    console.log(`   - User ID: ${userID}`);
    console.log(`   - Device token: ${deviceToken?.substring(0, 20)}...`);

    // Validate inputs
    if (!deviceToken) {
      console.error("❌ Missing device token");
      return new Response(
        JSON.stringify({ error: "Device token is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    if (!appName) {
      console.error("❌ Missing app name");
      return new Response(
        JSON.stringify({ error: "App name is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // Validate environment variables
    console.log(`🔍 Checking APNs config...`);
    console.log(`   - APNS_KEY_ID: ${APNS_KEY_ID ? "✅ Set" : "❌ Missing"}`);
    console.log(`   - APNS_TEAM_ID: ${APNS_TEAM_ID ? "✅ Set" : "❌ Missing"}`);
    console.log(`   - APNS_PRIVATE_KEY: ${APNS_PRIVATE_KEY ? "✅ Set" : "❌ Missing"}`);
    console.log(`   - APNS_ENVIRONMENT: ${APNS_ENVIRONMENT}`);
    console.log(`   - APNS_BUNDLE_ID: ${APNS_BUNDLE_ID}`);

    if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
      console.error("❌ Missing APNs configuration");
      return new Response(
        JSON.stringify({
          error: "APNs configuration missing",
          details: {
            keyId: !!APNS_KEY_ID,
            teamId: !!APNS_TEAM_ID,
            privateKey: !!APNS_PRIVATE_KEY
          }
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // Send the push notification
    const success = await sendAPNsPush(deviceToken, appName);

    if (success) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Push notification sent successfully"
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Failed to send push notification"
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      );
    }
  } catch (error) {
    console.error("❌ Edge Function error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});

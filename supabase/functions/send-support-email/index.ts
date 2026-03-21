// Supabase Edge Function to send support emails via Resend
// IMPORTANT: This keeps the Resend API key secure on the server

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = "re_VkYYKndX_PcuJNREbFiaDxc6LRKVXqwF6"
const SUPPORT_EMAIL = "oduduabasiav@gmail.com"

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    })
  }

  try {
    // Parse request body
    const { email, subject, message, userName, userId } = await req.json()

    // Validate input
    if (!email || !subject || !message) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email, subject, message' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }

    // Send email via Resend API
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'BeYou Support <onboarding@resend.dev>',
        reply_to: [email, SUPPORT_EMAIL],
        to: [SUPPORT_EMAIL],
        subject: `[BeYou Support] ${subject}`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                line-height: 1.6;
                color: #1A1A1A;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
              }
              .header {
                background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%);
                padding: 30px 20px;
                border-radius: 12px 12px 0 0;
                text-align: center;
              }
              .header h1 {
                color: white;
                margin: 0;
                font-size: 24px;
              }
              .content {
                background: #F8F8F8;
                padding: 30px 20px;
              }
              .info-box {
                background: white;
                border-left: 4px solid #6366F1;
                padding: 15px;
                margin-bottom: 20px;
                border-radius: 4px;
              }
              .info-box strong {
                color: #6366F1;
              }
              .message-box {
                background: white;
                padding: 20px;
                border-radius: 8px;
                margin-top: 20px;
              }
              .footer {
                background: #1A1A1A;
                padding: 20px;
                border-radius: 0 0 12px 12px;
                text-align: center;
                color: #999999;
                font-size: 12px;
              }
            </style>
          </head>
          <body>
            <div class="header">
              <h1>💌 New Support Request</h1>
            </div>

            <div class="content">
              <div class="info-box">
                <strong>From:</strong> ${userName || 'User'}<br>
                <strong>Email:</strong> ${email}<br>
                <strong>User ID:</strong> ${userId || 'Unknown'}<br>
                <strong>Subject:</strong> ${subject}
              </div>

              <div class="message-box">
                <h3 style="margin-top: 0; color: #1A1A1A;">Message:</h3>
                <p style="white-space: pre-wrap; color: #666666;">${message}</p>
              </div>
            </div>

            <div class="footer">
              Sent from BeYou iOS App • Support System
            </div>
          </body>
          </html>
        `,
        text: `
New Support Request from BeYou App

From: ${userName || 'User'}
Email: ${email}
User ID: ${userId || 'Unknown'}
Subject: ${subject}

Message:
${message}

---
Reply to this email to respond directly to the user.
        `
      }),
    })

    const resendData = await resendResponse.json()

    if (!resendResponse.ok) {
      console.error('Resend API error:', resendData)
      return new Response(
        JSON.stringify({ error: resendData.message || 'Failed to send email' }),
        {
          status: resendResponse.status,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }

    // Success!
    return new Response(
      JSON.stringify({
        success: true,
        messageId: resendData.id,
        message: 'Email sent successfully'
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      }
    )

  } catch (error) {
    console.error('Error sending support email:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      }
    )
  }
})

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const ADMIN_EMAIL = Deno.env.get('ADMIN_EMAIL') || 'pushinn.ltd@gmail.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

serve(async (req) => {
    // Only allow POST requests (triggered by Webhook)
    if (req.method !== 'POST') {
        return new Response('Method Not Allowed', { status: 405 })
    }

    try {
        const payload = await req.json()
        const { record } = payload // standard Supabase webhook payload

        if (!record) {
            throw new Error('No record found in payload')
        }

        const { feedback_text, user_id } = record

        // 1. Fetch user profile for metadata
        const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)
        let username = 'Anonymous'
        let email = 'No Email'

        if (user_id) {
            const { data: profile } = await supabase
                .from('user_profiles')
                .select('username, email')
                .eq('id', user_id)
                .single()

            if (profile) {
                username = profile.username || username
                email = profile.email || email
            }
        }

        // 2. Transmit to Administrator via Resend
        if (!RESEND_API_KEY) {
            console.error('RESEND_API_KEY is not set')
            return new Response('Internal Server Error', { status: 500 })
        }

        const resendResponse = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
                from: 'Pushinn <feedback@pushinn.app>', // Note: Domain must be verified in Resend
                to: [ADMIN_EMAIL],
                subject: `New Feedback Received from ${username}`,
                html: `
          <h3>New Transmitted Intelligence</h3>
          <p><strong>Sender:</strong> ${username} (${email})</p>
          <p><strong>Database ID:</strong> ${user_id || 'untracked'}</p>
          <hr/>
          <p style="font-family: monospace; background: #f4f4f4; padding: 15px;">
            ${feedback_text.replace(/\n/g, '<br/>')}
          </p>
          <hr/>
          <p><small>This post was triggered by the Pushinn Neural Webhook.</small></p>
        `,
            }),
        })

        const result = await resendResponse.json()
        console.log('Email transmit response:', result)

        return new Response(JSON.stringify(result), {
            headers: { 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (err) {
        console.error('Email Transmission Error:', err)
        return new Response(JSON.stringify({ error: err.message }), {
            headers: { 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

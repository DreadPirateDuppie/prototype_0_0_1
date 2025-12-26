import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts"
import { encode } from "https://deno.land/std@0.168.0/encoding/hex.ts"

const IPN_SECRET = Deno.env.get('NOWPAYMENTS_IPN_SECRET')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 })
  }

  try {
    const signature = req.headers.get('x-nowpayments-sig')
    if (!signature) {
      console.error('Missing x-nowpayments-sig header')
      return new Response('Unauthorized', { status: 401 })
    }

    const bodyText = await req.text()
    const body = JSON.parse(bodyText)

    // 1. Verify Signature
    if (IPN_SECRET) {
      // Sort keys alphabetically
      const sortedKeys = Object.keys(body).sort()
      const sortedBody: Record<string, any> = {}
      sortedKeys.forEach(key => {
        sortedBody[key] = body[key]
      })

      const sortedBodyString = JSON.stringify(sortedBody)

      // Generate HMAC-SHA512
      const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(IPN_SECRET),
        { name: "HMAC", hash: "SHA-512" },
        false,
        ["sign"]
      )
      const signatureBuffer = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(sortedBodyString)
      )
      const generatedSignature = new TextDecoder().decode(encode(new Uint8Array(signatureBuffer)))

      if (generatedSignature !== signature) {
        console.error('Invalid signature')
        return new Response('Unauthorized', { status: 401 })
      }
    } else {
      console.warn('NOWPAYMENTS_IPN_SECRET not set, skipping signature verification (NOT RECOMMENDED FOR PRODUCTION)')
    }

    // 2. Process Payment
    const paymentStatus = body.payment_status
    const orderId = body.order_id // e.g., premium_USER_ID_TIMESTAMP

    if (paymentStatus === 'finished') {
      const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

      if (orderId?.startsWith('premium_')) {
        const parts = orderId.split('_')
        if (parts.length >= 2) {
          const userId = parts[1]
          const { error } = await supabase
            .from('user_profiles')
            .update({ is_premium: true })
            .eq('id', userId)

          if (error) {
            console.error('Error updating user status:', error)
            return new Response('Internal Server Error', { status: 500 })
          }
          console.log(`User ${userId} upgraded to premium successfully`)
        }
      } else if (orderId?.startsWith('donation_')) {
        // Handle donation
        const parts = orderId.split('_')
        // orderId format: donation_TIMESTAMP or donation_USERID_TIMESTAMP
        // In our current implementation, it's donation_TIMESTAMP

        const { error } = await supabase
          .from('donations')
          .upsert({
            order_id: orderId,
            payment_id: body.payment_id,
            amount: body.price_amount,
            currency: body.price_currency,
            status: paymentStatus,
            // If we had the userId in the orderId, we could link it here
          }, { onConflict: 'order_id' })

        if (error) {
          console.error('Error recording donation:', error)
          return new Response('Internal Server Error', { status: 500 })
        }
        console.log(`Donation ${orderId} recorded successfully`)
      }
    }

    return new Response('OK', { status: 200 })
  } catch (err) {
    console.error('IPN Processing Error:', err)
    return new Response('Bad Request', { status: 400 })
  }
})

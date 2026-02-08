-- Migration: Setup Feedback Email Webhook
-- This script sets up a database webhook to trigger the Edge Function whenever a new feedback is submitted.

-- 1. Create the webhook trigger
-- Note: Replace '{YOUR_PROJECT_ID}' with your actual Supabase project ID
-- This is usually done through the Supabase UI (Database -> Webhooks), 
-- but this SQL provides a reference for what's happening.

-- Drop if exists (idempotency)
-- We can't easily drop webhooks via SQL if they were created via UI, 
-- but for a fresh migration:

-- Example for triggering Edge Function:
-- (Supabase Http Webhooks are often managed via the 'net' extension or the UI)

/* 
INSTRUCTIONS FOR SUPABASE UI:
1. Go to Database -> Webhooks
2. Create a new Webhook:
   - Name: "send_feedback_email"
   - Table: "user_feedback"
   - Events: "Insert"
   - Target: "HTTP Request" (or Edge Function if visible)
   - Method: POST
   - URL: https://[YOUR_PROJECT_ID].supabase.co/functions/v1/send-feedback-email
   - Auth: Service Role (for security) or use the 'Authorization' header with your service role key.
*/

-- Alternatively, using the 'net' extension if enabled:
-- CREATE TRIGGER on_feedback_inserted
--   AFTER INSERT ON public.user_feedback
--   FOR EACH ROW
--   EXECUTE FUNCTION supabase_functions.http_request(
--     'https://[YOUR_PROJECT_ID].supabase.co/functions/v1/send-feedback-email',
--     'POST',
--     '{"Content-Type":"application/json", "Authorization":"Bearer [YOUR_SERVICE_ROLE_KEY]"}',
--     '{}', -- body is handled by record payload
--     '1000'
--   );

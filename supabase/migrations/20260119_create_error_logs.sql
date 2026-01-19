-- Migration: Create error_logs table
-- Created: 2026-01-19

CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    error_type TEXT,
    device_info JSONB,
    severity TEXT DEFAULT 'error'
);

-- Enable RLS
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert their own error logs
CREATE POLICY "Users can insert their own error logs" 
ON error_logs FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Allow anonymous users to insert error logs (optional, for auth failures)
CREATE POLICY "Anyone can insert error logs"
ON error_logs FOR INSERT
TO anon
WITH CHECK (true);

-- Allow admins to read all logs
-- Note: Replace with your actual admin role or check if needed
CREATE POLICY "Admins can view all error logs"
ON error_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid()
    AND (user_profiles.is_admin = true OR user_profiles.email LIKE '%@pushinn.com')
  )
);

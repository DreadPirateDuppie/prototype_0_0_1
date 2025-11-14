# Database Schema for Point System

## Required Supabase Table

To use the point system and daily wheel spin feature, you need to create the following table in your Supabase database:

### user_points Table

```sql
CREATE TABLE user_points (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    points INTEGER NOT NULL DEFAULT 0,
    last_spin_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can view their own points
CREATE POLICY "Users can view own points"
ON user_points
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own points record
CREATE POLICY "Users can insert own points"
ON user_points
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own points
CREATE POLICY "Users can update own points"
ON user_points
FOR UPDATE
USING (auth.uid() = user_id);
```

## Usage

After creating this table in your Supabase project:
1. The app will automatically create a new points record for users when they first visit the Rewards tab
2. Users start with 0 points
3. Users can spin the wheel once per day to earn points (10, 25, 50, 100, 200, or 500 points)
4. Points can be used to redeem rewards

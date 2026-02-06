-- Schema Alignment Migration
-- This script ensures 'battles' and 'spot_videos' tables exist and have consistent columns.
-- It also creates the 'battle_tricks' table for history.

-- 0. Ensure extensions are enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Ensure spot_videos table exists and is updated
CREATE TABLE IF NOT EXISTS public.spot_videos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spot_id UUID NOT NULL,
    url TEXT,
    skater_name TEXT,
    submitted_by UUID REFERENCES auth.users(id),
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.spot_videos 
ADD COLUMN IF NOT EXISTS trick_name TEXT,
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

COMMENT ON COLUMN public.spot_videos.trick_name IS 'Standardized field for the trick name';
COMMENT ON COLUMN public.spot_videos.thumbnail_url IS 'URL for video thumbnail image';

-- 2. Ensure battles table exists and is updated
CREATE TABLE IF NOT EXISTS public.battles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player1_id UUID REFERENCES auth.users(id) NOT NULL,
    player2_id UUID REFERENCES auth.users(id) NOT NULL,
    game_mode TEXT NOT NULL,
    current_turn_player_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.battles
ADD COLUMN IF NOT EXISTS trick_name TEXT,
ADD COLUMN IF NOT EXISTS setter_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS attempter_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS setter_vote TEXT CHECK (setter_vote IN ('landed', 'missed')),
ADD COLUMN IF NOT EXISTS attempter_vote TEXT CHECK (attempter_vote IN ('landed', 'missed')),
ADD COLUMN IF NOT EXISTS player1_rps_move TEXT CHECK (player1_rps_move IN ('rock', 'paper', 'scissors')),
ADD COLUMN IF NOT EXISTS player2_rps_move TEXT CHECK (player2_rps_move IN ('rock', 'paper', 'scissors')),
ADD COLUMN IF NOT EXISTS wager_amount INTEGER DEFAULT 0;

COMMENT ON COLUMN public.battles.trick_name IS 'Name of the trick currently being contested';
COMMENT ON COLUMN public.battles.setter_id IS 'Current setter of the trick';
COMMENT ON COLUMN public.battles.attempter_id IS 'Current attempter of the trick';

-- 3. Create battle_tricks table for history
CREATE TABLE IF NOT EXISTS public.battle_tricks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    battle_id UUID REFERENCES public.battles(id) ON DELETE CASCADE NOT NULL,
    setter_id UUID REFERENCES auth.users(id) NOT NULL,
    attempter_id UUID REFERENCES auth.users(id) NOT NULL,
    trick_name TEXT NOT NULL,
    set_trick_video_url TEXT NOT NULL,
    attempt_video_url TEXT NOT NULL,
    outcome TEXT NOT NULL CHECK (outcome IN ('landed', 'missed')),
    letters_given TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for battle_tricks
ALTER TABLE public.battle_tricks ENABLE ROW LEVEL SECURITY;

-- Policies for battle_tricks
DROP POLICY IF EXISTS "Public read access for battle_tricks" ON public.battle_tricks;
CREATE POLICY "Public read access for battle_tricks" 
    ON public.battle_tricks FOR SELECT 
    USING (true);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_battle_tricks_battle_id ON public.battle_tricks(battle_id);
CREATE INDEX IF NOT EXISTS idx_battle_tricks_created_at ON public.battle_tricks(created_at);

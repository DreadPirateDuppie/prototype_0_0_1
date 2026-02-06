-- Create shops table
CREATE TABLE IF NOT EXISTS shops (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- The user who manages this shop
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    website_url TEXT,
    location_lat FLOAT,
    location_lng FLOAT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create sponsorship_offers table
CREATE TABLE IF NOT EXISTS sponsorship_offers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'flow', 'am', 'pro', 'one_time'
    status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected', 'expired'
    terms TEXT, -- Description of what is offered/expected
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Add is_sponsorable column to user_profiles (assuming user_profiles table exists, or auth.users metadata)
-- We'll add it to user_profiles if it exists, or create a separate table for skater stats if needed.
-- Based on previous context, there is a user_profiles table.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'is_sponsorable'
    ) THEN
        ALTER TABLE user_profiles
        ADD COLUMN is_sponsorable BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shops_owner_id ON shops(owner_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_user_id ON sponsorship_offers(user_id);
CREATE INDEX IF NOT EXISTS idx_sponsorship_offers_shop_id ON sponsorship_offers(shop_id);

-- Enable RLS
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE sponsorship_offers ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Public read access for shops" ON shops
    FOR SELECT USING (true);

CREATE POLICY "Shop owners can update their shop" ON shops
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can see their own offers" ON sponsorship_offers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Shop owners can see offers they sent" ON sponsorship_offers
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM shops WHERE id = sponsorship_offers.shop_id AND owner_id = auth.uid()
    ));

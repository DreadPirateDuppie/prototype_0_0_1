-- Add user_email and user_name columns to map_posts table if they don't exist

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'map_posts' AND column_name = 'user_email') THEN
        ALTER TABLE map_posts ADD COLUMN user_email TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'map_posts' AND column_name = 'user_name') THEN
        ALTER TABLE map_posts ADD COLUMN user_name TEXT;
    END IF;
END $$;

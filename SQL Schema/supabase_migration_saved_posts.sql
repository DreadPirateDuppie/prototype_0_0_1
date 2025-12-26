-- Create saved_posts table
CREATE TABLE IF NOT EXISTS public.saved_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.map_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, post_id)
);

-- Enable RLS
ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can view their own saved posts" ON public.saved_posts;
CREATE POLICY "Users can view their own saved posts"
    ON public.saved_posts FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can save posts" ON public.saved_posts;
CREATE POLICY "Users can save posts"
    ON public.saved_posts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unsave posts" ON public.saved_posts;
CREATE POLICY "Users can unsave posts"
    ON public.saved_posts FOR DELETE
    USING (auth.uid() = user_id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS saved_posts_user_id_idx ON public.saved_posts(user_id);
CREATE INDEX IF NOT EXISTS saved_posts_post_id_idx ON public.saved_posts(post_id);

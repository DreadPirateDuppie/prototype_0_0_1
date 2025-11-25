-- Add category and tags columns to map_posts table
ALTER TABLE public.map_posts 
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Other',
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Add indexes for filtering performance
CREATE INDEX IF NOT EXISTS map_posts_category_idx ON public.map_posts(category);
CREATE INDEX IF NOT EXISTS map_posts_tags_idx ON public.map_posts USING GIN(tags);

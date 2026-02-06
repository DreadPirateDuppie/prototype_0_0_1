-- 1. Alter spot_videos table to support external clips and weighted scoring
ALTER TABLE public.spot_videos 
ADD COLUMN IF NOT EXISTS trick_name_ext TEXT, -- Detailed trick name for the clip
ADD COLUMN IF NOT EXISTS is_own_clip BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS stance TEXT DEFAULT 'regular',
ADD COLUMN IF NOT EXISTS difficulty_multiplier DECIMAL DEFAULT 1.0;

-- Existing table columns for reference:
-- id, spot_id, url, platform, skater_name, description, submitted_by, status, upvotes, created_at, tags

-- 1.5 Create trick_definitions table
CREATE TABLE IF NOT EXISTS trick_definitions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug TEXT UNIQUE NOT NULL, -- e.g., 'kickflip'
  display_name TEXT NOT NULL, -- e.g., 'Kickflip'
  category TEXT NOT NULL, -- e.g., 'flip', 'grind', 'gap', 'transition', 'other'
  difficulty_multiplier DECIMAL DEFAULT 1.0,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create trick_aliases table
CREATE TABLE IF NOT EXISTS trick_aliases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trick_id UUID REFERENCES trick_definitions(id) ON DELETE CASCADE,
  alias TEXT UNIQUE NOT NULL, -- e.g., 'tre flip', '3 flip', '360 flip'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Add indices for faster search
CREATE INDEX IF NOT EXISTS idx_trick_definitions_slug ON trick_definitions(slug);
CREATE INDEX IF NOT EXISTS idx_trick_aliases_alias ON trick_aliases(alias);

-- 4. Seed with User-Defined 5-Level Hierarchy
INSERT INTO trick_definitions (slug, display_name, category, difficulty_multiplier, description)
VALUES 
  -- Level 1: Foundational Physics (1.0)
  ('ollie', 'Ollie', 'flatground', 1.0, 'The fundamental jump.'),
  ('shuv-it', 'Shuv-it', 'flatground', 1.0, '180-degree board rotation parallel to the ground.'),
  ('manual', 'Manual', 'balance', 1.0, 'Balancing on back wheels.'),
  ('nose-manual', 'Nose Manual', 'balance', 1.0, 'Balancing on front wheels.'),

  -- Level 2: Basic Flip and Directional (1.3)
  ('kickflip', 'Kickflip', 'flip', 1.3, 'Longitudinal 360-degree flip.'),
  ('heelflip', 'Heelflip', 'flip', 1.3, 'Longitudinal 360-degree flip using the heel.'),
  ('fs-180', 'FS 180 Ollie', 'flatground', 1.3, '180-degree rotation with body.'),
  ('bs-180', 'BS 180 Ollie', 'flatground', 1.3, '180-degree rotation with body (blind landing).'),

  -- Level 3: Technical Compound (1.7)
  ('varial-kickflip', 'Varial Kickflip', 'flip', 1.7, '180 shove-it combined with a kickflip.'),
  ('varial-heelflip', 'Varial Heelflip', 'flip', 1.7, '180 shove-it combined with a heelflip.'),
  ('bs-flip', 'Backside Flip', 'flip', 1.7, 'BS 180 combined with a kickflip.'),
  ('fs-flip', 'Frontside Flip', 'flip', 1.7, 'FS 180 combined with a kickflip.'),
  ('bs-50-50', 'BS 50-50', 'grind', 1.7, 'Both trucks grinding on the obstacle.'),

  -- Level 4: Advanced Multi-Axis (2.2)
  ('360-flip', '360 Flip', 'flip', 2.2, '360 shove-it combined with a kickflip.'),
  ('hardflip', 'Hardflip', 'flip', 2.2, 'Frontside shove-it with a kickflip through legs.'),
  ('inward-heelflip', 'Inward Heelflip', 'flip', 2.2, 'Backside shove-it with a heelflip through legs.'),
  ('bluntslide', 'Bluntslide', 'slide', 2.2, 'Tail locked on top of rail/ledge.'),

  -- Level 5: Elite Technical (3.0)
  ('laser-flip', 'Laser Flip', 'flip', 3.0, '360 FS shove-it combined with a heelflip.'),
  ('bigspin', 'Bigspin', 'flatground', 3.0, '360 board rotation with 180 body rotation.'),
  ('late-flip', 'Late Flip', 'flip', 3.0, 'Initiating the flip at the peak of an ollie.')
ON CONFLICT (slug) DO UPDATE SET 
  difficulty_multiplier = EXCLUDED.difficulty_multiplier,
  description = EXCLUDED.description;

-- 5. Seed aliases for common tricks
INSERT INTO trick_aliases (trick_id, alias)
SELECT id, 'tre flip' FROM trick_definitions WHERE slug = '360-flip'
ON CONFLICT (alias) DO NOTHING;

INSERT INTO trick_aliases (trick_id, alias)
-- 6. Create RPC for efficient trick search across definitions and aliases
CREATE OR REPLACE FUNCTION search_tricks(search_query TEXT)
RETURNS SETOF trick_definitions AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT td.*
  FROM trick_definitions td
  LEFT JOIN trick_aliases ta ON td.id = ta.trick_id
  WHERE 
    td.display_name ILIKE '%' || search_query || '%'
    OR td.slug ILIKE '%' || search_query || '%'
    OR ta.alias ILIKE '%' || search_query || '%'
  ORDER BY td.difficulty_multiplier DESC
  LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

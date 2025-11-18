# VS Tab Database Schema

This document describes the database tables needed for the VS Tab feature.

## Tables to Create in Supabase

### 1. user_scores

Stores the three scoring metrics for each user.

```sql
CREATE TABLE user_scores (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  map_score DECIMAL(5,2) DEFAULT 500.0 CHECK (map_score >= 0 AND map_score <= 1000),
  player_score DECIMAL(5,2) DEFAULT 500.0 CHECK (player_score >= 0 AND player_score <= 1000),
  ranking_score DECIMAL(5,2) DEFAULT 500.0 CHECK (ranking_score >= 0 AND ranking_score <= 1000),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX idx_user_scores_user_id ON user_scores(user_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_scores_updated_at BEFORE UPDATE
    ON user_scores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 2. battles

Stores information about SKATE battles between two players.

```sql
CREATE TABLE battles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  player1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  player2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_mode TEXT NOT NULL CHECK (game_mode IN ('skate', 'sk8', 'custom')),
  custom_letters TEXT DEFAULT '',
  player1_letters TEXT DEFAULT '',
  player2_letters TEXT DEFAULT '',
  set_trick_video_url TEXT,
  attempt_video_url TEXT,
  verification_status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (verification_status IN ('pending', 'quickFireVoting', 'communityVerification', 'resolved')),
  current_turn_player_id UUID NOT NULL REFERENCES auth.users(id),
  winner_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- Indexes for faster queries
CREATE INDEX idx_battles_player1 ON battles(player1_id);
CREATE INDEX idx_battles_player2 ON battles(player2_id);
CREATE INDEX idx_battles_status ON battles(verification_status);
CREATE INDEX idx_battles_winner ON battles(winner_id);
CREATE INDEX idx_battles_created ON battles(created_at DESC);
```

### 3. verification_attempts

Stores video attempts that need verification.

```sql
CREATE TABLE verification_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  battle_id UUID NOT NULL REFERENCES battles(id) ON DELETE CASCADE,
  attempting_player_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attempt_video_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'quickFireVoting', 'communityVerification', 'resolved')),
  result TEXT CHECK (result IN ('land', 'noLand', 'rebate')),
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_verification_attempts_battle ON verification_attempts(battle_id);
CREATE INDEX idx_verification_attempts_player ON verification_attempts(attempting_player_id);
CREATE INDEX idx_verification_attempts_status ON verification_attempts(status);
```

### 4. quick_fire_votes

Stores Quick-Fire voting sessions between the two battle players.

```sql
CREATE TABLE quick_fire_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  attempt_id UUID NOT NULL REFERENCES verification_attempts(id) ON DELETE CASCADE,
  player1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  player2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  player1_vote TEXT CHECK (player1_vote IN ('land', 'noLand', 'rebate')),
  player2_vote TEXT CHECK (player2_vote IN ('land', 'noLand', 'rebate')),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_quick_fire_votes_attempt ON quick_fire_votes(attempt_id);
CREATE UNIQUE INDEX idx_quick_fire_votes_attempt_unique ON quick_fire_votes(attempt_id);
```

### 5. community_votes

Stores community verification votes with vote weighting.

```sql
CREATE TABLE community_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  attempt_id UUID NOT NULL REFERENCES verification_attempts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type TEXT NOT NULL CHECK (vote_type IN ('land', 'noLand', 'rebate')),
  vote_weight DECIMAL(4,3) NOT NULL CHECK (vote_weight >= 0 AND vote_weight <= 1),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(attempt_id, user_id)
);

-- Indexes
CREATE INDEX idx_community_votes_attempt ON community_votes(attempt_id);
CREATE INDEX idx_community_votes_user ON community_votes(user_id);
```

### 6. battle_videos storage bucket

Create a storage bucket in Supabase for battle videos:

1. Go to Storage in Supabase dashboard
2. Create a new bucket named `battle_videos`
3. Set it to public or authenticated based on your privacy requirements
4. Configure upload size limits as needed (recommend at least 50MB for short videos)

## Row Level Security (RLS) Policies

Enable RLS on all tables and create appropriate policies:

### user_scores

```sql
-- Enable RLS
ALTER TABLE user_scores ENABLE ROW LEVEL SECURITY;

-- Users can view all scores
CREATE POLICY "Scores are viewable by everyone" 
  ON user_scores FOR SELECT 
  USING (true);

-- System can update scores (this would be done via service role)
-- You may want more restrictive policies based on your auth setup
```

### battles

```sql
ALTER TABLE battles ENABLE ROW LEVEL SECURITY;

-- Players can view their own battles
CREATE POLICY "Users can view their battles" 
  ON battles FOR SELECT 
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- Players can create battles
CREATE POLICY "Users can create battles" 
  ON battles FOR INSERT 
  WITH CHECK (auth.uid() = player1_id);

-- Players can update their own battles
CREATE POLICY "Players can update their battles" 
  ON battles FOR UPDATE 
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);
```

### verification_attempts

```sql
ALTER TABLE verification_attempts ENABLE ROW LEVEL SECURITY;

-- Everyone can view attempts in community verification
CREATE POLICY "Community verification is public" 
  ON verification_attempts FOR SELECT 
  USING (status = 'communityVerification');

-- Battle participants can view their attempts
CREATE POLICY "Players can view their attempts" 
  ON verification_attempts FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM battles 
      WHERE battles.id = verification_attempts.battle_id 
      AND (battles.player1_id = auth.uid() OR battles.player2_id = auth.uid())
    )
  );

-- Players can create attempts for their battles
CREATE POLICY "Players can create attempts" 
  ON verification_attempts FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM battles 
      WHERE battles.id = battle_id 
      AND (battles.player1_id = auth.uid() OR battles.player2_id = auth.uid())
    )
  );
```

### quick_fire_votes

```sql
ALTER TABLE quick_fire_votes ENABLE ROW LEVEL SECURITY;

-- Players can view their Quick-Fire votes
CREATE POLICY "Players can view Quick-Fire votes" 
  ON quick_fire_votes FOR SELECT 
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- System creates Quick-Fire sessions
CREATE POLICY "System can create Quick-Fire votes" 
  ON quick_fire_votes FOR INSERT 
  WITH CHECK (true);

-- Players can update their votes
CREATE POLICY "Players can update their votes" 
  ON quick_fire_votes FOR UPDATE 
  USING (auth.uid() = player1_id OR auth.uid() = player2_id);
```

### community_votes

```sql
ALTER TABLE community_votes ENABLE ROW LEVEL SECURITY;

-- Users can view all community votes
CREATE POLICY "Community votes are viewable" 
  ON community_votes FOR SELECT 
  USING (true);

-- Users can insert their own votes
CREATE POLICY "Users can submit votes" 
  ON community_votes FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own votes
CREATE POLICY "Users can update their votes" 
  ON community_votes FOR UPDATE 
  USING (auth.uid() = user_id);
```

## Setup Instructions

1. Run all the CREATE TABLE statements in the Supabase SQL Editor
2. Create the storage bucket `battle_videos`
3. Apply all RLS policies
4. Test by creating a battle and uploading videos

## Notes

- All score values are constrained to 0-1000 range
- Vote weights are constrained to 0-1 range
- The system uses CASCADE deletes to maintain referential integrity
- Timestamps use PostgreSQL's NOW() function for automatic timestamping

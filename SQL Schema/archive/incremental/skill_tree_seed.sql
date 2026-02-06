-- Seed data for trick_nodes

DO $$
DECLARE
    ollie_id UUID;
    pop_shuvit_id UUID;
    fs_180_id UUID;
    bs_180_id UUID;
    kickflip_id UUID;
    heelflip_id UUID;
    varial_flip_id UUID;
BEGIN
    -- 1. Ollie (Root)
    INSERT INTO trick_nodes (name, description, difficulty, category, points_value)
    VALUES ('Ollie', 'The foundation of street skating.', 1, 'flat', 50)
    RETURNING id INTO ollie_id;

    -- 2. Level 1 Tricks (Require Ollie)
    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Pop Shuvit', 'Spin the board 180 degrees without flipping.', 2, 'flat', ARRAY[ollie_id], 100)
    RETURNING id INTO pop_shuvit_id;

    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Frontside 180', 'Rotate your body and board 180 degrees frontside.', 2, 'flat', ARRAY[ollie_id], 100)
    RETURNING id INTO fs_180_id;

    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Backside 180', 'Rotate your body and board 180 degrees backside.', 2, 'flat', ARRAY[ollie_id], 100)
    RETURNING id INTO bs_180_id;

    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Kickflip', 'Flip the board with your toe.', 3, 'flat', ARRAY[ollie_id], 150)
    RETURNING id INTO kickflip_id;

    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Heelflip', 'Flip the board with your heel.', 3, 'flat', ARRAY[ollie_id], 150)
    RETURNING id INTO heelflip_id;

    -- 3. Level 2 Tricks (Combinations)
    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Varial Kickflip', 'Combine a Pop Shuvit and a Kickflip.', 4, 'flat', ARRAY[pop_shuvit_id, kickflip_id], 200)
    RETURNING id INTO varial_flip_id;

    INSERT INTO trick_nodes (name, description, difficulty, category, parent_ids, points_value)
    VALUES ('Tre Flip', '360 Pop Shuvit + Kickflip.', 5, 'flat', ARRAY[varial_flip_id], 300);

    RAISE NOTICE 'Seeded trick nodes successfully.';
END $$;

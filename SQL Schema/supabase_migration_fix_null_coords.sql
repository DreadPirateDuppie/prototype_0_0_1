-- Fix null coordinates for dreadpirateduppie
UPDATE user_profiles
SET 
  current_latitude = 51.5074,
  current_longitude = -0.1278,
  location_updated_at = NOW()
WHERE username = 'dreadpirateduppie' AND current_latitude IS NULL;

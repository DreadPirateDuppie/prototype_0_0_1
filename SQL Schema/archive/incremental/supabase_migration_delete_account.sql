-- Create a function to allow users to delete their own account
-- This function runs with SECURITY DEFINER to have permissions to delete from auth.users
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void AS $$
BEGIN
    -- Only allow the user to delete their own record
    -- The WHERE clause ensures they can only delete themselves
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account TO authenticated;

-- Add a comment for clarity
COMMENT ON FUNCTION delete_user_account IS 'Allows a user to permanently delete their own authentication account and all cascading data.';

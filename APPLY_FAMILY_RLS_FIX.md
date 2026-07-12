# Apply Family RLS Policy Fix

## Problem
The `family_members` table RLS policies are causing infinite recursion because they query `family_members` within policies on the same table.

## Solution
Use `SECURITY DEFINER` functions that bypass RLS to check membership, then use those functions in the policies.

## Steps to Fix

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to SQL Editor

2. **Run the Fix Script**
   - Copy the entire contents of `fix_family_rls_policy_simple.sql`
   - Paste it into the SQL Editor
   - Click "Run" to execute

3. **Verify the Fix**
   - The script will:
     - Drop the old recursive policies
     - Create two helper functions (`user_is_family_member` and `user_is_family_owner`) that bypass RLS
     - Create new policies that use these functions (no recursion!)

4. **Test in Your App**
   - Try loading the Family screen again
   - The infinite recursion error should be gone
   - You should be able to view and manage families

## What Changed

The new approach uses `SECURITY DEFINER` functions which:
- Run with the privileges of the function creator (bypassing RLS)
- Can safely query `family_members` without causing recursion
- Are then used in RLS policies, which only call the functions (no direct queries to `family_members`)

This breaks the circular dependency and eliminates the recursion error.




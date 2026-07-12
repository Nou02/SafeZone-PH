# Fix Family RLS Policy and Navigation

## Issue 1: Infinite Recursion in RLS Policy

The `family_members` table RLS policies were causing infinite recursion because they were checking the `family_members` table within policies on the same table.

## Solution

Run the SQL script `fix_family_rls_policy.sql` in your Supabase SQL Editor to fix the RLS policies.

The fix changes the policies to:
1. Check the `families` table first instead of directly querying `family_members`
2. Use `EXISTS` clauses to avoid circular dependencies
3. Ensure policies can evaluate without recursion

## Issue 2: Family Tab Not Showing for Officials

The Family tab was already in the code for officials, but with 6 navigation items, the `BottomNavigationBarType.fixed` might not display all items properly.

## Solution

The navigation bar now automatically switches to `BottomNavigationBarType.shifting` when there are more than 5 items, which better handles 6 tabs.

## Steps to Fix

1. **Fix RLS Policies:**
   - Open Supabase Dashboard → SQL Editor
   - Run the contents of `fix_family_rls_policy.sql`
   - This will drop and recreate the policies without recursion

2. **Rebuild the App:**
   - The navigation code has been updated
   - Rebuild the APK to see the Family tab for all users

## Verification

After applying the fixes:
- Family tab should appear for all users (including officials)
- Family data should load without infinite recursion errors
- All 6 tabs should be visible for officials (Home, Create, My Reports, Map, Alerts, Family)
- All 5 tabs should be visible for normal users (Home, Create, My Reports, Map, Family)




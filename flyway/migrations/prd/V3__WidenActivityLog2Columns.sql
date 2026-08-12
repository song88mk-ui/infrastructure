-- BO-91: Manual Bet Settlement fails with "Error (An error occurred while updating the entries...)"
-- Root cause: ActivityLog2.Page/Activity/From/To are NVARCHAR(255), but the manual settlement
-- audit entry's "To" field stores a serialized bet object that routinely exceeds 255 characters.
-- Widening these columns to remove the length limit.

USE Backoffice;

ALTER TABLE ActivityLog2 ALTER COLUMN Page NVARCHAR(255);
ALTER TABLE ActivityLog2 ALTER COLUMN Activity NVARCHAR(255);
ALTER TABLE ActivityLog2 ALTER COLUMN [From] NVARCHAR(MAX);
ALTER TABLE ActivityLog2 ALTER COLUMN [To] NVARCHAR(MAX);

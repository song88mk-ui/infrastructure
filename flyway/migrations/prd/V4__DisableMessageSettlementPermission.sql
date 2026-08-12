-- Turn off "Message Settlement" admin permission (Admin.Settlements.MessageSettlement).
-- Removes the Permission row entirely so the claim is no longer issued to any role,
-- including Super Admin (Super Admin reads directly from the Permission table at
-- login, bypassing per-role AspNetRoleClaims settings).

USE Auth;

DELETE FROM Permission
WHERE PermissionId = '28F85DF5-5F98-ED11-8A17-00224815B68B';

-- rollback
-- USE Auth;
--
-- INSERT INTO Permission (PermissionId, CategoryId, CategoryName, SubCategoryName, GroupName, Name, ClaimType, HasReadOnly, SortOrder, IsSubUser, UserGroupTemplateIdRef, Version)
-- VALUES ('28F85DF5-5F98-ED11-8A17-00224815B68B', 0, 'Admin', 'Settlements', '', 'Message Settlement', 'Admin.Settlements.MessageSettlement', 0, 8, 0, 0, 2);

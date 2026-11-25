-- mod-temucraft-ptr: its commands as RBAC permissions 104001-104099 (104001-104049 admin, 104050-104099 player).
-- Player commands are linked to the player roles 195 and 1010, admin commands to 192 and 1014. Only this module's own
-- permission rows and their links are replaced; no role row is touched. Grant or deny per account with
-- .rbac account grant / deny <account> <id>.
DELETE FROM `rbac_linked_permissions` WHERE `linkedId` BETWEEN 104001 AND 104099;
DELETE FROM `rbac_permissions` WHERE `id` BETWEEN 104001 AND 104099;
INSERT INTO `rbac_permissions` (`id`, `name`) VALUES
(104001, 'Command: ptr requests'),
(104050, 'Command: ptr copy'),
(104051, 'Command: ptr copy list'),
(104052, 'Command: ptr status');
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(192, 104001),
(1014, 104001),
(195, 104050),
(1010, 104050),
(195, 104051),
(1010, 104051),
(195, 104052),
(1010, 104052);

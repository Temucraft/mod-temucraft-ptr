-- mod-ptr-template (Temucraft fork): its commands as RBAC permissions, instead of the security levels of the
-- original. 104101-104149 admin, 104150-104199 player (next to mod-temucraft-ptr's 104001-104099). Player permissions
-- are linked to the player roles 195 and 1010, admin ones to 192 and 1014. Only these permission rows and their links
-- are replaced; no role row is touched. Copy to the fork as data/sql/db-auth/ptr_template_rbac.sql.
DELETE FROM `rbac_linked_permissions` WHERE `linkedId` BETWEEN 104101 AND 104199;
DELETE FROM `rbac_permissions` WHERE `id` BETWEEN 104101 AND 104199;
INSERT INTO `rbac_permissions` (`id`, `name`) VALUES
(104101, 'Command: template enable'),
(104102, 'Command: template disable'),
(104103, 'PTR template: see and apply disabled templates'),
(104150, 'Command: template apply'),
(104151, 'Command: template list');
INSERT INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES
(192, 104101),
(1014, 104101),
(192, 104102),
(1014, 104102),
(192, 104103),
(1014, 104103),
(195, 104150),
(1010, 104150),
(195, 104151),
(1010, 104151);

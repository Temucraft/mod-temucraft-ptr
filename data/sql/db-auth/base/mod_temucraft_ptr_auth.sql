-- mod-temucraft-ptr: tables shared by the Live and the PTR worldservers (both use the same acore_auth).
-- Safe to run again: the tables are only created when missing.

-- Copy and template requests. Rows are added by .ptr copy, the PTR Quartermaster or an external tool (launcher).
-- See the module README ("Request table contract") for who sets which column and the order of the states.
CREATE TABLE IF NOT EXISTS `mod_temucraft_ptr_copy` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account` INT UNSIGNED NOT NULL COMMENT 'account.id that asks; the copy is made for this account only',
  `type` ENUM('copy', 'template') NOT NULL DEFAULT 'copy',
  `live_realm` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'realmlist.id of the Live realm of live_guid (0 = any Live realm)',
  `live_guid` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'copy: characters.guid on Live',
  `live_name` VARCHAR(12) NOT NULL DEFAULT '' COMMENT 'copy: the Live name (for display and as the default PTR name)',
  `template_index` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'template: mod_ptrtemplate_index.ID',
  `ptr_realm` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'realmlist.id of the PTR (0 = any PTR); set by the PTR when it is done',
  `ptr_name` VARCHAR(12) NOT NULL DEFAULT '' COMMENT 'copy: wanted PTR name (empty = live_name); template: the PTR character',
  `replace_old` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'copy: 1 = delete this account''s earlier PTR copy of the same Live character',
  `ptr_guid` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'copy: characters.guid of the copy on the PTR, set when done',
  `state` ENUM('requested', 'working', 'ready', 'loading', 'done', 'failed') NOT NULL DEFAULT 'requested',
  `message` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'last progress or error text, for the player',
  `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_state` (`state`, `type`),
  KEY `idx_account` (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='mod-temucraft-ptr: Live to PTR copy requests';

-- The Live characters of every account, written by the Live worldserver (Temucraft.PTR.CopyWriter = 1): all of them
-- at its start, then one row at a time on login, logout, level up, creation and deletion.
CREATE TABLE IF NOT EXISTS `mod_temucraft_ptr_live_chars` (
  `realm` INT UNSIGNED NOT NULL COMMENT 'realmlist.id of the Live realm',
  `realm_name` VARCHAR(32) NOT NULL DEFAULT '',
  `account` INT UNSIGNED NOT NULL,
  `guid` INT UNSIGNED NOT NULL,
  `name` VARCHAR(12) NOT NULL,
  `race` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `class` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`realm`, `guid`),
  KEY `idx_account` (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='mod-temucraft-ptr: Live characters a PTR copy can be made of';

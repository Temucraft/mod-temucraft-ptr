-- mod-temucraft-ptr: the PTR Quartermaster (free supplies, level-80 templates, Live copies).
-- Creature entries 609300-609309, npc_text 609300. The quartermasters have no `creature` rows: the PTR worldserver
-- (Temucraft.PTR.Enable = 1, Temucraft.PTR.Quartermaster.Enable = 1) places them at start, in front of the stock
-- bankers Olivia Burnside (spawn 79684, Stormwind Counting House) and Karus (spawn 6598, Orgrimmar bank). So this file
-- can go into a world database that Live uses too: nothing shows up on Live.
SET @ALLIANCE := 609300;
SET @HORDE := 609301;
SET @TEXT := 609300;

DELETE FROM `creature_template` WHERE `entry` BETWEEN @ALLIANCE AND @ALLIANCE+9;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `IconName`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `type`, `type_flags`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(@ALLIANCE, 'PTR Quartermaster', 'Test Realm Supplies', 'Speak', 80, 80, 12, 1, 1, 1.14286, 1, 2, 7, 0, 2, 'npc_temucraft_ptr_quartermaster', 0),
(@HORDE,    'PTR Quartermaster', 'Test Realm Supplies', 'Speak', 80, 80, 29, 1, 1, 1.14286, 1, 2, 7, 0, 2, 'npc_temucraft_ptr_quartermaster', 0);

-- the looks of the bankers they stand by (stock creature_template_model rows of 2455 Olivia Burnside and 3309 Karus)
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN @ALLIANCE AND @ALLIANCE+9;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @ALLIANCE, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0 FROM `creature_template_model` WHERE `CreatureID` = 2455;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @HORDE, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 0 FROM `creature_template_model` WHERE `CreatureID` = 3309;

DELETE FROM `npc_text` WHERE `ID` = @TEXT;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`) VALUES
(@TEXT, 'Welcome to the test realm. Supplies are free here, and nothing you do here ever goes back to Live. Take what you need.',
        'Welcome to the test realm. Supplies are free here, and nothing you do here ever goes back to Live. Take what you need.', 1);

-- What the quartermaster hands out, free. class_mask: 0 = everyone, else the classes it is for (1 Warrior, 2 Paladin,
-- 4 Hunter, 8 Rogue, 16 Priest, 32 Death Knight, 64 Shaman, 128 Mage, 256 Warlock, 1024 Druid). Every item is stock
-- WotLK (checked against item_template).
CREATE TABLE IF NOT EXISTS `mod_temucraft_ptr_supplies` (
  `item` INT UNSIGNED NOT NULL,
  `count` INT UNSIGNED NOT NULL DEFAULT 1,
  `class_mask` INT UNSIGNED NOT NULL DEFAULT 0,
  `sort` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `comment` VARCHAR(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='mod-temucraft-ptr: free PTR supplies';

DELETE FROM `mod_temucraft_ptr_supplies`;
INSERT INTO `mod_temucraft_ptr_supplies` (`item`, `count`, `class_mask`, `sort`, `comment`) VALUES
(41599,    4,    0, 1, 'Frostweave Bag'),
(43000,   20,    0, 2, 'Dragonfin Filet'),
(33445,   20,    0, 2, 'Honeymint Tea'),
(43015,    5,    0, 2, 'Fish Feast'),
(34722,   20,    0, 2, 'Heavy Frostweave Bandage'),
(33447,   20,    0, 3, 'Runic Healing Potion'),
(33448,   20, 1490, 3, 'Runic Mana Potion (mana users)'),
(40211,   10,    0, 3, 'Potion of Speed'),
(40212,   10, 1490, 3, 'Potion of Wild Magic (casters)'),
(40093,   10,    0, 3, 'Indestructible Potion'),
(46377,    5, 1135, 4, 'Flask of Endless Rage (physical damage)'),
(46376,    5, 1490, 4, 'Flask of the Frost Wyrm (spell damage)'),
(46378,    5, 1106, 4, 'Flask of Pure Mojo (healers)'),
(46379,    5, 1059, 4, 'Flask of Stoneblood (tanks)'),
(21177,  100,    2, 5, 'Symbol of Kings (paladin)'),
(17033,    5,    2, 5, 'Symbol of Divinity (paladin)'),
(44615,   20,   16, 5, 'Devout Candle (priest)'),
(17029,   20,   16, 5, 'Sacred Candle (priest)'),
(17056,   20,  144, 5, 'Light Feather (priest, mage)'),
(37201,   20,   32, 5, 'Corpse Dust (death knight)'),
(17030,   10,   64, 5, 'Ankh (shaman)'),
(17020,  100,  128, 5, 'Arcane Powder (mage)'),
(17031,   20,  128, 5, 'Rune of Teleportation (mage)'),
(17032,   20,  128, 5, 'Rune of Portals (mage)'),
(44605,   20, 1024, 5, 'Wild Spineleaf (druid)'),
(44614,   20, 1024, 5, 'Starleaf Seed (druid)'),
(5140,    20,    8, 5, 'Flash Powder (rogue)'),
(43231,   20,    8, 5, 'Instant Poison IX (rogue)'),
(43233,   20,    8, 5, 'Deadly Poison IX (rogue)'),
(41165, 1000,    4, 6, 'Saronite Razorheads (hunter arrows)'),
(41164, 1000,    4, 6, 'Mammoth Cutters (hunter bullets)');

-- Temucraft level-80 template sets for mod-ptr-template (Temucraft fork). Copy to the fork as
-- data/sql/db-world/ptr_template_set_temucraft.sql. Needs the fork's blizzlike set (template 3, 'Wrath Classic Level 80')
-- applied first: everything except the five tier slots is taken from it (level, Dalaran position and hearth, flight
-- paths, spells, skills, reputations, achievements, action bars, and neck/back/wrist/waist/feet/rings/trinkets/weapons/
-- bags). The tier slots (head, shoulders, chest, legs, hands) are the 10-man tier 7 sets (Naxxramas, item level 200).
-- Every item id below was checked against the stock acore_world item_template (name, item level 200, set, class).
-- TODO: template 3 gives one off-piece and weapon pick per class, so tank and healer templates get that class's
--       template 3 weapons/jewellery (often a damage spec's). Replace those rows per role when someone has verified ids.
SET
@tcmelee = 80,
@tcspell = 81,
@tctank = 82,
@tchealer = 83,
@base = 3,          -- the fork's 'Wrath Classic Level 80' (ptr_template_set_blizzlike.sql)
-- Rows of template 3 are copied only for the classes a template is for (ClassMask & the template's classes).
@allraces = 1791;   -- 1+2+4+8+16+32+64+128+512+1024: every playable race

DELETE FROM `mod_ptrtemplate_achievements` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_action` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_index` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_inventory` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_quests` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_reputations` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_skills` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_spells` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);
DELETE FROM `mod_ptrtemplate_locale` WHERE `ID` IN (@tcmelee, @tcspell, @tctank, @tchealer);

INSERT INTO `mod_ptrtemplate_index` (`ID`, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, `Enable`, `Comment`)
SELECT @tcmelee, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, 1, 'Temucraft Level 80 - Tier 7 Melee and Ranged' FROM `mod_ptrtemplate_index` WHERE `ID` = @base;
INSERT INTO `mod_ptrtemplate_index` (`ID`, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, `Enable`, `Comment`)
SELECT @tcspell, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, 1, 'Temucraft Level 80 - Tier 7 Spell Damage' FROM `mod_ptrtemplate_index` WHERE `ID` = @base;
INSERT INTO `mod_ptrtemplate_index` (`ID`, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, `Enable`, `Comment`)
SELECT @tctank, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, 1, 'Temucraft Level 80 - Tier 7 Tank' FROM `mod_ptrtemplate_index` WHERE `ID` = @base;
INSERT INTO `mod_ptrtemplate_index` (`ID`, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, `Enable`, `Comment`)
SELECT @tchealer, `Keywords`, `Level`, `MapAlliance`, `XAlliance`, `YAlliance`, `ZAlliance`, `OAlliance`, `MapHorde`, `XHorde`, `YHorde`, `ZHorde`, `OHorde`, `HMapAlliance`, `HZoneAlliance`, `HXAlliance`, `HYAlliance`, `HZAlliance`, `HOAlliance`, `HMapHorde`, `HZoneHorde`, `HXHorde`, `HYHorde`, `HZHorde`, `HOHorde`, `TaxiAlliance`, `TaxiHorde`, 1, 'Temucraft Level 80 - Tier 7 Healer' FROM `mod_ptrtemplate_index` WHERE `ID` = @base;

-- Temucraft Level 80 - Tier 7 Melee and Ranged
INSERT INTO `mod_ptrtemplate_achievements` (`ID`, `RaceMask`, `ClassMask`, `AchievementID`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `AchievementID`, `Comment` FROM `mod_ptrtemplate_achievements` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_action` (`ID`, `RaceMask`, `ClassMask`, `Button`, `Action`, `Type`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `Button`, `Action`, `Type`, `Comment` FROM `mod_ptrtemplate_action` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_quests` (`ID`, `RaceMask`, `ClassMask`, `QuestID`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `QuestID`, `Comment` FROM `mod_ptrtemplate_quests` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_reputations` (`ID`, `RaceMask`, `ClassMask`, `FactionID`, `Standing`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `FactionID`, `Standing`, `Comment` FROM `mod_ptrtemplate_reputations` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_skills` (`ID`, `RaceMask`, `ClassMask`, `SkillID`, `Value`, `Max`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `SkillID`, `Value`, `Max`, `Comment` FROM `mod_ptrtemplate_skills` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_spells` (`ID`, `RaceMask`, `ClassMask`, `SpellID`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `SpellID`, `Comment` FROM `mod_ptrtemplate_spells` WHERE `ID` = @base AND `ClassMask` & 1135;
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment`) SELECT @tcmelee, `RaceMask`, `ClassMask` & 1135, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment` FROM `mod_ptrtemplate_inventory` WHERE `ID` = @base AND `ClassMask` & 1135
    AND NOT (`BagID` = 0 AND `SlotID` IN (0, 2, 4, 6, 9));   -- the tier slots come below
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Comment`) VALUES
(@tcmelee, @allraces, 1, 0, 0, 39605, 1, 'Heroes\' Dreadnaught Helmet'),   -- Warrior, Heroes' Dreadnaught Battlegear
(@tcmelee, @allraces, 1, 0, 2, 39608, 1, 'Heroes\' Dreadnaught Shoulderplates'),   -- Warrior, Heroes' Dreadnaught Battlegear
(@tcmelee, @allraces, 1, 0, 4, 39606, 1, 'Heroes\' Dreadnaught Battleplate'),   -- Warrior, Heroes' Dreadnaught Battlegear
(@tcmelee, @allraces, 1, 0, 6, 39607, 1, 'Heroes\' Dreadnaught Legplates'),   -- Warrior, Heroes' Dreadnaught Battlegear
(@tcmelee, @allraces, 1, 0, 9, 39609, 1, 'Heroes\' Dreadnaught Gauntlets'),   -- Warrior, Heroes' Dreadnaught Battlegear
(@tcmelee, @allraces, 2, 0, 0, 39635, 1, 'Heroes\' Redemption Helm'),   -- Paladin, Heroes' Redemption Battlegear
(@tcmelee, @allraces, 2, 0, 2, 39637, 1, 'Heroes\' Redemption Shoulderplates'),   -- Paladin, Heroes' Redemption Battlegear
(@tcmelee, @allraces, 2, 0, 4, 39633, 1, 'Heroes\' Redemption Chestpiece'),   -- Paladin, Heroes' Redemption Battlegear
(@tcmelee, @allraces, 2, 0, 6, 39636, 1, 'Heroes\' Redemption Legplates'),   -- Paladin, Heroes' Redemption Battlegear
(@tcmelee, @allraces, 2, 0, 9, 39634, 1, 'Heroes\' Redemption Gauntlets'),   -- Paladin, Heroes' Redemption Battlegear
(@tcmelee, @allraces, 4, 0, 0, 39578, 1, 'Heroes\' Cryptstalker Headpiece'),   -- Hunter, Heroes' Cryptstalker Battlegear
(@tcmelee, @allraces, 4, 0, 2, 39581, 1, 'Heroes\' Cryptstalker Spaulders'),   -- Hunter, Heroes' Cryptstalker Battlegear
(@tcmelee, @allraces, 4, 0, 4, 39579, 1, 'Heroes\' Cryptstalker Tunic'),   -- Hunter, Heroes' Cryptstalker Battlegear
(@tcmelee, @allraces, 4, 0, 6, 39580, 1, 'Heroes\' Cryptstalker Legguards'),   -- Hunter, Heroes' Cryptstalker Battlegear
(@tcmelee, @allraces, 4, 0, 9, 39582, 1, 'Heroes\' Cryptstalker Handguards'),   -- Hunter, Heroes' Cryptstalker Battlegear
(@tcmelee, @allraces, 8, 0, 0, 39561, 1, 'Heroes\' Bonescythe Helmet'),   -- Rogue, Heroes' Bonescythe Battlegear
(@tcmelee, @allraces, 8, 0, 2, 39565, 1, 'Heroes\' Bonescythe Pauldrons'),   -- Rogue, Heroes' Bonescythe Battlegear
(@tcmelee, @allraces, 8, 0, 4, 39558, 1, 'Heroes\' Bonescythe Breastplate'),   -- Rogue, Heroes' Bonescythe Battlegear
(@tcmelee, @allraces, 8, 0, 6, 39564, 1, 'Heroes\' Bonescythe Legplates'),   -- Rogue, Heroes' Bonescythe Battlegear
(@tcmelee, @allraces, 8, 0, 9, 39560, 1, 'Heroes\' Bonescythe Gauntlets'),   -- Rogue, Heroes' Bonescythe Battlegear
(@tcmelee, @allraces, 32, 0, 0, 39619, 1, 'Heroes\' Scourgeborne Helmet'),   -- Death Knight, Heroes' Scourgeborne Battlegear
(@tcmelee, @allraces, 32, 0, 2, 39621, 1, 'Heroes\' Scourgeborne Shoulderplates'),   -- Death Knight, Heroes' Scourgeborne Battlegear
(@tcmelee, @allraces, 32, 0, 4, 39617, 1, 'Heroes\' Scourgeborne Battleplate'),   -- Death Knight, Heroes' Scourgeborne Battlegear
(@tcmelee, @allraces, 32, 0, 6, 39620, 1, 'Heroes\' Scourgeborne Legplates'),   -- Death Knight, Heroes' Scourgeborne Battlegear
(@tcmelee, @allraces, 32, 0, 9, 39618, 1, 'Heroes\' Scourgeborne Gauntlets'),   -- Death Knight, Heroes' Scourgeborne Battlegear
(@tcmelee, @allraces, 64, 0, 0, 39602, 1, 'Heroes\' Earthshatter Faceguard'),   -- Shaman, Heroes' Earthshatter Battlegear
(@tcmelee, @allraces, 64, 0, 2, 39604, 1, 'Heroes\' Earthshatter Shoulderguards'),   -- Shaman, Heroes' Earthshatter Battlegear
(@tcmelee, @allraces, 64, 0, 4, 39597, 1, 'Heroes\' Earthshatter Chestguard'),   -- Shaman, Heroes' Earthshatter Battlegear
(@tcmelee, @allraces, 64, 0, 6, 39603, 1, 'Heroes\' Earthshatter War-Kilt'),   -- Shaman, Heroes' Earthshatter Battlegear
(@tcmelee, @allraces, 64, 0, 9, 39601, 1, 'Heroes\' Earthshatter Grips'),   -- Shaman, Heroes' Earthshatter Battlegear
(@tcmelee, @allraces, 1024, 0, 0, 39553, 1, 'Heroes\' Dreamwalker Headguard'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tcmelee, @allraces, 1024, 0, 2, 39556, 1, 'Heroes\' Dreamwalker Shoulderpads'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tcmelee, @allraces, 1024, 0, 4, 39554, 1, 'Heroes\' Dreamwalker Raiments'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tcmelee, @allraces, 1024, 0, 6, 39555, 1, 'Heroes\' Dreamwalker Legguards'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tcmelee, @allraces, 1024, 0, 9, 39557, 1, 'Heroes\' Dreamwalker Handgrips');   -- Druid, Heroes' Dreamwalker Battlegear

-- Temucraft Level 80 - Tier 7 Spell Damage
INSERT INTO `mod_ptrtemplate_achievements` (`ID`, `RaceMask`, `ClassMask`, `AchievementID`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `AchievementID`, `Comment` FROM `mod_ptrtemplate_achievements` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_action` (`ID`, `RaceMask`, `ClassMask`, `Button`, `Action`, `Type`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `Button`, `Action`, `Type`, `Comment` FROM `mod_ptrtemplate_action` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_quests` (`ID`, `RaceMask`, `ClassMask`, `QuestID`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `QuestID`, `Comment` FROM `mod_ptrtemplate_quests` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_reputations` (`ID`, `RaceMask`, `ClassMask`, `FactionID`, `Standing`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `FactionID`, `Standing`, `Comment` FROM `mod_ptrtemplate_reputations` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_skills` (`ID`, `RaceMask`, `ClassMask`, `SkillID`, `Value`, `Max`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `SkillID`, `Value`, `Max`, `Comment` FROM `mod_ptrtemplate_skills` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_spells` (`ID`, `RaceMask`, `ClassMask`, `SpellID`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `SpellID`, `Comment` FROM `mod_ptrtemplate_spells` WHERE `ID` = @base AND `ClassMask` & 1488;
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment`) SELECT @tcspell, `RaceMask`, `ClassMask` & 1488, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment` FROM `mod_ptrtemplate_inventory` WHERE `ID` = @base AND `ClassMask` & 1488
    AND NOT (`BagID` = 0 AND `SlotID` IN (0, 2, 4, 6, 9));   -- the tier slots come below
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Comment`) VALUES
(@tcspell, @allraces, 16, 0, 0, 39521, 1, 'Heroes\' Circlet of Faith'),   -- Priest, Heroes' Garb of Faith
(@tcspell, @allraces, 16, 0, 2, 39529, 1, 'Heroes\' Mantle of Faith'),   -- Priest, Heroes' Garb of Faith
(@tcspell, @allraces, 16, 0, 4, 39523, 1, 'Heroes\' Raiments of Faith'),   -- Priest, Heroes' Garb of Faith
(@tcspell, @allraces, 16, 0, 6, 39528, 1, 'Heroes\' Pants of Faith'),   -- Priest, Heroes' Garb of Faith
(@tcspell, @allraces, 16, 0, 9, 39530, 1, 'Heroes\' Handwraps of Faith'),   -- Priest, Heroes' Garb of Faith
(@tcspell, @allraces, 64, 0, 0, 39594, 1, 'Heroes\' Earthshatter Helm'),   -- Shaman, Heroes' Earthshatter Garb
(@tcspell, @allraces, 64, 0, 2, 39596, 1, 'Heroes\' Earthshatter Shoulderpads'),   -- Shaman, Heroes' Earthshatter Garb
(@tcspell, @allraces, 64, 0, 4, 39592, 1, 'Heroes\' Earthshatter Hauberk'),   -- Shaman, Heroes' Earthshatter Garb
(@tcspell, @allraces, 64, 0, 6, 39595, 1, 'Heroes\' Earthshatter Kilt'),   -- Shaman, Heroes' Earthshatter Garb
(@tcspell, @allraces, 64, 0, 9, 39593, 1, 'Heroes\' Earthshatter Gloves'),   -- Shaman, Heroes' Earthshatter Garb
(@tcspell, @allraces, 128, 0, 0, 39491, 1, 'Heroes\' Frostfire Circlet'),   -- Mage, Heroes' Frostfire Garb
(@tcspell, @allraces, 128, 0, 2, 39494, 1, 'Heroes\' Frostfire Shoulderpads'),   -- Mage, Heroes' Frostfire Garb
(@tcspell, @allraces, 128, 0, 4, 39492, 1, 'Heroes\' Frostfire Robe'),   -- Mage, Heroes' Frostfire Garb
(@tcspell, @allraces, 128, 0, 6, 39493, 1, 'Heroes\' Frostfire Leggings'),   -- Mage, Heroes' Frostfire Garb
(@tcspell, @allraces, 128, 0, 9, 39495, 1, 'Heroes\' Frostfire Gloves'),   -- Mage, Heroes' Frostfire Garb
(@tcspell, @allraces, 256, 0, 0, 39496, 1, 'Heroes\' Plagueheart Circlet'),   -- Warlock, Heroes' Plagueheart Garb
(@tcspell, @allraces, 256, 0, 2, 39499, 1, 'Heroes\' Plagueheart Shoulderpads'),   -- Warlock, Heroes' Plagueheart Garb
(@tcspell, @allraces, 256, 0, 4, 39497, 1, 'Heroes\' Plagueheart Robe'),   -- Warlock, Heroes' Plagueheart Garb
(@tcspell, @allraces, 256, 0, 6, 39498, 1, 'Heroes\' Plagueheart Leggings'),   -- Warlock, Heroes' Plagueheart Garb
(@tcspell, @allraces, 256, 0, 9, 39500, 1, 'Heroes\' Plagueheart Gloves'),   -- Warlock, Heroes' Plagueheart Garb
(@tcspell, @allraces, 1024, 0, 0, 39545, 1, 'Heroes\' Dreamwalker Cover'),   -- Druid, Heroes' Dreamwalker Garb
(@tcspell, @allraces, 1024, 0, 2, 39548, 1, 'Heroes\' Dreamwalker Mantle'),   -- Druid, Heroes' Dreamwalker Garb
(@tcspell, @allraces, 1024, 0, 4, 39547, 1, 'Heroes\' Dreamwalker Vestments'),   -- Druid, Heroes' Dreamwalker Garb
(@tcspell, @allraces, 1024, 0, 6, 39546, 1, 'Heroes\' Dreamwalker Trousers'),   -- Druid, Heroes' Dreamwalker Garb
(@tcspell, @allraces, 1024, 0, 9, 39544, 1, 'Heroes\' Dreamwalker Gloves');   -- Druid, Heroes' Dreamwalker Garb

-- Temucraft Level 80 - Tier 7 Tank
INSERT INTO `mod_ptrtemplate_achievements` (`ID`, `RaceMask`, `ClassMask`, `AchievementID`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `AchievementID`, `Comment` FROM `mod_ptrtemplate_achievements` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_action` (`ID`, `RaceMask`, `ClassMask`, `Button`, `Action`, `Type`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `Button`, `Action`, `Type`, `Comment` FROM `mod_ptrtemplate_action` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_quests` (`ID`, `RaceMask`, `ClassMask`, `QuestID`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `QuestID`, `Comment` FROM `mod_ptrtemplate_quests` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_reputations` (`ID`, `RaceMask`, `ClassMask`, `FactionID`, `Standing`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `FactionID`, `Standing`, `Comment` FROM `mod_ptrtemplate_reputations` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_skills` (`ID`, `RaceMask`, `ClassMask`, `SkillID`, `Value`, `Max`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `SkillID`, `Value`, `Max`, `Comment` FROM `mod_ptrtemplate_skills` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_spells` (`ID`, `RaceMask`, `ClassMask`, `SpellID`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `SpellID`, `Comment` FROM `mod_ptrtemplate_spells` WHERE `ID` = @base AND `ClassMask` & 1059;
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment`) SELECT @tctank, `RaceMask`, `ClassMask` & 1059, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment` FROM `mod_ptrtemplate_inventory` WHERE `ID` = @base AND `ClassMask` & 1059
    AND NOT (`BagID` = 0 AND `SlotID` IN (0, 2, 4, 6, 9));   -- the tier slots come below
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Comment`) VALUES
(@tctank, @allraces, 1, 0, 0, 39610, 1, 'Heroes\' Dreadnaught Greathelm'),   -- Warrior, Heroes' Dreadnaught Plate
(@tctank, @allraces, 1, 0, 2, 39613, 1, 'Heroes\' Dreadnaught Pauldrons'),   -- Warrior, Heroes' Dreadnaught Plate
(@tctank, @allraces, 1, 0, 4, 39611, 1, 'Heroes\' Dreadnaught Breastplate'),   -- Warrior, Heroes' Dreadnaught Plate
(@tctank, @allraces, 1, 0, 6, 39612, 1, 'Heroes\' Dreadnaught Legguards'),   -- Warrior, Heroes' Dreadnaught Plate
(@tctank, @allraces, 1, 0, 9, 39622, 1, 'Heroes\' Dreadnaught Handguards'),   -- Warrior, Heroes' Dreadnaught Plate
(@tctank, @allraces, 2, 0, 0, 39640, 1, 'Heroes\' Redemption Faceguard'),   -- Paladin, Heroes' Redemption Plate
(@tctank, @allraces, 2, 0, 2, 39642, 1, 'Heroes\' Redemption Shoulderguards'),   -- Paladin, Heroes' Redemption Plate
(@tctank, @allraces, 2, 0, 4, 39638, 1, 'Heroes\' Redemption Breastplate'),   -- Paladin, Heroes' Redemption Plate
(@tctank, @allraces, 2, 0, 6, 39641, 1, 'Heroes\' Redemption Legguards'),   -- Paladin, Heroes' Redemption Plate
(@tctank, @allraces, 2, 0, 9, 39639, 1, 'Heroes\' Redemption Handguards'),   -- Paladin, Heroes' Redemption Plate
(@tctank, @allraces, 32, 0, 0, 39625, 1, 'Heroes\' Scourgeborne Faceguard'),   -- Death Knight, Heroes' Scourgeborne Plate
(@tctank, @allraces, 32, 0, 2, 39627, 1, 'Heroes\' Scourgeborne Pauldrons'),   -- Death Knight, Heroes' Scourgeborne Plate
(@tctank, @allraces, 32, 0, 4, 39623, 1, 'Heroes\' Scourgeborne Chestguard'),   -- Death Knight, Heroes' Scourgeborne Plate
(@tctank, @allraces, 32, 0, 6, 39626, 1, 'Heroes\' Scourgeborne Legguards'),   -- Death Knight, Heroes' Scourgeborne Plate
(@tctank, @allraces, 32, 0, 9, 39624, 1, 'Heroes\' Scourgeborne Handguards'),   -- Death Knight, Heroes' Scourgeborne Plate
(@tctank, @allraces, 1024, 0, 0, 39553, 1, 'Heroes\' Dreamwalker Headguard'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tctank, @allraces, 1024, 0, 2, 39556, 1, 'Heroes\' Dreamwalker Shoulderpads'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tctank, @allraces, 1024, 0, 4, 39554, 1, 'Heroes\' Dreamwalker Raiments'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tctank, @allraces, 1024, 0, 6, 39555, 1, 'Heroes\' Dreamwalker Legguards'),   -- Druid, Heroes' Dreamwalker Battlegear
(@tctank, @allraces, 1024, 0, 9, 39557, 1, 'Heroes\' Dreamwalker Handgrips');   -- Druid, Heroes' Dreamwalker Battlegear

-- Temucraft Level 80 - Tier 7 Healer
INSERT INTO `mod_ptrtemplate_achievements` (`ID`, `RaceMask`, `ClassMask`, `AchievementID`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `AchievementID`, `Comment` FROM `mod_ptrtemplate_achievements` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_action` (`ID`, `RaceMask`, `ClassMask`, `Button`, `Action`, `Type`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `Button`, `Action`, `Type`, `Comment` FROM `mod_ptrtemplate_action` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_quests` (`ID`, `RaceMask`, `ClassMask`, `QuestID`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `QuestID`, `Comment` FROM `mod_ptrtemplate_quests` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_reputations` (`ID`, `RaceMask`, `ClassMask`, `FactionID`, `Standing`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `FactionID`, `Standing`, `Comment` FROM `mod_ptrtemplate_reputations` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_skills` (`ID`, `RaceMask`, `ClassMask`, `SkillID`, `Value`, `Max`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `SkillID`, `Value`, `Max`, `Comment` FROM `mod_ptrtemplate_skills` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_spells` (`ID`, `RaceMask`, `ClassMask`, `SpellID`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `SpellID`, `Comment` FROM `mod_ptrtemplate_spells` WHERE `ID` = @base AND `ClassMask` & 1106;
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment`) SELECT @tchealer, `RaceMask`, `ClassMask` & 1106, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Enchant0`, `Enchant1`, `Enchant2`, `Enchant3`, `Enchant4`, `Enchant5`, `Enchant6`, `Comment` FROM `mod_ptrtemplate_inventory` WHERE `ID` = @base AND `ClassMask` & 1106
    AND NOT (`BagID` = 0 AND `SlotID` IN (0, 2, 4, 6, 9));   -- the tier slots come below
INSERT INTO `mod_ptrtemplate_inventory` (`ID`, `RaceMask`, `ClassMask`, `BagID`, `SlotID`, `ItemID`, `Quantity`, `Comment`) VALUES
(@tchealer, @allraces, 2, 0, 0, 39628, 1, 'Heroes\' Redemption Headpiece'),   -- Paladin, Heroes' Redemption Regalia
(@tchealer, @allraces, 2, 0, 2, 39631, 1, 'Heroes\' Redemption Spaulders'),   -- Paladin, Heroes' Redemption Regalia
(@tchealer, @allraces, 2, 0, 4, 39629, 1, 'Heroes\' Redemption Tunic'),   -- Paladin, Heroes' Redemption Regalia
(@tchealer, @allraces, 2, 0, 6, 39630, 1, 'Heroes\' Redemption Greaves'),   -- Paladin, Heroes' Redemption Regalia
(@tchealer, @allraces, 2, 0, 9, 39632, 1, 'Heroes\' Redemption Gloves'),   -- Paladin, Heroes' Redemption Regalia
(@tchealer, @allraces, 16, 0, 0, 39514, 1, 'Heroes\' Crown of Faith'),   -- Priest, Heroes' Regalia of Faith
(@tchealer, @allraces, 16, 0, 2, 39518, 1, 'Heroes\' Shoulderpads of Faith'),   -- Priest, Heroes' Regalia of Faith
(@tchealer, @allraces, 16, 0, 4, 39515, 1, 'Heroes\' Robe of Faith'),   -- Priest, Heroes' Regalia of Faith
(@tchealer, @allraces, 16, 0, 6, 39517, 1, 'Heroes\' Leggings of Faith'),   -- Priest, Heroes' Regalia of Faith
(@tchealer, @allraces, 16, 0, 9, 39519, 1, 'Heroes\' Gloves of Faith'),   -- Priest, Heroes' Regalia of Faith
(@tchealer, @allraces, 64, 0, 0, 39583, 1, 'Heroes\' Earthshatter Headpiece'),   -- Shaman, Heroes' Earthshatter Regalia
(@tchealer, @allraces, 64, 0, 2, 39590, 1, 'Heroes\' Earthshatter Spaulders'),   -- Shaman, Heroes' Earthshatter Regalia
(@tchealer, @allraces, 64, 0, 4, 39588, 1, 'Heroes\' Earthshatter Tunic'),   -- Shaman, Heroes' Earthshatter Regalia
(@tchealer, @allraces, 64, 0, 6, 39589, 1, 'Heroes\' Earthshatter Legguards'),   -- Shaman, Heroes' Earthshatter Regalia
(@tchealer, @allraces, 64, 0, 9, 39591, 1, 'Heroes\' Earthshatter Handguards'),   -- Shaman, Heroes' Earthshatter Regalia
(@tchealer, @allraces, 1024, 0, 0, 39531, 1, 'Heroes\' Dreamwalker Headpiece'),   -- Druid, Heroes' Dreamwalker Regalia
(@tchealer, @allraces, 1024, 0, 2, 39542, 1, 'Heroes\' Dreamwalker Spaulders'),   -- Druid, Heroes' Dreamwalker Regalia
(@tchealer, @allraces, 1024, 0, 4, 39538, 1, 'Heroes\' Dreamwalker Robe'),   -- Druid, Heroes' Dreamwalker Regalia
(@tchealer, @allraces, 1024, 0, 6, 39539, 1, 'Heroes\' Dreamwalker Leggings'),   -- Druid, Heroes' Dreamwalker Regalia
(@tchealer, @allraces, 1024, 0, 9, 39543, 1, 'Heroes\' Dreamwalker Handguards');   -- Druid, Heroes' Dreamwalker Regalia


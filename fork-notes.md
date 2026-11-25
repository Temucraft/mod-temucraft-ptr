# Temucraft/mod-ptr-template: what to change in the fork

Upstream: <https://github.com/azerothcore/mod-ptr-template> (heyitsbench, AGPL-3.0; read at commit `ad30515`,
"Remove PlayerScript reliance from `createTemplate`"). The fork stays AGPL-3.0; keep the LICENSE and the credits.
mod-temucraft-ptr does not copy any of its code: it only runs its `.template apply` command (see the end).

The files under `fork/` in this repository are ready to copy into the fork:

| From this repo | To the fork |
|---|---|
| `fork/data/sql/db-auth/ptr_template_rbac.sql` | `data/sql/db-auth/ptr_template_rbac.sql` (new) |
| `fork/data/sql/db-world/ptr-template_command.sql` | `data/sql/db-world/ptr-template_command.sql` (replaces it) |
| `fork/data/sql/db-world/ptr_template_set_temucraft.sql` | `data/sql/db-world/ptr_template_set_temucraft.sql` (new) |

## 1. RBAC permissions instead of security levels

Upstream gives its commands `SEC_PLAYER` / `SEC_ADMINISTRATOR` and checks `GetSecurity()` against five config
options. On Temucraft a command's number of 200 or more is an RBAC permission (`ChatCommand.cpp`), so:

- `src/ptr_template_loader.h`, add:

  ```cpp
  enum PtrTemplatePermissions : uint32
  {
      RBAC_PTR_TEMPLATE_ENABLE   = 104101, // .template enable
      RBAC_PTR_TEMPLATE_DISABLE  = 104102, // .template disable
      RBAC_PTR_TEMPLATE_DISABLED = 104103, // see, and apply, disabled templates
      RBAC_PTR_TEMPLATE_APPLY    = 104150, // .template apply
      RBAC_PTR_TEMPLATE_LIST     = 104151  // .template list
  };
  ```

- `ptr_template_commandscript::GetCommands()`: `SEC_PLAYER` becomes `RBAC_PTR_TEMPLATE_APPLY` (apply) and
  `RBAC_PTR_TEMPLATE_LIST` (list); `SEC_ADMINISTRATOR` becomes `RBAC_PTR_TEMPLATE_ENABLE` / `RBAC_PTR_TEMPLATE_DISABLE`.
- `createTemplate::CheckTemplateQualifier`: drop the two `GetSecurity()` checks. The one for disabled templates
  becomes `if (!enable && !player->GetSession()->HasPermission(RBAC_PTR_TEMPLATE_DISABLED)) return TEMPLATE_DISABLED_LOCAL;`
  (the apply permission itself is already checked by the command system; `INSUFFICIENT_SECURITY_LEVEL` is then unused).
- `listTemplate`: instead of comparing `playerSecurity` with `EnableListSecurity` / `DisableListSecurity` /
  `StatusSecurityText`, show a disabled template and the Enabled/Disabled word only when
  `handler->IsConsole() || handler->GetSession()->HasPermission(RBAC_PTR_TEMPLATE_DISABLED)`.
- `conf/mod_ptr_template.conf.dist`: remove `EnableApplySecurity`, `DisableApplySecurity`, `EnableListSecurity`,
  `DisableListSecurity`, `StatusSecurityText`; write in their place that the permissions are 104101-104151
  (`.rbac account grant/deny`).
- SQL: add `ptr_template_rbac.sql` (auth database) and replace `ptr-template_command.sql` with the copy here. That one
  only **deletes** the `command` rows: on Temucraft a `command` row overrides the code's permission, and its
  `security` column (SMALLINT, read as uint16) can't hold ids above 65535, so the fork must not keep rows there.

## 2. Only on the PTR realm

The module must do nothing on Live, even if it is built into the same worldserver binary.

- New config keys, default off:

  ```
  #    PtrTemplate.Enable
  #        Description: Templates can be listed and applied on this worldserver. Turn it on on the PTR only.
  #        Default:     0
  PtrTemplate.Enable = 0

  #    PtrTemplate.RealmId
  #        Description: When not 0, templates also need this realmlist id (a second guard against Live).
  #        Default:     0
  PtrTemplate.RealmId = 0
  ```

- `ptr_template_loader.h`:

  ```cpp
  #include "World.h"   // realm

  inline bool PtrTemplateRealmAllowed()
  {
      if (!sConfigMgr->GetOption<bool>("PtrTemplate.Enable", false))
          return false;
      uint32 only = sConfigMgr->GetOption<uint32>("PtrTemplate.RealmId", 0);
      return !only || only == realm.Id.Realm;
  }
  ```

  Include `Realm.h` too if `realm` is an incomplete type there (mod-temucraft-ptr needed it).
- Call it first in `applyTemplate`, `listTemplate`, `enableTemplate`, `disableTemplate` (send
  `ERROR_TEMPLATE_DIABLE_GLOBAL` and return true) and at the top of `announce::OnPlayerLogin` (no announce, no
  `LoginTemplateIndex`). `CheckTemplateQualifier` returns `TEMPLATE_DISABLED_GLOBAL` when it is false.

## 3. Prefix the config keys

Upstream reads unprefixed keys (`DeleteItems`, `TemplateEnable`, `LevelEnable`, `TemplateLevel`, ...). Every module's
`.conf` ends up in one config space, so rename them all to `PtrTemplate.<old name>` (for example
`PtrTemplate.DeleteItems`) in the `.conf.dist` and in every `sConfigMgr->GetOption` call. Also: the
`GetOption<int8>(..., true)` calls pass `true` as the default; with the security options gone they disappear anyway.

## 4. Two crash fixes worth taking

- `applyTemplate`: `player->GetConnectedPlayer()` is null when the named character is offline, and
  `CheckTemplateQualifier(target, ...)` then dereferences it. Return an error when `!target`. A bare number is also
  read as a character guid by `Optional<PlayerIdentifier>`, so `.template apply 80` can pick the character with guid 80;
  mod-temucraft-ptr always sends `.template apply <name> <index>` for that reason.
- `createTemplate::HandleApply` schedules about 15 steps 50 ms apart with a raw `Player*` in the lambda. If the player
  logs out in between, the next step uses a freed pointer. Capture `player->GetGUID()` and re-find it in each step
  (`ObjectAccessor::FindConnectedPlayer(guid)`), `return` (no `Repeat`) when it is gone.

## 5. Temucraft level-80 template sets

`fork/data/sql/db-world/ptr_template_set_temucraft.sql`, in the fork's own format (`mod_ptrtemplate_*` tables):

| ID | Name | Classes and tier 7 set (10-man, item level 200) |
|---|---|---|
| 80 | Temucraft Level 80 - Tier 7 Melee and Ranged | Warrior Dreadnaught Battlegear, Paladin Redemption Battlegear, Hunter Cryptstalker, Rogue Bonescythe, Death Knight Scourgeborne Battlegear, Shaman Earthshatter Battlegear, Druid Dreamwalker Battlegear |
| 81 | Temucraft Level 80 - Tier 7 Spell Damage | Priest Garb of Faith, Shaman Earthshatter Garb, Mage Frostfire, Warlock Plagueheart, Druid Dreamwalker Garb |
| 82 | Temucraft Level 80 - Tier 7 Tank | Warrior Dreadnaught Plate, Paladin Redemption Plate, Death Knight Scourgeborne Plate, Druid Dreamwalker Battlegear |
| 83 | Temucraft Level 80 - Tier 7 Healer | Paladin Redemption Regalia, Priest Regalia of Faith, Shaman Earthshatter Regalia, Druid Dreamwalker Regalia |

All ten classes are covered. Each template gets head, shoulders, chest, legs and hands from its tier set (100 rows, every
item id checked against the stock `item_template`: the `Heroes'` 39xxx pieces of item sets 787-805, item level 200,
class-restricted to that class; the 43xxx duplicates in the same sets were left out). Everything else (level 80,
Dalaran position and hearthstone, flight paths, spells, skills, reputations, achievements, action bars, the other gear
slots and bags) is copied from the fork's own template 3, "Wrath Classic Level 80", so that file must be applied first
(it already is: it is in the fork's automatic `db-world` folder).

**TODO (marked in the file):** template 3 has a single choice of neck, back, wrists, waist, feet, rings, trinkets
and weapons per class, so the tank and healer templates get that class's template 3 off-pieces and weapons (and the
melee druid gets the template 3 druid's). Replace those rows per role once someone has verified ids. The set-to-spec
names (Battlegear/Plate/Garb/Regalia) follow the item set names; the druid ones were checked on warcraft.wiki.gg,
the shaman Garb (item set 796) on Wowhead, the rest are from the piece names and should get a quick look in game.

## 6. How mod-temucraft-ptr uses the fork

- The PTR Quartermaster's "Level-80 templates" menu lists `mod_ptrtemplate_index` rows with `Enable = 1` and, on
  choice, runs `Temucraft.PTR.Templates.ApplyCommand` (default `.template apply {name} {index}`) as the player,
  through `ChatHandler::ParseCommands`. The player needs permission 104150 (linked to the player roles above).
- A `template` request in `mod_temucraft_ptr_copy` (from a launcher) is applied the same way at the named PTR
  character's next login.
- Why a command and not a function call: the fork's apply code (`createTemplate::HandleApply`) is a class inside
  `src/ptr_template.cpp`, with no header, and its `ptr_template_loader.h` defines globals (`TaskScheduler scheduler`,
  `SendTalentReset`), so another module can't include it. If the fork ever wants a direct call, add a small header
  `src/PtrTemplateApi.h` with `void PtrTemplateApply(Player* player, uint32 index);` defined in `ptr_template.cpp`
  (running `CheckTemplateQualifier` and `HandleApply`); mod-temucraft-ptr could then call it, but it would no longer
  build without the fork, so the command stays the default.
- Set `AnnounceEnable = false` (or `PtrTemplate.AnnounceEnable` after the rename) if one PTR login message is enough:
  mod-temucraft-ptr already says "You are on the PTR: progress here never goes back to Live."

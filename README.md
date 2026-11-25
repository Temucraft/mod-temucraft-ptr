# mod-temucraft-ptr

The PTR (public test realm) for Temucraft: players copy a Live character to the PTR when they choose to, or start
from a level-80 template, and get free supplies there. Nothing ever goes back from the PTR to Live.

Everything is off until its config key is on (`conf/mod-temucraft-ptr.conf.dist`).

## What players get

- **Copy a Live character:** `.ptr copy <name>` (on Live or on the PTR), or the PTR Quartermaster's
  "Copy a character from Live". Only characters of the same account can be copied. The copy keeps its name when it is
  free on the PTR; otherwise it gets a temporary name and asks for a new one at login. `.ptr copy <name> replace` (or
  "Copy and replace my earlier copy of it") deletes the account's previous PTR copy of that character first; without
  it, every copy is a new character. A copy needs a free character place on the PTR (`CharactersPerRealm`, and at most
  9 characters: the core's dump loader refuses an account with 10).
- **`.ptr copy list`** shows the account's Live characters, **`.ptr status`** the last five requests and how far
  they are.
- **PTR Quartermaster** (in front of the bankers of Stormwind and Orgrimmar, PTR only): free supplies for the class
  (food, potions, flasks, bags, class reagents, poisons, arrows and bullets), level-80 templates (with the fork below),
  copies and their status.
- **At login on the PTR:** "You are on the PTR: progress here never goes back to Live."

What a copy carries is the core's PlayerDump (`.pdump`): the character, its items, bags, bank, mail, pets, spells,
talents, quests, reputations, achievements and action bars. Per-character tables of other modules (Temucraft settings,
journals, followers and so on) and account-wide data are not part of it. Guild membership and group are not copied.

## Server setup

Live and PTR are two worldservers with their own characters and world databases and the **same auth database**
(`LoginDatabaseInfo`). Install this module on both (same build), and on the PTR also the Temucraft fork of
mod-ptr-template if templates are wanted.

**Live** `mod-temucraft-ptr.conf`:

```
Temucraft.PTR.CopyWriter = 1
Temucraft.PTR.DumpFolder = "/srv/temucraft/ptr-dumps"
Temucraft.PTR.RealmId = 0          # the PTR's realmlist id; 0 = any PTR (one PTR)
```

**PTR** `mod-temucraft-ptr.conf`:

```
Temucraft.PTR.Enable = 1
Temucraft.PTR.DumpFolder = "/srv/temucraft/ptr-dumps"
Temucraft.PTR.Templates.Enable = 1 # only with the mod-ptr-template fork
```

- **The dump folder** must be the same folder for both: one directory when both run on one machine (VPS), or a share
  both can read and write. The worldserver user needs write rights there on Live and read (and delete, for
  `DeleteDumps`) rights on the PTR. The files are `ptr-copy-<request id>.dump`; Live writes `.tmp` first and renames,
  so the PTR never reads half a file. Copies and template requests are off while the folder is empty in the config.
- The PTR has its own `realmlist` row (its own `RealmID` in its worldserver.conf) and its own characters database.
  The usual PTR settings (rates, `CharactersPerRealm`, `StartPlayerLevel` and so on) go in the PTR's worldserver.conf.
- Poll interval (`Temucraft.PTR.PollInterval`, default 10 s): how often each side looks at the request table. A copy
  usually takes one poll on Live and one on the PTR.
- Live saves an online character before writing its copy (and waits `SaveDelay`, 3 s, for the save).
- Nothing blocks the world thread for long: the polls are async queries; the dump is written and read on a helper
  thread; only the dump load itself (the same step as `.pdump load`) runs on the world thread.

### SQL

Applied by the worldserver's module updater at start (each file deletes its own rows first, so they can run again):

| Database | File | What |
|---|---|---|
| auth (shared) | `data/sql/db-auth/base/mod_temucraft_ptr_auth.sql` | `mod_temucraft_ptr_copy`, `mod_temucraft_ptr_live_chars` |
| auth (shared) | `data/sql/db-auth/base/mod_temucraft_ptr_rbac.sql` | permissions 104001, 104050-104052 |
| world | `data/sql/db-world/base/mod_temucraft_ptr_world.sql` | PTR Quartermaster 609300 (Alliance) / 609301 (Horde), npc_text 609300, `mod_temucraft_ptr_supplies` |
| world | `data/sql/db-world/base/mod_temucraft_ptr_module_string.sql` | the 26 player texts |

The world SQL is harmless on Live: the quartermasters have no `creature` rows. The PTR places them at start
(`ObjectMgr::AddCreData`), 10 yards in front of the stock banker Olivia Burnside (spawn 79684, Stormwind Counting
House) and 6 yards in front of Karus (spawn 6598, Orgrimmar bank), facing the same way. Check the spots in game; to
move them, change the numbers in `SpawnQuartermasters()` (`src/TemucraftPtr.cpp`).

### Permissions

| Id | Command | Linked to |
|---|---|---|
| 104050 | `.ptr copy <name> [replace]` | 195, 1010 (players) |
| 104051 | `.ptr copy list` | 195, 1010 |
| 104052 | `.ptr status` | 195, 1010 |
| 104001 | `.ptr requests` (open and failed requests of every account; console too) | 192, 1014 (admins) |

104001-104099 are this module's; 104101-104199 are for the mod-ptr-template fork (`fork/`). A name that is the
start of `list` ("Li", "Lis") is read as `.ptr copy list`; use the quartermaster for those.

## Request table contract (for the launcher)

`acore_auth.mod_temucraft_ptr_copy`, one row per request. A tool **inserts** a row and then only **reads** it:

| Column | Copy | Template |
|---|---|---|
| `account` | account.id (the copy goes to this account only; Live checks the character is on it) | account.id |
| `type` | `'copy'` | `'template'` |
| `live_realm` | realmlist id of the Live realm (from `mod_temucraft_ptr_live_chars.realm`; 0 = any Live realm, only with one) | 0 |
| `live_guid` | `mod_temucraft_ptr_live_chars.guid` | 0 |
| `live_name` | its name (display, default PTR name) | '' |
| `template_index` | 0 | `mod_ptrtemplate_index.ID` (80-83 for the Temucraft sets) |
| `ptr_realm` | realmlist id of the PTR, or 0 (any PTR) | same |
| `ptr_name` | wanted PTR name, '' = `live_name` | the existing PTR character to apply it to |
| `replace_old` | 1 = delete this account's earlier copy of the same Live character first | 0 |
| `state`, `message`, `ptr_guid`, `created`, `updated` | leave to the servers | |

States, in order:

- copy: `requested` (new row) -> `working` (Live writes the dump) -> `ready` (dump in the folder) -> `loading` (PTR
  loads it) -> `done` (`ptr_guid` and `ptr_realm` set) or `failed` at any step;
- template: `requested` -> `working` (waiting for that character's next login on the PTR, or applied at once when
  it is online) -> `done`, or `failed` (no such PTR character on the account, templates off).

`message` always holds the last progress or error text in plain English, fit to show to the player. An account can
have `MaxOpenRequests` (3) unfinished requests through the in-game commands; a launcher should keep to the same.
Finished rows are removed after `KeepDays` (30). The character list to offer is
`SELECT realm, realm_name, guid, name, race, class, level FROM mod_temucraft_ptr_live_chars WHERE account = ?`.

Notes: after a crash a Live row in `working` goes back to `requested`, a PTR row in `loading` back to `ready`. A PTR
that stops in the instant between loading a copy and marking it done can make one copy twice. With more than one
PTR, give each request its `ptr_realm` (0 would let both take it). Use the default single LoginDatabase worker thread
(`LoginDatabase.WorkerThreads = 1`) so the state updates run in order.

## Templates (mod-ptr-template fork)

Templates come from <https://github.com/azerothcore/mod-ptr-template> (AGPL-3.0, heyitsbench), forked as
**Temucraft/mod-ptr-template**. What to change in the fork, and the Temucraft level-80 sets to add to it, are in
[`fork-notes.md`](fork-notes.md); the SQL to copy is under `fork/`. In short:

- RBAC permissions (104101-104151) instead of security levels, no `command` rows;
- only on the PTR (`PtrTemplate.Enable`, optional `PtrTemplate.RealmId`), config keys prefixed `PtrTemplate.`;
- four Temucraft templates, 80-83 (tier 7 melee/ranged, spell damage, tank, healer, all ten classes), built on the
  fork's "Wrath Classic Level 80" template.

This module does not need the fork to build. With `Temucraft.PTR.Templates.Enable = 1` it lists the enabled
templates in the quartermaster's menu and runs `.template apply <name> <index>` for the player (the fork's apply code
lives inside its own `.cpp` and can't be called from another module); template requests are applied the same way.

Part of the Temucraft modules for AzerothCore 3.3.5a.

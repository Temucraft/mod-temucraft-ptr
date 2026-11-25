/*
 * mod-temucraft-ptr
 *
 * Copy a character from Live to the PTR, the player's choice. The Live and PTR worldservers share acore_auth:
 *
 *   mod_temucraft_ptr_copy        copy and template requests: from .ptr copy, the PTR Quartermaster or a launcher
 *   mod_temucraft_ptr_live_chars  every account's Live characters, kept fresh by the Live worldserver
 *
 * Live (Temucraft.PTR.CopyWriter = 1) takes 'requested' copies of its realm, checks that the character belongs to the
 * requesting account, writes a PlayerDump of it to Temucraft.PTR.DumpFolder and marks the request 'ready'. The PTR
 * (Temucraft.PTR.Enable = 1) takes 'ready' copies, loads the dump into the requesting account (its free name, or a
 * rename at login), replaces the earlier copy only when the request asks for it, and marks the request 'done'.
 * Template requests name a PTR character: its template (mod-ptr-template, Temucraft fork) is applied at its next login.
 *
 * Nothing here blocks the world thread for long: the request polls are async queries, the dump is written and read
 * on a helper thread (std::async), only the PlayerDumpReader step (which needs the guid generators) runs on the world
 * thread, like the stock .pdump load command.
 *
 *   .ptr copy <name> [replace]   ask for a copy of one of your Live characters
 *   .ptr copy list               your Live characters
 *   .ptr status                  your last requests
 *   .ptr requests                (admin) open and failed requests of every account
 *   npc_temucraft_ptr_quartermaster   PTR only: free supplies, templates, copies (Stormwind and Orgrimmar banks)
 */

#include "AccountMgr.h"
#include "AsyncCallbackProcessor.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerDump.h"
#include "PlayerScript.h"
#include "QueryCallback.h"
#include "Realm.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
#include "TemucraftModuleText.h"
#include "World.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <future>
#include <iterator>
#include <list>
#include <mutex>
#include <sstream>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

namespace TemucraftPtr
{
    constexpr char const* MODULE = "mod-temucraft-ptr";
    constexpr uint32 QUARTERMASTER_ALLIANCE = 609300;
    constexpr uint32 QUARTERMASTER_HORDE = 609301;
    constexpr uint32 QUARTERMASTER_TEXT = 609300;
    // stock banker spawns the quartermasters stand in front of (acore_world `creature`)
    constexpr ObjectGuid::LowType BANKER_STORMWIND = 79684;   // Olivia Burnside, Stormwind Counting House
    constexpr ObjectGuid::LowType BANKER_ORGRIMMAR = 6598;    // Karus, Orgrimmar bank
    constexpr uint32 MAX_CHARACTERS_IN_DUMP_READER = 10;      // PlayerDumpReader refuses an account with 10 characters

    struct Cfg
    {
        bool ptr = false;              // Temucraft.PTR.Enable: this worldserver is the PTR
        bool writer = false;           // Temucraft.PTR.CopyWriter: this worldserver is a Live realm that writes copies
        std::string folder;            // Temucraft.PTR.DumpFolder: shared by Live and PTR
        uint32 pollMs = 10000;         // Temucraft.PTR.PollInterval (seconds in the config)
        uint32 ptrRealm = 0;           // Temucraft.PTR.RealmId: on Live, the PTR realm that requests made there go to
        uint32 maxOpen = 3;            // Temucraft.PTR.MaxOpenRequests per account
        uint32 saveDelayMs = 3000;     // Temucraft.PTR.SaveDelay: wait after saving an online character before the dump
        uint32 keepDays = 30;          // Temucraft.PTR.KeepDays: finished requests are removed after this many days
        bool deleteDumps = true;       // Temucraft.PTR.DeleteDumps: remove the dump file once the PTR loaded it
        bool loginMessage = true;      // Temucraft.PTR.LoginMessage
        bool quartermaster = true;     // Temucraft.PTR.Quartermaster.Enable
        bool templates = false;        // Temucraft.PTR.Templates.Enable (needs the mod-ptr-template fork)
        std::string applyCommand = ".template apply {name} {index}";   // Temucraft.PTR.Templates.ApplyCommand
    } cfg;

    struct LiveChar { uint32 realm = 0; uint32 guid = 0; std::string name; uint8 level = 0; };
    struct Supply { uint32 item; uint32 count; uint32 classMask; };

    std::vector<Supply> sSupplies;
    std::string sRealmNameEsc;
    QueryCallbackProcessor sCallbacks;
    std::unordered_set<uint32> sSeen;            // request ids this server took up since its start (world thread)
    bool sLivePolling = false;
    bool sPtrPolling = false;
    uint32 sLiveTimer = 0;
    uint32 sPtrTimer = 0;

    std::mutex sPickLock;
    std::unordered_map<ObjectGuid::LowType, std::vector<LiveChar>> sPick;   // player -> Live characters the gossip shows

    char const* ClassName(uint8 cls)
    {
        static char const* const names[] = { "", "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "", "Druid" };
        return cls < std::size(names) ? names[cls] : "";
    }

    uint32 RealmId() { return realm.Id.Realm; }

    std::string Esc(std::string text)
    {
        LoginDatabase.EscapeString(text);
        return text;
    }

    std::string DumpPath(uint32 id)
    {
        return (std::filesystem::path(cfg.folder) / Acore::StringFormat("ptr-copy-{}.dump", id)).string();
    }

    void SetState(uint32 id, char const* state, std::string message, uint32 ptrGuid = 0)
    {
        if (message.size() > 250)
            message.resize(250);
        std::string extra = ptrGuid ? Acore::StringFormat(", `ptr_guid` = {}, `ptr_realm` = {}", ptrGuid, RealmId()) : std::string();
        LoginDatabase.Execute("UPDATE `mod_temucraft_ptr_copy` SET `state` = '{}', `message` = '{}'{} WHERE `id` = {}", state, Esc(message), extra, id);
    }

    void LoadConfig()
    {
        cfg.ptr = sConfigMgr->GetOption<bool>("Temucraft.PTR.Enable", false);
        cfg.writer = sConfigMgr->GetOption<bool>("Temucraft.PTR.CopyWriter", false);
        cfg.folder = sConfigMgr->GetOption<std::string>("Temucraft.PTR.DumpFolder", "");
        cfg.pollMs = std::max<uint32>(2, sConfigMgr->GetOption<uint32>("Temucraft.PTR.PollInterval", 10)) * IN_MILLISECONDS;
        cfg.ptrRealm = sConfigMgr->GetOption<uint32>("Temucraft.PTR.RealmId", 0);
        cfg.maxOpen = std::max<uint32>(1, sConfigMgr->GetOption<uint32>("Temucraft.PTR.MaxOpenRequests", 3));
        cfg.saveDelayMs = sConfigMgr->GetOption<uint32>("Temucraft.PTR.SaveDelay", 3) * IN_MILLISECONDS;
        cfg.keepDays = sConfigMgr->GetOption<uint32>("Temucraft.PTR.KeepDays", 30);
        cfg.deleteDumps = sConfigMgr->GetOption<bool>("Temucraft.PTR.DeleteDumps", true);
        cfg.loginMessage = sConfigMgr->GetOption<bool>("Temucraft.PTR.LoginMessage", true);
        cfg.quartermaster = sConfigMgr->GetOption<bool>("Temucraft.PTR.Quartermaster.Enable", true);
        cfg.templates = sConfigMgr->GetOption<bool>("Temucraft.PTR.Templates.Enable", false);
        cfg.applyCommand = sConfigMgr->GetOption<std::string>("Temucraft.PTR.Templates.ApplyCommand", ".template apply {name} {index}");

        // without a folder the copies are off; the PTR still has its quartermaster and login message
        if ((cfg.ptr || cfg.writer) && cfg.folder.empty())
            LOG_ERROR("module", "mod-temucraft-ptr: Temucraft.PTR.DumpFolder is empty: character copies and template requests are off.");
    }

    bool CopiesOn() { return !cfg.folder.empty() && (cfg.ptr || cfg.writer); }

    // ---------------------------------------------------------------- Live characters (Live worldserver)
    void UpsertLiveChar(Player* player)
    {
        if (!cfg.writer || !player || !player->GetSession())
            return;
        LoginDatabase.Execute("REPLACE INTO `mod_temucraft_ptr_live_chars` (`realm`, `realm_name`, `account`, `guid`, `name`, `race`, `class`, `level`) VALUES ({}, '{}', {}, {}, '{}', {}, {}, {})",
            RealmId(), sRealmNameEsc, player->GetSession()->GetAccountId(), player->GetGUID().GetCounter(), Esc(player->GetName()),
            uint32(player->getRace()), uint32(player->getClass()), uint32(player->GetLevel()));
    }

    void RefreshLiveChars()
    {
        uint32 total = 0;
        LoginDatabaseTransaction trans = LoginDatabase.BeginTransaction();
        trans->Append(Acore::StringFormat("DELETE FROM `mod_temucraft_ptr_live_chars` WHERE `realm` = {}", RealmId()));
        if (QueryResult r = CharacterDatabase.Query("SELECT `guid`, `account`, `name`, `race`, `class`, `level` FROM `characters` WHERE `deleteDate` IS NULL"))
        {
            std::string values;
            uint32 n = 0;
            auto flush = [&]
            {
                if (values.empty())
                    return;
                trans->Append("INSERT INTO `mod_temucraft_ptr_live_chars` (`realm`, `realm_name`, `account`, `guid`, `name`, `race`, `class`, `level`) VALUES " + values);
                values.clear();
                n = 0;
            };
            do
            {
                Field* f = r->Fetch();
                if (!values.empty())
                    values += ',';
                values += Acore::StringFormat("({}, '{}', {}, {}, '{}', {}, {}, {})", RealmId(), sRealmNameEsc, f[1].Get<uint32>(), f[0].Get<uint32>(),
                    Esc(f[2].Get<std::string>()), uint32(f[3].Get<uint8>()), uint32(f[4].Get<uint8>()), uint32(f[5].Get<uint8>()));
                ++total;
                if (++n == 500)
                    flush();
            } while (r->NextRow());
            flush();
        }
        LoginDatabase.CommitTransaction(trans);
        LOG_INFO("module", "mod-temucraft-ptr: {} Live characters listed for the PTR copy.", total);
    }

    // ---------------------------------------------------------------- Live: writing copies
    struct PendingDump { uint32 id; uint32 account; uint32 guid; int32 waitMs; };
    struct DumpJob { uint32 id; std::future<std::pair<bool, std::string>> result; };
    std::vector<PendingDump> sPendingDumps;
    std::list<DumpJob> sDumpJobs;

    void StartDump(PendingDump const& d)
    {
        std::string path = DumpPath(d.id);
        sDumpJobs.push_back({ d.id, std::async(std::launch::async, [d, path]() -> std::pair<bool, std::string>
        {
            // helper thread: only synchronous database queries and file writes
            QueryResult own = CharacterDatabase.Query("SELECT `name` FROM `characters` WHERE `guid` = {} AND `account` = {} AND `deleteDate` IS NULL", d.guid, d.account);
            if (!own)
                return { false, "That character is not on this account on Live." };
            std::string name = own->Fetch()[0].Get<std::string>();

            std::string dump;
            PlayerDumpWriter writer;
            if (writer.WriteDumpToString(dump, d.guid) != DUMP_SUCCESS)
                return { false, "Live could not write the copy." };

            std::string tmp = path + ".tmp";
            {
                std::ofstream out(tmp, std::ios::binary | std::ios::trunc);
                if (!out)
                    return { false, "Live could not write to the copy folder." };
                out << dump;
                if (!out)
                    return { false, "Live could not write to the copy folder." };
            }
            std::error_code ec;
            std::filesystem::rename(tmp, path, ec);   // the PTR only ever sees a whole file
            if (ec)
                return { false, "Live could not write to the copy folder." };
            return { true, name };
        }) });
    }

    void OnLivePoll(QueryResult r)
    {
        sLivePolling = false;
        if (!r)
            return;
        do
        {
            Field* f = r->Fetch();
            uint32 id = f[0].Get<uint32>();
            uint32 account = f[1].Get<uint32>();
            uint32 guid = f[2].Get<uint32>();
            if (!sSeen.insert(id).second)
                continue;
            SetState(id, "working", "Live is writing the copy.");
            int32 wait = 0;
            // an online character is saved first so the copy has its latest state; the save is async, so wait a little
            if (Player* player = ObjectAccessor::FindPlayerByLowGUID(guid))
                if (player->IsInWorld() && player->GetSession() && player->GetSession()->GetAccountId() == account)
                {
                    player->SaveToDB(false, false);
                    wait = int32(cfg.saveDelayMs);
                }
            sPendingDumps.push_back({ id, account, guid, wait });
        } while (r->NextRow());
    }

    void UpdateLive(uint32 diff)
    {
        for (auto it = sPendingDumps.begin(); it != sPendingDumps.end();)
        {
            it->waitMs -= int32(diff);
            if (it->waitMs > 0)
            {
                ++it;
                continue;
            }
            StartDump(*it);
            it = sPendingDumps.erase(it);
        }

        for (auto it = sDumpJobs.begin(); it != sDumpJobs.end();)
        {
            if (it->result.wait_for(std::chrono::seconds(0)) != std::future_status::ready)
            {
                ++it;
                continue;
            }
            std::pair<bool, std::string> result = it->result.get();
            if (result.first)
                SetState(it->id, "ready", Acore::StringFormat("Copy of {} written; the PTR loads it next.", result.second));
            else
            {
                SetState(it->id, "failed", result.second);
                LOG_WARN("module", "mod-temucraft-ptr: copy request {} failed on Live: {}", it->id, result.second);
            }
            it = sDumpJobs.erase(it);
        }

        if (sLivePolling)
            return;
        if (sLiveTimer > diff)
        {
            sLiveTimer -= diff;
            return;
        }
        sLiveTimer = cfg.pollMs;
        sLivePolling = true;
        sCallbacks.AddCallback(LoginDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT `id`, `account`, `live_guid` FROM `mod_temucraft_ptr_copy` WHERE `type` = 'copy' AND `state` = 'requested' AND `live_realm` IN (0, {}) ORDER BY `id` LIMIT 5",
            RealmId()))).WithCallback(OnLivePoll);
    }

    // ---------------------------------------------------------------- PTR: loading copies
    enum class LoadStep : uint8 { ReadFile, WaitForDelete, Load };
    struct LoadJob
    {
        uint32 id;
        uint32 account;
        std::string name;
        uint32 oldGuid;
        LoadStep step;
        std::future<std::pair<bool, std::string>> file;   // ok, dump text or error
        std::string dump;
        int32 waitMs;
        uint32 tries;
    };
    std::list<LoadJob> sLoadJobs;

    void FinishLoad(LoadJob& job, bool ok, std::string const& message, uint32 ptrGuid = 0)
    {
        SetState(job.id, ok ? "done" : "failed", message, ptrGuid);
        if (!ok)
            LOG_WARN("module", "mod-temucraft-ptr: copy request {} failed on the PTR: {}", job.id, message);
        if (ok && cfg.deleteDumps)
        {
            std::error_code ec;
            std::filesystem::remove(DumpPath(job.id), ec);
        }
    }

    // Returns true when the job is finished (done or failed).
    bool LoadNow(LoadJob& job)
    {
        uint32 limit = std::min<uint32>(sWorld->getIntConfig(CONFIG_CHARACTERS_PER_REALM), MAX_CHARACTERS_IN_DUMP_READER);
        if (AccountMgr::GetCharactersCount(job.account) >= limit)
        {
            FinishLoad(job, false, "No free character place on the PTR: delete a PTR character and ask again.");
            return true;
        }

        ObjectGuid::LowType newGuid = sObjectMgr->GetGenerator<HighGuid::Player>().GetNextAfterMaxUsed();
        PlayerDumpReader reader;
        DumpReturn ret = reader.LoadDumpFromString(job.dump, job.account, job.name, 0);
        job.dump.clear();
        switch (ret)
        {
            case DUMP_SUCCESS:
                break;
            case DUMP_TOO_MANY_CHARS:
                FinishLoad(job, false, "No free character place on the PTR: delete a PTR character and ask again.");
                return true;
            case DUMP_GUID_OVERFLOW:
                FinishLoad(job, false, "The PTR has run out of character or item numbers: tell a game master.");
                return true;
            default:
                FinishLoad(job, false, "The copy file could not be read on the PTR: ask again.");
                return true;
        }

        CharacterCacheEntry const* entry = sCharacterCache->GetCharacterCacheByGuid(ObjectGuid::Create<HighGuid::Player>(newGuid));
        if (!entry || entry->AccountId != job.account)
        {
            // loaded, but not where we expected it: leave the guid out rather than replace the wrong character later
            FinishLoad(job, true, "Copied to the PTR.");
            return true;
        }
        if (entry->Name == job.name)
            FinishLoad(job, true, Acore::StringFormat("Copied to the PTR as {}.", entry->Name), newGuid);
        else
            FinishLoad(job, true, Acore::StringFormat("Copied to the PTR; the name {} was taken, pick a new one when you log in.", job.name), newGuid);
        LOG_INFO("module", "mod-temucraft-ptr: request {}: account {} has a PTR copy, guid {}.", job.id, job.account, newGuid);
        return true;
    }

    // Returns true when the job is finished (done or failed).
    bool StepLoad(LoadJob& job, uint32 diff)
    {
        switch (job.step)
        {
            case LoadStep::ReadFile:
            {
                if (job.file.wait_for(std::chrono::seconds(0)) != std::future_status::ready)
                    return false;
                std::pair<bool, std::string> file = job.file.get();
                if (!file.first)
                {
                    FinishLoad(job, false, file.second);
                    return true;
                }
                job.dump = std::move(file.second);

                if (job.oldGuid)
                {
                    ObjectGuid old = ObjectGuid::Create<HighGuid::Player>(job.oldGuid);
                    CharacterCacheEntry const* entry = sCharacterCache->GetCharacterCacheByGuid(old);
                    if (entry && entry->AccountId == job.account)
                    {
                        if (ObjectAccessor::FindConnectedPlayer(old))
                        {
                            FinishLoad(job, false, "Your earlier copy is logged in on the PTR: log it out and ask again.");
                            return true;
                        }
                        // the earlier copy goes for good (not to the deleted-character list); its name is free once the
                        // async delete has run
                        Player::DeleteFromDB(job.oldGuid, job.account, true, true);
                        job.step = LoadStep::WaitForDelete;
                        job.waitMs = 1000;
                        return false;
                    }
                }
                job.step = LoadStep::Load;
                return false;
            }
            case LoadStep::WaitForDelete:
            {
                job.waitMs -= int32(diff);
                if (job.waitMs > 0)
                    return false;
                job.waitMs = 1000;
                if (CharacterDatabase.Query("SELECT 1 FROM `characters` WHERE `guid` = {}", job.oldGuid))
                {
                    if (++job.tries >= 60)
                    {
                        FinishLoad(job, false, "The earlier copy could not be removed from the PTR: ask again.");
                        return true;
                    }
                    return false;
                }
                job.step = LoadStep::Load;
                return false;
            }
            case LoadStep::Load:
                return LoadNow(job);
        }
        return true;
    }

    void ApplyTemplate(Player* player, uint32 index)
    {
        std::string command = cfg.applyCommand;
        auto replaceAll = [&command](std::string const& key, std::string const& value)
        {
            for (std::size_t pos = command.find(key); pos != std::string::npos; pos = command.find(key, pos + value.size()))
                command.replace(pos, key.size(), value);
        };
        replaceAll("{name}", player->GetName());
        replaceAll("{index}", std::to_string(index));
        // mod-ptr-template keeps its apply code inside its own .cpp: run its command as the player would type it
        ChatHandler(player->GetSession()).ParseCommands(command);
    }

    // template requests: applied at the character's next login on the PTR (or now, if it is online)
    void CheckTemplateRequest(ObjectGuid guid, uint32 account, std::string const& name)
    {
        std::string query = Acore::StringFormat(
            "SELECT `id`, `template_index` FROM `mod_temucraft_ptr_copy` WHERE `type` = 'template' AND `state` = 'working' AND `account` = {} AND `ptr_name` = '{}' AND `ptr_realm` IN (0, {}) ORDER BY `id` LIMIT 1",
            account, Esc(name), RealmId());
        sCallbacks.AddCallback(LoginDatabase.AsyncQuery(query)).WithCallback([guid](QueryResult r)
        {
            if (!r)
                return;
            Player* player = ObjectAccessor::FindConnectedPlayer(guid);
            if (!player || !player->IsInWorld())
                return;
            uint32 id = r->Fetch()[0].Get<uint32>();
            uint32 index = r->Fetch()[1].Get<uint8>();
            SetState(id, "done", Acore::StringFormat("Template {} applied to {}.", index, player->GetName()));
            ApplyTemplate(player, index);
        });
    }

    void HandleTemplateRequest(uint32 id, uint32 account, std::string name, uint32 index)
    {
        if (!cfg.templates)
        {
            SetState(id, "failed", "Templates are off on this PTR.");
            return;
        }
        if (!normalizePlayerName(name))
        {
            SetState(id, "failed", "No PTR character name given.");
            return;
        }
        CharacterCacheEntry const* entry = sCharacterCache->GetCharacterCacheByName(name);
        if (!entry || entry->AccountId != account)
        {
            SetState(id, "failed", Acore::StringFormat("{} is not a PTR character of this account: make it on the PTR first.", name));
            return;
        }
        LoginDatabase.Execute("UPDATE `mod_temucraft_ptr_copy` SET `state` = 'working', `ptr_name` = '{}', `ptr_realm` = {}, `message` = '{}' WHERE `id` = {}",
            Esc(name), RealmId(), Esc(Acore::StringFormat("Template {} is applied when {} logs in on the PTR.", index, name)), id);
        if (Player* player = ObjectAccessor::FindConnectedPlayer(entry->Guid))
            if (player->IsInWorld())
                CheckTemplateRequest(entry->Guid, account, name);   // queued after the UPDATE above
    }

    void OnPtrPoll(QueryResult r)
    {
        sPtrPolling = false;
        if (!r)
            return;
        do
        {
            Field* f = r->Fetch();
            uint32 id = f[0].Get<uint32>();
            if (!sSeen.insert(id).second)
                continue;
            uint32 account = f[1].Get<uint32>();
            std::string type = f[2].Get<std::string>();
            std::string liveName = f[3].Get<std::string>();
            std::string ptrName = f[4].Get<std::string>();
            uint32 index = f[5].Get<uint8>();
            bool replace = f[6].Get<uint8>() != 0;
            uint32 oldGuid = f[7].IsNull() ? 0 : f[7].Get<uint32>();

            if (type == "template")
            {
                HandleTemplateRequest(id, account, ptrName, index);
                continue;
            }

            std::string name = ptrName.empty() ? liveName : ptrName;
            normalizePlayerName(name);
            SetState(id, "loading", "The PTR is loading the copy.");
            std::string path = DumpPath(id);
            sLoadJobs.push_back({ id, account, name, replace ? oldGuid : 0, LoadStep::ReadFile,
                std::async(std::launch::async, [path]() -> std::pair<bool, std::string>
                {
                    std::ifstream in(path, std::ios::binary);
                    if (!in)
                        return { false, "The PTR can't find the copy file: check that Live and PTR use the same DumpFolder." };
                    std::ostringstream text;
                    text << in.rdbuf();
                    return { true, text.str() };
                }), std::string(), 0, 0 });
        } while (r->NextRow());
    }

    void UpdatePtr(uint32 diff)
    {
        for (auto it = sLoadJobs.begin(); it != sLoadJobs.end();)
        {
            if (StepLoad(*it, diff))
                it = sLoadJobs.erase(it);
            else
                ++it;
        }

        if (sPtrPolling)
            return;
        if (sPtrTimer > diff)
        {
            sPtrTimer -= diff;
            return;
        }
        sPtrTimer = cfg.pollMs;
        sPtrPolling = true;
        // the last copy this account finished of the same Live character on this PTR is the one a 'replace' removes
        sCallbacks.AddCallback(LoginDatabase.AsyncQuery(Acore::StringFormat(
            "SELECT c.`id`, c.`account`, c.`type`, c.`live_name`, c.`ptr_name`, c.`template_index`, c.`replace_old`, "
            "(SELECT o.`ptr_guid` FROM `mod_temucraft_ptr_copy` o WHERE o.`account` = c.`account` AND o.`type` = 'copy' AND o.`state` = 'done' "
            "AND o.`live_realm` = c.`live_realm` AND o.`live_guid` = c.`live_guid` AND o.`ptr_realm` = {0} AND o.`ptr_guid` <> 0 AND o.`id` < c.`id` "
            "ORDER BY o.`id` DESC LIMIT 1) "
            "FROM `mod_temucraft_ptr_copy` c WHERE c.`ptr_realm` IN (0, {0}) AND ((c.`type` = 'copy' AND c.`state` = 'ready') OR (c.`type` = 'template' AND c.`state` = 'requested')) "
            "ORDER BY c.`id` LIMIT 5", RealmId()))).WithCallback(OnPtrPoll);
    }

    // ---------------------------------------------------------------- requests from players
    std::vector<LiveChar> LiveCharsOf(uint32 account)
    {
        std::vector<LiveChar> list;
        if (QueryResult r = LoginDatabase.Query("SELECT `realm`, `guid`, `name`, `level` FROM `mod_temucraft_ptr_live_chars` WHERE `account` = {} ORDER BY `level` DESC, `name` LIMIT 20", account))
            do
            {
                Field* f = r->Fetch();
                list.push_back({ f[0].Get<uint32>(), f[1].Get<uint32>(), f[2].Get<std::string>(), f[3].Get<uint8>() });
            } while (r->NextRow());
        return list;
    }

    bool RequestCopy(ChatHandler& handler, uint32 account, LiveChar const& c, bool replace)
    {
        if (QueryResult r = LoginDatabase.Query("SELECT COUNT(*) FROM `mod_temucraft_ptr_copy` WHERE `account` = {} AND `state` NOT IN ('done', 'failed')", account))
            if (r->Fetch()[0].Get<uint64>() >= cfg.maxOpen)
            {
                handler.PSendSysMessage(TemucraftModuleText(MODULE, handler, 4, "|cff66ccffPTR:|r you already have {} copies on the way. Wait for them to finish (.ptr status)."), cfg.maxOpen);
                return false;
            }
        uint32 ptrRealm = cfg.ptr ? RealmId() : cfg.ptrRealm;
        LoginDatabase.Execute("INSERT INTO `mod_temucraft_ptr_copy` (`account`, `type`, `live_realm`, `live_guid`, `live_name`, `ptr_realm`, `ptr_name`, `replace_old`, `message`) "
            "VALUES ({}, 'copy', {}, {}, '{}', {}, '{}', {}, 'Waiting for Live.')", account, c.realm, c.guid, Esc(c.name), ptrRealm, Esc(c.name), replace ? 1 : 0);
        handler.PSendSysMessage(TemucraftModuleText(MODULE, handler, 5, "|cff66ccffPTR:|r copy of {} asked for{}. It shows on the PTR character list in a minute or so; .ptr status shows how far it is."),
            c.name, replace ? TemucraftModuleText(MODULE, handler, 6, " (it replaces your earlier copy)") : "");
        return true;
    }

    void ShowStatus(ChatHandler& handler, uint32 account)
    {
        QueryResult r = LoginDatabase.Query("SELECT `id`, `type`, `live_name`, `ptr_name`, `template_index`, `state`, `message` FROM `mod_temucraft_ptr_copy` WHERE `account` = {} ORDER BY `id` DESC LIMIT 5", account);
        if (!r)
        {
            handler.SendSysMessage(TemucraftModuleText(MODULE, handler, 12, "|cff66ccffPTR:|r no copy requests yet."));
            return;
        }
        handler.SendSysMessage(TemucraftModuleText(MODULE, handler, 10, "|cff66ccffPTR:|r your last copy requests:"));
        do
        {
            Field* f = r->Fetch();
            std::string type = f[1].Get<std::string>();
            std::string what = type == "template" ? Acore::StringFormat("template {} for {}", uint32(f[4].Get<uint8>()), f[3].Get<std::string>()) : f[2].Get<std::string>();
            handler.PSendSysMessage(TemucraftModuleText(MODULE, handler, 11, "  #{} {}: {} - {}"), f[0].Get<uint32>(), what, f[5].Get<std::string>(), f[6].Get<std::string>());
        } while (r->NextRow());
    }

    // ---------------------------------------------------------------- PTR Quartermaster
    enum Actions : uint32
    {
        ACTION_MAIN         = 1,
        ACTION_SUPPLIES     = 2,
        ACTION_TAKE_ALL     = 3,
        ACTION_TEMPLATES    = 4,
        ACTION_COPY_LIST    = 5,
        ACTION_STATUS       = 6,
        ACTION_ITEM         = 100,    // + supply index
        ACTION_TEMPLATE     = 1000,   // + template ID
        ACTION_COPY_PICK    = 2000,   // + list index
        ACTION_COPY_NEW     = 3000,   // + list index
        ACTION_COPY_REPLACE = 4000    // + list index
    };

    bool ForClass(Supply const& s, Player* player) { return !s.classMask || (s.classMask & player->getClassMask()); }

    void LoadSupplies()
    {
        sSupplies.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT `item`, `count`, `class_mask` FROM `mod_temucraft_ptr_supplies` ORDER BY `sort`, `item`"))
            do
            {
                Field* f = r->Fetch();
                uint32 item = f[0].Get<uint32>();
                if (!sObjectMgr->GetItemTemplate(item))
                {
                    LOG_ERROR("sql.sql", "mod-temucraft-ptr: mod_temucraft_ptr_supplies has item {}, which does not exist.", item);
                    continue;
                }
                sSupplies.push_back({ item, std::max<uint32>(1, f[1].Get<uint32>()), f[2].Get<uint32>() });
            } while (r->NextRow());
    }

    void SpawnQuartermasters()
    {
        struct Spot { uint32 entry; ObjectGuid::LowType banker; float forward; };
        for (Spot const& spot : { Spot{ QUARTERMASTER_ALLIANCE, BANKER_STORMWIND, 10.0f }, Spot{ QUARTERMASTER_HORDE, BANKER_ORGRIMMAR, 6.0f } })
        {
            CreatureData const* banker = sObjectMgr->GetCreatureData(spot.banker);
            if (!banker)
            {
                LOG_ERROR("module", "mod-temucraft-ptr: banker spawn {} is missing, its PTR Quartermaster is not placed.", spot.banker);
                continue;
            }
            // in front of the banker (along its facing), looking the same way: towards the bank's door
            float x = banker->posX + spot.forward * std::cos(banker->orientation);
            float y = banker->posY + spot.forward * std::sin(banker->orientation);
            if (!sObjectMgr->AddCreData(spot.entry, banker->mapid, x, y, banker->posZ, banker->orientation, 300))
                LOG_ERROR("module", "mod-temucraft-ptr: PTR Quartermaster {} could not be placed (is the world SQL applied?).", spot.entry);
        }
    }

    void ShowMain(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, TemucraftModuleText(MODULE, player, 13, "Supplies for my class"), GOSSIP_SENDER_MAIN, ACTION_SUPPLIES);
        if (cfg.templates)
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, TemucraftModuleText(MODULE, player, 16, "Level-80 templates"), GOSSIP_SENDER_MAIN, ACTION_TEMPLATES);
        if (CopiesOn())
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 19, "Copy a character from Live"), GOSSIP_SENDER_MAIN, ACTION_COPY_LIST);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 23, "How are my copies doing?"), GOSSIP_SENDER_MAIN, ACTION_STATUS);
        }
        SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
    }

    void ShowSupplies(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, TemucraftModuleText(MODULE, player, 14, "Take everything"), GOSSIP_SENDER_MAIN, ACTION_TAKE_ALL);
        uint32 shown = 0;
        for (uint32 i = 0; i < sSupplies.size() && shown < 28; ++i)
        {
            Supply const& s = sSupplies[i];
            if (!ForClass(s, player))
                continue;
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(s.item);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, Acore::StringFormat(TemucraftModuleText(MODULE, player, 15, "{} x {}"), s.count, proto->Name1), GOSSIP_SENDER_MAIN, ACTION_ITEM + i);
            ++shown;
        }
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 24, "Back"), GOSSIP_SENDER_MAIN, ACTION_MAIN);
        SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
    }

    bool GiveSupply(Player* player, Supply const& s)
    {
        if (player->AddItem(s.item, s.count))
            return true;
        ChatHandler(player->GetSession()).SendSysMessage(TemucraftModuleText(MODULE, player, 25, "|cff66ccffPTR:|r your bags are full."));
        return false;
    }

    void ShowTemplates(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        uint32 shown = 0;
        if (QueryResult r = WorldDatabase.Query("SELECT `ID`, `Comment` FROM `mod_ptrtemplate_index` WHERE `Enable` = 1 ORDER BY `ID` LIMIT 25"))
            do
            {
                Field* f = r->Fetch();
                uint32 id = f[0].Get<uint8>();
                AddGossipItemFor(player, GOSSIP_ICON_TRAINER, Acore::StringFormat(TemucraftModuleText(MODULE, player, 17, "Use template: {}"), f[1].Get<std::string>()),
                    GOSSIP_SENDER_MAIN, ACTION_TEMPLATE + id, TemucraftModuleText(MODULE, player, 18, "This replaces your level, gear and spells with the template. Go on?"), 0, false);
                ++shown;
            } while (r->NextRow());
        if (!shown)
            ChatHandler(player->GetSession()).SendSysMessage(TemucraftModuleText(MODULE, player, 26, "|cff66ccffPTR:|r there are no templates on this PTR yet."));
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 24, "Back"), GOSSIP_SENDER_MAIN, ACTION_MAIN);
        SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
    }

    void ShowCopyList(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        std::vector<LiveChar> list = LiveCharsOf(player->GetSession()->GetAccountId());
        if (list.empty())
            ChatHandler(player->GetSession()).SendSysMessage(TemucraftModuleText(MODULE, player, 9, "|cff66ccffPTR:|r no Live characters are known for your account yet."));
        for (uint32 i = 0; i < list.size(); ++i)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, Acore::StringFormat(TemucraftModuleText(MODULE, player, 20, "Copy {} (level {})"), list[i].name, uint32(list[i].level)),
                GOSSIP_SENDER_MAIN, ACTION_COPY_PICK + i);
        {
            std::lock_guard<std::mutex> lock(sPickLock);
            sPick[player->GetGUID().GetCounter()] = std::move(list);
        }
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 24, "Back"), GOSSIP_SENDER_MAIN, ACTION_MAIN);
        SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
    }

    bool PickedChar(Player* player, uint32 index, LiveChar& out)
    {
        std::lock_guard<std::mutex> lock(sPickLock);
        auto it = sPick.find(player->GetGUID().GetCounter());
        if (it == sPick.end() || index >= it->second.size())
            return false;
        out = it->second[index];
        return true;
    }

    class npc_temucraft_ptr_quartermaster : public CreatureScript
    {
    public:
        npc_temucraft_ptr_quartermaster() : CreatureScript("npc_temucraft_ptr_quartermaster") { }

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            if (!cfg.ptr || !cfg.quartermaster)
                return true;   // no menu off the PTR
            ShowMain(player, creature);
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
        {
            if (!cfg.ptr || !cfg.quartermaster)
            {
                CloseGossipMenuFor(player);
                return true;
            }
            ChatHandler handler(player->GetSession());
            if (action == ACTION_MAIN)
                ShowMain(player, creature);
            else if (action == ACTION_SUPPLIES)
                ShowSupplies(player, creature);
            else if (action == ACTION_TAKE_ALL)
            {
                for (Supply const& s : sSupplies)
                    if (ForClass(s, player) && !GiveSupply(player, s))
                        break;
                ShowSupplies(player, creature);
            }
            else if (action >= ACTION_ITEM && action < ACTION_TEMPLATE)
            {
                if (action - ACTION_ITEM < sSupplies.size() && ForClass(sSupplies[action - ACTION_ITEM], player))
                    GiveSupply(player, sSupplies[action - ACTION_ITEM]);
                ShowSupplies(player, creature);
            }
            else if (action == ACTION_TEMPLATES && cfg.templates)
                ShowTemplates(player, creature);
            else if (action >= ACTION_TEMPLATE && action < ACTION_COPY_PICK && cfg.templates)
            {
                CloseGossipMenuFor(player);
                ApplyTemplate(player, action - ACTION_TEMPLATE);
            }
            else if (action == ACTION_COPY_LIST && CopiesOn())
                ShowCopyList(player, creature);
            else if (action == ACTION_STATUS && CopiesOn())
            {
                CloseGossipMenuFor(player);
                ShowStatus(handler, player->GetSession()->GetAccountId());
            }
            else if (action >= ACTION_COPY_PICK && action < ACTION_COPY_NEW && CopiesOn())
            {
                LiveChar c;
                if (!PickedChar(player, action - ACTION_COPY_PICK, c))
                {
                    ShowCopyList(player, creature);
                    return true;
                }
                ClearGossipMenuFor(player);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 21, "Copy as a new character"), GOSSIP_SENDER_MAIN, ACTION_COPY_NEW + (action - ACTION_COPY_PICK));
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 22, "Copy and replace my earlier copy of it"), GOSSIP_SENDER_MAIN, ACTION_COPY_REPLACE + (action - ACTION_COPY_PICK));
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, TemucraftModuleText(MODULE, player, 24, "Back"), GOSSIP_SENDER_MAIN, ACTION_COPY_LIST);
                SendGossipMenuFor(player, QUARTERMASTER_TEXT, creature->GetGUID());
            }
            else if (action >= ACTION_COPY_NEW && action < ACTION_COPY_REPLACE + 1000 && CopiesOn())
            {
                bool replace = action >= ACTION_COPY_REPLACE;
                LiveChar c;
                CloseGossipMenuFor(player);
                if (PickedChar(player, action - (replace ? ACTION_COPY_REPLACE : ACTION_COPY_NEW), c))
                    RequestCopy(handler, player->GetSession()->GetAccountId(), c, replace);
            }
            else
                CloseGossipMenuFor(player);
            return true;
        }
    };

    // ---------------------------------------------------------------- hooks
    class TemucraftPtrPlayer : public PlayerScript
    {
    public:
        TemucraftPtrPlayer() : PlayerScript("TemucraftPtrPlayer", {
            PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_CREATE, PLAYERHOOK_ON_DELETE }) { }

        void OnPlayerLogin(Player* player) override
        {
            UpsertLiveChar(player);
            if (!cfg.ptr)
                return;
            if (cfg.loginMessage)
                ChatHandler(player->GetSession()).SendSysMessage(TemucraftModuleText(MODULE, player, 1, "|cffff8000You are on the PTR: progress here never goes back to Live.|r"));
            if (cfg.templates)
                CheckTemplateRequest(player->GetGUID(), player->GetSession()->GetAccountId(), player->GetName());
        }

        void OnPlayerLogout(Player* player) override
        {
            UpsertLiveChar(player);
            std::lock_guard<std::mutex> lock(sPickLock);
            sPick.erase(player->GetGUID().GetCounter());
        }

        void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override { UpsertLiveChar(player); }
        void OnPlayerCreate(Player* player) override { UpsertLiveChar(player); }

        void OnPlayerDelete(ObjectGuid guid, uint32 /*accountId*/) override
        {
            if (cfg.writer)
                LoginDatabase.Execute("DELETE FROM `mod_temucraft_ptr_live_chars` WHERE `realm` = {} AND `guid` = {}", RealmId(), guid.GetCounter());
        }
    };

    class TemucraftPtrWorld : public WorldScript
    {
    public:
        TemucraftPtrWorld() : WorldScript("TemucraftPtrWorld", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_UPDATE }) { }

        void OnAfterConfigLoad(bool /*reload*/) override { LoadConfig(); }

        void OnStartup() override
        {
            sRealmNameEsc = Esc(realm.Name);
            if (cfg.ptr && cfg.writer)
                LOG_WARN("module", "mod-temucraft-ptr: Temucraft.PTR.Enable and Temucraft.PTR.CopyWriter are both on: this realm copies to itself.");
            if (CopiesOn())
            {
                std::error_code ec;
                if (!std::filesystem::is_directory(cfg.folder, ec))
                    LOG_ERROR("module", "mod-temucraft-ptr: Temucraft.PTR.DumpFolder '{}' is not a folder this worldserver can reach.", cfg.folder);
                if (cfg.keepDays)
                    LoginDatabase.Execute("DELETE FROM `mod_temucraft_ptr_copy` WHERE `state` IN ('done', 'failed') AND `updated` < NOW() - INTERVAL {} DAY", cfg.keepDays);
            }
            if (cfg.writer && !cfg.folder.empty())
            {
                // a copy this realm was writing when it stopped is written again
                LoginDatabase.Execute("UPDATE `mod_temucraft_ptr_copy` SET `state` = 'requested' WHERE `type` = 'copy' AND `state` = 'working' AND `live_realm` IN (0, {})", RealmId());
                RefreshLiveChars();
            }
            if (cfg.ptr)
            {
                if (!cfg.folder.empty())
                    LoginDatabase.Execute("UPDATE `mod_temucraft_ptr_copy` SET `state` = 'ready' WHERE `type` = 'copy' AND `state` = 'loading' AND `ptr_realm` IN (0, {})", RealmId());
                if (cfg.quartermaster)
                {
                    LoadSupplies();
                    SpawnQuartermasters();
                }
            }
        }

        void OnUpdate(uint32 diff) override
        {
            sCallbacks.ProcessReadyCallbacks();
            if (cfg.folder.empty())
                return;
            if (cfg.writer)
                UpdateLive(diff);
            if (cfg.ptr)
                UpdatePtr(diff);
        }
    };

    // ---------------------------------------------------------------- commands
    class TemucraftPtrCommands : public CommandScript
    {
    public:
        TemucraftPtrCommands() : CommandScript("TemucraftPtrCommands") { }

        ChatCommandTable GetCommands() const override
        {
            static ChatCommandTable copy =
            {
                { "list", HandleCopyList, 104051, Console::No },
                { "",     HandleCopy,     104050, Console::No },
            };
            static ChatCommandTable ptr =
            {
                { "copy",     copy },
                { "status",   HandleStatus,   104052, Console::No },
                { "requests", HandleRequests, 104001, Console::Yes },
            };
            static ChatCommandTable root = { { "ptr", ptr } };
            return root;
        }

        static bool Off(ChatHandler* handler)
        {
            if (CopiesOn())
                return false;
            handler->SendSysMessage(TemucraftModuleText(MODULE, handler, 2, "|cff66ccffPTR:|r character copies are off on this realm."));
            return true;
        }

        static bool HandleCopy(ChatHandler* handler, std::string_view nameArg, Optional<std::string_view> option)
        {
            if (Off(handler))
                return true;
            uint32 account = handler->GetSession()->GetAccountId();
            std::string name(nameArg);
            QueryResult r;
            if (normalizePlayerName(name))   // a name on this realm first, if the account has the same name on two Live realms
                r = LoginDatabase.Query("SELECT `realm`, `guid`, `name`, `level` FROM `mod_temucraft_ptr_live_chars` WHERE `account` = {} AND `name` = '{}' ORDER BY (`realm` = {}) DESC, `realm` LIMIT 1",
                    account, Esc(name), RealmId());
            if (!r)
            {
                handler->PSendSysMessage(TemucraftModuleText(MODULE, handler, 3, "|cff66ccffPTR:|r no Live character named {} on your account. Type .ptr copy list to see them."), std::string(nameArg));
                return true;
            }
            Field* f = r->Fetch();
            LiveChar c{ f[0].Get<uint32>(), f[1].Get<uint32>(), f[2].Get<std::string>(), f[3].Get<uint8>() };
            bool replace = option && (*option == "replace" || *option == "Replace");
            RequestCopy(*handler, account, c, replace);
            return true;
        }

        static bool HandleCopyList(ChatHandler* handler)
        {
            if (Off(handler))
                return true;
            uint32 account = handler->GetSession()->GetAccountId();
            QueryResult r = LoginDatabase.Query("SELECT `name`, `level`, `class`, `realm_name` FROM `mod_temucraft_ptr_live_chars` WHERE `account` = {} ORDER BY `level` DESC, `name` LIMIT 20", account);
            if (!r)
            {
                handler->SendSysMessage(TemucraftModuleText(MODULE, handler, 9, "|cff66ccffPTR:|r no Live characters are known for your account yet."));
                return true;
            }
            handler->SendSysMessage(TemucraftModuleText(MODULE, handler, 7, "|cff66ccffPTR:|r your Live characters (.ptr copy <name>, add 'replace' to replace your earlier copy):"));
            do
            {
                Field* f = r->Fetch();
                handler->PSendSysMessage(TemucraftModuleText(MODULE, handler, 8, "  {} - level {} {} ({})"), f[0].Get<std::string>(), uint32(f[1].Get<uint8>()), ClassName(f[2].Get<uint8>()), f[3].Get<std::string>());
            } while (r->NextRow());
            return true;
        }

        static bool HandleStatus(ChatHandler* handler)
        {
            if (Off(handler))
                return true;
            ShowStatus(*handler, handler->GetSession()->GetAccountId());
            return true;
        }

        static bool HandleRequests(ChatHandler* handler)
        {
            QueryResult open = LoginDatabase.Query("SELECT `state`, COUNT(*) FROM `mod_temucraft_ptr_copy` WHERE `state` NOT IN ('done') GROUP BY `state`");
            if (!open)
            {
                handler->SendSysMessage("PTR copies: nothing open or failed.");
                return true;
            }
            do
                handler->PSendSysMessage("PTR copies {}: {}", open->Fetch()[0].Get<std::string>(), open->Fetch()[1].Get<uint64>());
            while (open->NextRow());
            if (QueryResult r = LoginDatabase.Query("SELECT `id`, `account`, `type`, `live_name`, `ptr_name`, `state`, `message`, `updated` FROM `mod_temucraft_ptr_copy` WHERE `state` <> 'done' ORDER BY `id` DESC LIMIT 15"))
                do
                {
                    Field* f = r->Fetch();
                    handler->PSendSysMessage("  #{} account {} {} {}/{}: {} - {} ({})", f[0].Get<uint32>(), f[1].Get<uint32>(), f[2].Get<std::string>(), f[3].Get<std::string>(),
                        f[4].Get<std::string>(), f[5].Get<std::string>(), f[6].Get<std::string>(), f[7].Get<std::string>());
                } while (r->NextRow());
            return true;
        }
    };
}

void AddTemucraftPtrScripts()
{
    new TemucraftPtr::TemucraftPtrWorld();
    new TemucraftPtr::TemucraftPtrPlayer();
    new TemucraftPtr::npc_temucraft_ptr_quartermaster();
    new TemucraftPtr::TemucraftPtrCommands();
}

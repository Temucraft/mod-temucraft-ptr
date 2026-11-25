-- mod-ptr-template (Temucraft fork): replaces the fork's data/sql/db-world/ptr-template_command.sql.
-- On Temucraft a `command` row overrides the permission written in the code (ChatCommand.cpp), and `security` is a
-- SMALLINT read as uint16, so it can't hold the RBAC ids 104101-104151. Like the Temucraft modules, the fork keeps no
-- `command` rows: the permissions come from the command table in the code and ptr_template_rbac.sql.
DELETE FROM `command` WHERE `name` IN ('template apply', 'template disable', 'template enable', 'template list');

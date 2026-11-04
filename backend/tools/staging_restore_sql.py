"""Build a bounded application restore, not a full Supabase platform clone.

Source SQL comes from the owner-authorized pg_dump archive. All dump SQL and
COPY values stay in memory. Only numeric archive IDs are staged as temporary files.
"""

from dataclasses import dataclass
from pathlib import Path
import re
from uuid import uuid4

from tools.backup_database import MAX_MEMORY, TOOLS, capture, clean_environment, require

TABLES = ("auth.users", "auth.identities", "public.users", "public._prisma_migrations")
PUBLIC_FUNCTIONS = {"handle_auth_user_created()", "handle_auth_email_changed()"}
AUTH_TRIGGERS = {"users wellbeing_auth_user_created", "users wellbeing_auth_email_changed"}
KINDS = sorted({
    "SEQUENCE OWNED BY", "MATERIALIZED VIEW DATA", "PUBLICATION TABLES IN SCHEMA",
    "TEXT SEARCH CONFIGURATION", "TEXT SEARCH DICTIONARY", "TEXT SEARCH TEMPLATE", "TEXT SEARCH PARSER",
    "FOREIGN DATA WRAPPER", "DATABASE PROPERTIES", "FK CONSTRAINT", "TABLE DATA", "ROW SECURITY",
    "SEQUENCE SET", "DEFAULT ACL", "SECURITY LABEL", "EVENT TRIGGER", "FOREIGN TABLE",
    "USER MAPPING", "OPERATOR CLASS", "OPERATOR FAMILY", "MATERIALIZED VIEW", "PUBLICATION TABLE",
    "PROCEDURAL LANGUAGE", "ACCESS METHOD", "BLOB METADATA", "BLOB COMMENTS", "SHELL TYPE",
    "SCHEMA", "TYPE", "TABLE", "FUNCTION", "PROCEDURE", "CONSTRAINT", "INDEX", "DEFAULT",
    "TRIGGER", "POLICY", "ACL", "COMMENT", "SEQUENCE", "EXTENSION", "RULE", "DOMAIN",
    "AGGREGATE", "COLLATION", "CAST", "OPERATOR", "TRANSFORM", "SERVER", "PUBLICATION",
    "SUBSCRIPTION", "ENCODING", "STDSTRINGS", "SEARCHPATH", "SEARCH PATH", "BLOBS", "LANGUAGE",
}, key=len, reverse=True)
PUBLIC_KINDS = {"TYPE", "TABLE", "TABLE DATA", "FUNCTION", "CONSTRAINT", "FK CONSTRAINT",
                "INDEX", "POLICY", "ROW SECURITY", "ACL", "COMMENT", "DEFAULT"}
IDENTIFIER = r'(?:"(?:[^"]|"")+"|[a-zA-Z_][a-zA-Z0-9_$]*)'


def quote(value):
    return '"' + value.replace('"', '""') + '"'


def qualified(value):
    return ".".join(quote(part) for part in value.split("."))


@dataclass
class CopyBlock:
    name: str
    columns: tuple[str, ...]
    data: str
    rows: int


def copy_blocks(script):
    header = re.compile(rf'COPY ({IDENTIFIER})\.({IDENTIFIER}) \((.+)\) FROM stdin;')
    result, active, rows = {}, None, []
    for line in script.splitlines(keepends=True):
        plain = line.rstrip("\r\n")
        if active is not None:
            if plain == r"\.":
                name, columns = active
                result[name] = CopyBlock(name, columns, "".join(rows), len(rows))
                active, rows = None, []
            else:
                rows.append(line if line.endswith("\n") else line + "\n")
        elif plain.startswith("COPY "):
            match = header.fullmatch(plain)
            require(match is not None, "UNREVIEWED_COPY_FORMAT")
            def unquote(value):
                return value[1:-1].replace('""', '"') if value.startswith('"') else value
            name = unquote(match[1]) + "." + unquote(match[2])
            require(name not in result, "DUPLICATE_COPY_TABLE")
            column_tokens = [token.strip() for token in match[3].split(",")]
            require(all(re.fullmatch(IDENTIFIER, token) for token in column_tokens), "UNREVIEWED_COPY_COLUMNS")
            columns = tuple(unquote(token) for token in column_tokens)
            require(len(set(columns)) == len(columns), "DUPLICATE_COPY_COLUMN")
            active = name, columns
    require(active is None, "INCOMPLETE_COPY_BLOCK")
    return result


def select_archive(index):
    public, triggers, acls, function_names, tables = [], [], [], set(), set()
    trigger_names = set()
    for line in index.splitlines():
        match = re.match(r"^([0-9]+);\s+[0-9]+\s+[0-9]+\s+(.+)$", line)
        if not match:
            continue
        entry_id, rest = int(match[1]), match[2]
        kind = next((item for item in KINDS if rest.startswith(item + " ")), None)
        if kind is None:
            require(" public " not in rest and " auth " not in rest, "UNKNOWN_APPLICATION_ARCHIVE_ENTRY")
            continue
        parts = rest[len(kind) + 1:].split(" ", 1)
        if len(parts) != 2:
            continue
        namespace, description = parts
        if namespace == "public":
            if kind == "DEFAULT ACL":
                continue
            require(kind in PUBLIC_KINDS, "UNREVIEWED_PUBLIC_OBJECT")
            if kind in {"TABLE", "TABLE DATA"}:
                table = description.rsplit(" ", 1)[0]
                require(table in {"users", "_prisma_migrations"}, "UNREVIEWED_PUBLIC_TABLE")
                tables.add(table)
            if kind == "FUNCTION":
                function = description.rsplit(" ", 1)[0]
                require(function in PUBLIC_FUNCTIONS, "UNREVIEWED_PUBLIC_FUNCTION")
                function_names.add(function)
            (acls if kind == "ACL" else public).append(entry_id)
        elif namespace == "auth" and kind == "TRIGGER":
            name = description.rsplit(" ", 1)[0]
            require(name in AUTH_TRIGGERS, "UNREVIEWED_AUTH_TRIGGER")
            triggers.append(entry_id)
            trigger_names.add(name)
    require(tables == {"users", "_prisma_migrations"} and function_names == PUBLIC_FUNCTIONS
            and trigger_names == AUTH_TRIGGERS and len(triggers) == 2, "REQUIRED_RESTORE_OBJECT_MISSING")
    return public, triggers, acls


def render_selected(dump, ids, section):
    directory = TOOLS / ("restore-selection-" + uuid4().hex)
    directory.mkdir()
    selection = directory / "ids.list"
    try:
        # pg_restore consumes dump IDs; names/owners/private SQL are not written here.
        selection.write_text("".join(f"{entry};\n" for entry in ids), encoding="ascii")
        section_flags = [] if section is None else ["--section=" + section]
        result = capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--use-list", str(selection),
                          *section_flags, "--file=-"],
                         env=clean_environment(), data=dump, limit=MAX_MEMORY).decode("utf-8")
        for line in result.splitlines():
            if line.startswith("\\"):
                require(re.fullmatch(r"\\(?:un)?restrict [a-zA-Z0-9]+", line) is not None,
                        "UNREVIEWED_PSQL_COMMAND")
        # Keep bounded operator timeouts; dump-generated setup otherwise disables them.
        result = re.sub(r"^SET (?:statement_timeout|lock_timeout|idle_in_transaction_session_timeout|transaction_timeout) = .*;\r?$",
                        "", result, flags=re.M)
        return result
    finally:
        if selection.exists():
            selection.unlink()
        directory.rmdir()


def prepare_payload(dump):
    env = clean_environment()
    index = capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--list"], env=env, data=dump).decode("utf-8")
    public, triggers, acls = select_archive(index)
    blocks = copy_blocks(capture([str(TOOLS / "pgsql/bin/pg_restore.exe"), "--data-only", "--file=-"],
                                 env=env, data=dump, limit=MAX_MEMORY).decode("utf-8"))
    require(all(name in blocks for name in (*TABLES, "auth.schema_migrations")), "REQUIRED_COPY_DATA_MISSING")
    for name in ("storage.buckets", "storage.objects", "vault.secrets"):
        require(name in blocks and blocks[name].rows == 0, "NONEMPTY_OR_UNVERIFIED_STORAGE_VAULT")
    for name, block in blocks.items():
        if name.startswith("auth.") and name not in TABLES and name != "auth.schema_migrations":
            # Old session/flow state is intentionally excluded; MFA/SSO/OAuth configuration is not silently lost.
            disposable = {"auth.sessions", "auth.refresh_tokens", "auth.audit_log_entries", "auth.one_time_tokens",
                          "auth.flow_state", "auth.mfa_challenges", "auth.mfa_amr_claims"}
            require(name in disposable or block.rows == 0, "NONEMPTY_ADDITIONAL_AUTH_CONFIGURATION")
    require(blocks["auth.users"].rows == blocks["public.users"].rows, "ACCOUNT_PROFILE_COUNT_MISMATCH")
    return {
        "pre": render_selected(dump, public, "pre-data"),
        "post": render_selected(dump, public, "post-data"),
        "acls": render_selected(dump, acls, None),
        "triggers": render_selected(dump, triggers, "post-data"),
        "blocks": {name: blocks[name] for name in (*TABLES, "auth.schema_migrations")},
        "excluded_auth_state_rows": sum(block.rows for name, block in blocks.items()
                                        if name.startswith("auth.") and name not in TABLES
                                        and name != "auth.schema_migrations"),
    }


def build_restore_sql(payload, *, expected_database="postgres"):
    require(re.fullmatch(r"[a-zA-Z0-9_]+", expected_database), "INVALID_TARGET_DATABASE")
    pieces = [f"""BEGIN READ WRITE;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL search_path = '';
SET LOCAL timezone = 'UTC';
LOCK TABLE auth.users, auth.identities IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
 IF current_database() <> '{expected_database}' OR current_user <> 'postgres'
    OR to_regclass('public.users') IS NOT NULL OR to_regclass('public._prisma_migrations') IS NOT NULL
    OR EXISTS (SELECT 1 FROM auth.users) OR EXISTS (SELECT 1 FROM auth.identities)
    OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='chatbot')
    OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal) THEN
   RAISE EXCEPTION 'STAGING_TARGET_CHANGED' USING ERRCODE='P0001';
 END IF;
END $$;
""", payload["pre"], """
REVOKE ALL ON public.users, public._prisma_migrations FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.handle_auth_user_created(), public.handle_auth_email_changed()
  FROM PUBLIC, anon, authenticated, service_role;
"""]
    for number, name in enumerate((*TABLES, "auth.schema_migrations")):
        block = payload["blocks"][name]
        columns = ",".join(quote(column) for column in block.columns)
        temporary = f"msu_restore_expected_{number}"
        pieces.append(f"CREATE TEMP TABLE {quote(temporary)} ON COMMIT DROP AS SELECT {columns} FROM {qualified(name)} WITH NO DATA;\n")
        pieces.append(f"COPY pg_temp.{quote(temporary)} ({columns}) FROM stdin;\n{block.data}\\.\n")
        if name != "auth.schema_migrations":
            pieces.append(f"INSERT INTO {qualified(name)} ({columns}) SELECT {columns} FROM pg_temp.{quote(temporary)};\n")
        actual = f"SELECT {columns} FROM {qualified(name)}"
        pieces.append(f"""DO $$ BEGIN
 IF EXISTS (SELECT to_jsonb(e) FROM pg_temp.{quote(temporary)} e
            EXCEPT ALL SELECT to_jsonb(a) FROM ({actual}) a)
    OR EXISTS (SELECT to_jsonb(a) FROM ({actual}) a
               EXCEPT ALL SELECT to_jsonb(e) FROM pg_temp.{quote(temporary)} e) THEN
   RAISE EXCEPTION 'RESTORE_SNAPSHOT_MISMATCH_{number}' USING ERRCODE='P0001';
 END IF;
END $$;
""")
    ledger_columns = ",".join(quote(column) for column in payload["blocks"]["public._prisma_migrations"].columns)
    pieces.extend([payload["post"], payload["acls"], f"""
-- Staging deliberately restricts the legacy website ledger; no client needs it.
REVOKE ALL ON public._prisma_migrations FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ({ledger_columns}) ON public._prisma_migrations FROM PUBLIC, anon, authenticated, service_role;
""", payload["triggers"], """
DO $$ BEGIN
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.users'::regclass) THEN
   RAISE EXCEPTION 'RESTORE_PROFILE_RLS_MISSING';
 END IF;
 IF EXISTS (SELECT 1 FROM public.users p LEFT JOIN auth.users a ON p.id=a.id WHERE a.id IS NULL) THEN
   RAISE EXCEPTION 'RESTORE_PROFILE_IDENTITY_MISMATCH';
 END IF;
 IF (SELECT count(*) FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal) <> 2 THEN
   RAISE EXCEPTION 'RESTORE_AUTH_TRIGGER_COUNT_MISMATCH';
 END IF;
 IF NOT has_schema_privilege('authenticated','public','USAGE')
    OR NOT has_column_privilege('authenticated','public.users','id','SELECT')
    OR NOT has_column_privilege('authenticated','public.users','full_name','SELECT')
    OR NOT has_column_privilege('authenticated','public.users','email','SELECT')
    OR NOT has_column_privilege('authenticated','public.users','role','SELECT')
    OR NOT has_column_privilege('authenticated','public.users','is_active','SELECT')
 THEN RAISE EXCEPTION 'RESTORE_PROFILE_COLUMN_READ_MISSING';
 END IF;
 IF has_table_privilege('authenticated','public.users','SELECT')
    OR has_column_privilege('authenticated','public.users','password_hash','SELECT') THEN
   RAISE EXCEPTION 'RESTORE_PROFILE_HASH_PRIVILEGE_EXPOSED';
 END IF;
 IF has_table_privilege('anon','public.users','SELECT')
    OR has_table_privilege('authenticated','public.users','INSERT') THEN
   RAISE EXCEPTION 'RESTORE_PROFILE_UNEXPECTED_CLIENT_PRIVILEGE';
 END IF;
 IF has_table_privilege('authenticated','public._prisma_migrations','SELECT') THEN
   RAISE EXCEPTION 'RESTORE_LEDGER_CLIENT_PRIVILEGE_EXPOSED';
 END IF;
END $$;
COMMIT;
SELECT 'MSU_STAGING_RESTORE_COMMIT_OK';
"""])
    return "\n".join(pieces)

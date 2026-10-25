# MCPLIB Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the multi-server RPG application source and an IFS/CL compile path while preserving the existing tutorial server.

**Architecture:** A shared catalog maps a short server ID to per-server configuration and tool tables. A generic CGI program reads one server's registry and invokes a qualified standalone RPG handler through a fixed interface. DDS command processors manage server and tool metadata.

**Tech Stack:** IBM i ILE RPG with embedded SQL, DDS, CL command definitions, Db2 for i, IBM HTTP Server CGI, PASE make.

**Spec:** `docs/superpowers/specs/2026-10-25-mcplib-application-design.md`

## Global Constraints

- All IBM i object, DDS field, and record format names have at most ten characters.
- The application library is `MCPLIB`; per-server IDs are uppercase, at most ten characters, and distinct from display names.
- Only READ handlers can become active in this release.
- The existing `rpgle-mcp-server/` tutorial remains untouched.
- No IBM i partition is configured in this workspace; compilation and HTTP acceptance require a later live run.

## Review Focus

- An invalid server ID or client-supplied tool name cannot become a dynamic SQL identifier or program name.
- A published tool cannot be called from a different server.
- A malformed or oversized handler result cannot enter the JSON-RPC response.
- Rebuilding does not delete or replace registry rows.
- Start reports a missing Apache instance instead of claiming success.

---

### Task 1: Catalog and generated-file contract

**Files:** `rpgle-mcp-server/mcplib/sql/SCHEMA.sql`, `rpgle-mcp-server/mcplib/tests/test_source_contract.py`

**Interfaces:** `MCPCAT` maps `SRVID` to `CFGFILE` and `TOOLFILE`; `MCPCFGT` and `MCPTOOLT` are empty table templates.

- [x] Write source-contract tests for object names, uniqueness, states, and per-server file mapping; run them red.
- [x] Create the DDL with one-time setup semantics; run the tests green.

### Task 2: CGI registry and independent handler programs

**Files:** `mcplib/rpg/MCPHTTP.sqlrpgle`, `MCPREG.sqlrpgle`, `MCPJSON.sqlrpgle`, `MCSYSINF.sqlrpgle`, `MCLIBLST.sqlrpgle`, `mcplib/copy/MCPABI.rpgleinc`, test file.

**Interfaces:** `MCPREG` exports `resolveServer`, `listRegisteredTools`, and `callRegisteredTool`; handlers use four by-reference arguments (8192, 8192, int32, int32).

- [x] Write tests for server scoping, fixed handler interface, no static tool router, and response limits; run them red.
- [x] Implement the CGI/registry and two sample handlers; run the tests green.

### Task 3: DDS administration commands

**Files:** `mcplib/dds/MCPSRVD.dspf`, `MCPTOOLD.dspf`, `mcplib/rpg/MCPSRVAD.sqlrpgle`, `MCPTOOAD.sqlrpgle`, `MCPSRVOP.sqlrpgle`, `mcplib/cmd/*.cmd`, test file.

**Interfaces:** `CRTMCPSRV` and `CHGMCPSRV` invoke `MCPSRVAD`; `ADDMCPTOOL`, `EDTMCPTOOL`, and `RMVMCPTOOL` invoke `MCPTOOAD`; `STRMCPSRV` and `ENDMCPSRV` invoke `MCPSRVOP`.

- [x] Write tests for the seven command definitions and DDS object wiring; run them red.
- [x] Implement validation, per-server file creation, one-row tool registration, activation/retirement, and start/stop wrappers; run the tests green.

### Task 4: IFS and CL build entry points, learning guide

**Files:** `mcplib/Makefile`, `mcplib/cl/BLDMCPLIB.clle`, `mcplib/README.md`, test file.

**Interfaces:** `make schema` is one-time; `make app` rebuilds program/display/command objects without touching data; `make check` runs local source checks; CL driver performs the same object compilation from IFS paths.

- [x] Write tests for consistent build object ordering and non-destructive rebuild; run them red.
- [x] Add Makefile, CL driver, and documentation, then run all local tests green.

### Task 5: Review and release readiness

- [x] Inspect all new source for IBM i name, SQL, and RPG call-interface consistency.
- [x] Run source-contract tests, Makefile dry run, and `git diff --check`. The existing HTTP smoke script requires a live IBM i endpoint and is deferred.
- [x] Record that IBM i compile and HTTP tests are pending until a partition is available.

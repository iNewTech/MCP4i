# MCPLIB multi-server application design

**Status:** implementation brief approved by the user's “let's execute the plan” request. This document supersedes the earlier single-server `CRTTOOL` draft for the new `mcplib/` tree. The existing tutorial in `rpgle-mcp-server/` remains available.

## User workflow

An IBM i administrator creates a named server with `CRTMCPSRV` on a DDS screen, then registers independent read-only handler `*PGM` objects with `ADDMCPTOOL`. `EDTMCPTOOL` can publish a reviewed handler; `RMVMCPTOOL` retires one immediately. `CHGMCPSRV` edits the server's saved settings. `STRMCPSRV` and `ENDMCPSRV` control the matching IBM HTTP Server instance; they do not submit the CGI program as a batch job.

One application library, `MCPLIB`, contains the commands, shared CGI program, catalog, screen programs, and all server-specific physical files. A server has a friendly display name and a separate system ID of at most ten characters. Each server receives its own Apache instance, port, `Snnnnnnn` configuration table and `Tnnnnnnn` tool table. Every instance calls the same `MCPHTTP` `*PGM` and sets its trusted `MCP_SERVER_ID`; the CGI chooses that server's registry. The shared CGI service profile is the selected first-version deployment model; separate tables and instances are logical isolation, **not** separate IBM i authority domains.

## Runtime contract

Apache passes a fixed server ID through `SetEnv MCP_SERVER_ID`; the CGI program rejects a missing, malformed, or unknown ID. `initialize` identifies that server. `tools/list` pages through active READ rows from its own `Tnnnnnnn` table using an MCP cursor. `tools/call` resolves a name only inside the same table, validates that `params.arguments` is a bounded JSON object, and invokes the registered, explicitly qualified `*PGM`. The CGI program never accepts a handler program name from a client. Each handler receives four by-reference arguments: fixed 8192-byte argument JSON, fixed 8192-byte result JSON, four-byte result length, and four-byte status. It returns a JSON payload, not HTTP headers or a JSON-RPC envelope. The CGI program checks status, length, and JSON syntax before wrapping the payload in MCP `content`.

The first two handlers implement `get_system_info` and `get_library_list` as separate programs. More tools are independently compiled programs using the same ABI. A program with a different positional parameter signature needs an adapter program matching this ABI; source mapping and automatic adapter generation are reserved for a later milestone. A program name alone cannot safely describe an arbitrary call signature.

## Administration and data

`MCPSERVERS` assigns unique server IDs, ports, and generated physical-file names. `MCPCFGT` and `MCPTOOLT` are templates used to create per-server tables; actual rows live in the generated tables. A server starts in `D` (draft). Tool states are `D` (draft), `A` (active), and `X` (retired). Only level `R` can be activated in this version, regardless of a server's recorded maximum `R`, `W`, or `D` capability. This policy metadata does not prove a handler is read-only: the administrator must review the program and its IBM i authority before publishing. The CGI profile needs read access to registry data and execute access to reviewed handlers, not update access to the catalog.

The first DDS tool screen collects public name, description, qualified handler, capability, and up to three flat argument definitions. `ADDMCPTOOL` accepts an optional `TOOL` parameter to prefill the name; the name is required when saving. `EDTMCPTOOL` and `RMVMCPTOOL` require the existing name, and edit does not rename a tool. The screen generates an `inputSchema`; semantic argument validation belongs to the handler, while the CGI program checks the JSON envelope and size. The generated schema is limited to flat `string`, `integer`, `number`, and `boolean` fields. Tool metadata stays in one row to avoid partial multi-row registration. Edit uses saved field columns to regenerate the schema. Changes to an active handler or schema require saving a draft and republishing after review. Retire is a soft state change and takes effect on the next request.

## Scope of this implementation

This implementation supplies the application source, SQL templates, DDS screens, command definitions, two sample handlers, an IFS Makefile, and an equivalent CL compile driver. The build must preserve existing registry rows on rebuild. Apache instance creation and configuration, per-server library-list application, authority grants, live compilation, and deployment verification are the next infrastructure milestone. Until an instance is provisioned, `STRMCPSRV` must report that it cannot start it. No workstation-only check may be presented as proof of IBM i compilation or running behavior.

## Acceptance

On an IBM i development partition: compile all objects; create two server records in one library with distinct ports and files; add and publish a reviewed no-argument handler; verify that only its server lists it and can call it; reject a draft, retired, non-READ, malformed-JSON, and unknown tool; confirm rebuild preserves rows. Apache provisioning and end-to-end HTTP acceptance follow the infrastructure milestone.

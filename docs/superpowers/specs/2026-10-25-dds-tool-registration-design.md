# DDS tool registration for the RPGLE MCP server

**Status:** proposed design for review. No implementation is implied by this document.

## Intent

An IBM i developer should be able to create an MCP tool without editing the CGI request handler or rebinding the main server program. They will define the tool on a familiar 5250 DDS screen, compile an independent RPG handler program, and register that program. The server will discover enabled metadata from Db2 for i and invoke the matching handler for `tools/call`.

This extends the current [RPGLE server](../../../rpgle-mcp-server/README.md), where `MCPHTTP` has a hard-coded two-tool registry and statically bound tool modules. The first implementation is still a learning sample: it has not yet been compiled on IBM i.

## Goals, boundaries, and calls made for this design

- `CRTTOOL` launches **our own DDS display file** and RPG controller, not IBM i's automatic F4 command prompt. The DDS screen is the user's chosen approach.
- An administrator can enter name, description, qualified handler program, and simple input fields; the controller validates them and stores one registry row in Db2.
- A new independently compiled `*PGM` handler can become available without changing the `MCPHTTP` source or rebinding it.
- Only enabled tools appear in `tools/list` and can run through `tools/call`.
- The first version remains read-only. The screen is administrative and writes only the MCP registry; an exposed tool must not modify business data, objects, or job state.
- The first version supports simple flat input fields. Arbitrary nested JSON Schema, a raw SQL tool, CL execution, plugin installation, and automatic generation of handler code are outside scope.

**Design calls to review:** Newly created tools start disabled; an administrator activates them after checking the handler. The server wraps a handler's JSON payload into the MCP `content` result. Complex argument schemas can be added only with a validator that enforces them at call time.

For the first version, handlers must reside in one dedicated `MCPHDL` library. The screen displays that library and accepts a program name; it does not permit choosing another library. An administrator controls which programs can be created in `MCPHDL` and which profiles can run `ACTTOOL`. This fixed-library rule is a conservative starting trust boundary; per-program allowlisting can be added later if needed.

## Approaches considered

1. **Native command prompting:** `CRTTOOL` with command-definition parameters would get an F4 prompt cheaply, but it is not the custom DDS screen requested.
2. **DDS screen + Db2 registry + independent `*PGM` handlers (chosen):** Familiar interactive workflow, no source changes for new tools, and a clear separation between registration and execution. It requires a stable program-call interface and careful authority checks.
3. **DDS screen + statically bound modules:** Easier to preserve the existing two tools, but every new tool would still require `MCPHTTP` prototypes/router changes and a new bind. That defeats the main ease-of-use goal.

## Developer workflow

```text
Write and compile a read-only RPG handler *PGM
                  ↓
Run CRTTOOL → DDS entry screen → parameter subfile → validate → save disabled
                  ↓
Admin reviews handler and registry entry → ACTTOOL enables it
                  ↓
MCP tools/list reads enabled rows; tools/call looks up one row and invokes its *PGM
```

The `CRTTOOL` command is a small launcher for an interactive RPG program. That program opens a DDS display file. `CRTTOOL` does not call the handler or start the HTTP server. A separate `ACTTOOL` administrative command changes the state after validation; there is no automatic execution while someone is filling in the screen.

### Screen layout

```text
Create MCP Tool (CRTTOOL)

MCP name . . . . . . . . .  get_job_status
Description  . . . . . . .  Read the state of one authorized job
                             (continuation line)
Handler library  . . . . .  MCPHDL  (fixed)
Handler program  . . . . .  JOBSTAT

Input fields  (F6=Add, F11=Details)
  Name             Type       Required   Description
  job_id           string     Y          Qualified number/user/name

F3=Exit  F12=Cancel  Enter=Validate and save
```

The main screen collects stable IBM i object names and the MCP public name. A parameter subfile collects one flat argument per row: name, type (`string`, `integer`, `number`, or `boolean`), required flag, and short description. This is easier to use and validate on 5250 than editing raw multi-line JSON. The controller generates the MCP `inputSchema` object with `additionalProperties:false` and stores the resulting JSON. An optional advanced JSON editor is deferred, because storing arbitrary schema text without validating incoming calls would mislead clients about what the server enforces.

On Enter, the controller checks the MCP name format/length and uniqueness, description length, fixed handler library and program name, duplicate argument names, supported types, required flags, generated schema size and syntax, and whether the handler exists as a `*PGM` in `MCPHDL`. Invalid input stays on the screen with a field-specific message. F12 exits without a row. Creating a row does not grant execution authority or enable the tool.

## Db2 registry

One `MCP4I.MCPTOOLS` SQL table is the source of truth for discovery and routing. Initial columns:

| Column | Purpose |
| --- | --- |
| `TOOL_NAME` | Unique lower-case MCP name; primary key. |
| `DESCRIPTION` | Public description shown to the model. |
| `HANDLER_LIBRARY`, `HANDLER_PROGRAM` | Explicit qualified `*PGM` identity; never `*LIBL`. |
| `INPUT_SCHEMA_JSON` | Generated MCP input schema, stored as bounded JSON text. |
| `STATE` | `D` draft/disabled or `A` active. |
| `CREATED_BY`, `CREATED_AT`, `CHANGED_BY`, `CHANGED_AT` | Administrative trace. |

The SQL DDL constrains names, state, sizes, and JSON syntax, so direct inserts cannot bypass every screen check. The controller validates MCP-specific semantics before saving. We may add version and approved metadata columns later; no secrets are stored in JSON. The input field rows can live in a separate `MCPTOOLPARM` table **or** be rebuilt from the generated JSON on edit; for the first version, preserve structured rows so an edit screen can round-trip them without parsing an arbitrary schema. The schema JSON remains the authoritative MCP representation.

## Handler program interface

Every registered handler is a separately compiled ILE `*PGM` with the same by-reference parameters, for example:

```text
request JSON buffer (fixed maximum, includes only validated tool arguments)
response JSON buffer (fixed maximum, tool payload only)
response length
status code (success, invalid input, denied, unavailable, internal failure)
```

The exact RPG declarations and buffer sizes belong in one shared `/COPY` member used by the server and sample handlers. A handler must set response length and status on every path. The server initializes buffers, rejects an overlong or malformed result, and wraps a successful payload with the existing MCP text-result formatter. It converts a handler failure to an MCP `isError:true` result without leaking job-log diagnostics. A handler does **not** print HTTP headers or produce the whole JSON-RPC envelope.

`MCPHTTP` resolves a registered library/program name and performs a dynamic program call using a variable `EXTPGM` name; IBM documents that this is supported and that program parameters are passed by reference. The handler's qualified name comes only from an active trusted row, never directly from model arguments. [IBM `EXTPGM` reference](https://www.ibm.com/docs/en/i/7.5.0?topic=keywords-extpgmname)

## Runtime flow and activation

1. `tools/list` queries only active rows in a deterministic order, encodes each name/description as JSON, and includes the stored `inputSchema` as a JSON object. It enforces a tool-count and response-size limit. It does not call handlers.
2. `tools/call` reads the active row by exact tool name, parses `params.arguments`, validates their structure and the supported flat fields, confirms the handler's qualified identity and authority, and calls the handler. It enforces request and result size limits.
3. The registry is read per request in the first version, so no process restart is needed for a newly active row. A connected client may have cached `tools/list`; because this CGI server has no outbound notification channel, a user may need to reconnect or refresh that client's tool list. We will not advertise `tools.listChanged` until notifications actually work.
4. Disabling a row prevents new calls. An in-flight call may complete; activation/deactivation is not a cancellation mechanism.

The current `SYSINFO` and `LIBLIST` modules should be adapted into two example standalone handler programs and registered as active seed rows when the new path is proven. Until then, keep the existing static path working during migration. Remove it only after both tools pass the live smoke test through the registry; avoid advertising duplicates.

## Authority and read-only boundary

The admin screen runs under an authorized interactive profile. CGI jobs get read access to the registry and execute authority only for the dedicated `MCPHDL` handler library and reviewed programs; they do not get registry write access. Only trusted administrators can install programs into `MCPHDL` or run `ACTTOOL`. The server uses explicit library qualification and does not accept a handler path from a tool call. `ACTTOOL` requires administrative authority and verifies that the target is an existing `MCPHDL` program; a program object's existence cannot by itself prove that it follows the documented interface or is read-only. Every handler still needs code review, authority review, and a bounded read strategy: a database row marked active does not make an arbitrary program read-only.

The registry stores public metadata, not credentials. Treat descriptions and returned data as untrusted content. Limit result size and avoid exposing raw SQL errors, credentials, or job logs. Record admin changes and safe call metadata for audit without logging tool arguments by default.

## Build, verification, and delivery

Add DDS source and compile it with `CRTDSPF`; add SQL DDL for the registry; compile the interactive RPG controller and two administrative commands; compile sample handler programs; update `MCPHTTP` to use the registry. IBM documents [DDS display files](https://www.ibm.com/docs/en/i/7.5.0?topic=files-defining-display-file-dds) and [CRTDSPF](https://www.ibm.com/docs/en/i/7.4.0?topic=ssw_ibm_i_74%2Fcl%2Fcrtdspf.html). The deployment guide must show the build order, program authorities, sample registration, activation, and HTTP start sequence.

The workstation can check source conventions and exercise protocol behavior with a fake registry/handler test harness. Real acceptance needs an authorized IBM i partition: compile all objects; use the screen to create a valid and invalid tool; confirm no row after cancel/error; confirm disabled tools are absent; activate a reviewed handler; verify `tools/list` and `tools/call`; check malformed args, missing/unauthorized program, overlong response, deactivation, and no restart required. The repository currently has no IBM i connection, so no local check can establish that RPG/DDS/SQL compilation succeeds.

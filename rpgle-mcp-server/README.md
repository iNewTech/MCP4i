# RPGLE MCP server: one program, separate tool modules

This folder is the first **MCP server written in ILE RPG** in MCP4i. It is not a Python or TypeScript MCP server calling an RPG program. IBM HTTP Server for i receives `POST /mcp`, invokes the RPG program as CGI, and the RPG program parses MCP JSON-RPC, lists its tools, reads Db2 for i, and writes the MCP response.

**Status:** source and deployment recipe are ready for an IBM i development partition. This repository has not compiled or run the program on a partition yet. The live smoke test is the acceptance gate; do not treat this sample as production-verified.

## Files and reading order

| Read | What it does |
| --- | --- |
| [MCPHTTP.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle) | CGI entry module: HTTP, JSON-RPC, tool registry and routing. |
| [SYSINFO.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/SYSINFO.sqlrpgle) | `get_system_info` definition, handler, and fixed query. |
| [LIBLIST.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/LIBLIST.sqlrpgle) | `get_library_list` definition, handler, and bounded query. |
| [MCPJSON.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPJSON.sqlrpgle) | Shared MCP text-result formatter. |
| [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) | Directives to add to a dedicated IBM HTTP Server instance. |
| [smoke_test.py](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) | Tests the **deployed** RPG endpoint from a machine with Python 3.10+. No Python runs on IBM i for this server. |
| [Phase 1 tool roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) | Planned later tools and read-only limits. |

## Architecture

```text
MCP client ── POST /mcp ──> IBM HTTP Server for i
                               │ invokes CGI
                               ▼
                    MCP4I/MCPHTTP *PGM
                    ├─ MCPHTTP module: CGI, JSON-RPC, tool registry
                    ├─ SYSINFO module: get_system_info
                    ├─ LIBLIST module: get_library_list
                    └─ MCPJSON module: shared result formatting
                               │ JSON response
                               ▼
                            MCP client
```

These are **four statically bound ILE modules in one `*PGM`**, not four separately running servers. Only `MCPHTTP` has a main procedure. Each tool module exports one metadata procedure and one handler; its SQL read stays private. `tools/list` invokes metadata only, while `tools/call` routes a registered name to its handler. Adding a tool does not change the generic HTTP or JSON-RPC procedures.

The sample implements the **2025-11-25 MCP Streamable HTTP request/response subset**: `initialize`, `notifications/initialized`, `ping`, `tools/list`, and `tools/call`. It returns HTTP 202 for the initialization notification. It has no SSE, sessions, prompts, resources, batching, or arbitrary commands. `GET /mcp` returns 405.

`get_library_list` reads [QSYS2.LIBRARY_LIST_INFO](https://www.ibm.com/support/pages/qsys2librarylistinfo) for the **current CGI request job**, not the user's separate interactive job. It returns at most 40 ordered entries plus a count and `truncated` flag. Both tools use fixed queries and take no arguments.

## Prerequisites

- An authorized **IBM i 7.4/7.5/7.6 development partition** with IBM HTTP Server for i, ILE RPG compiler, and Db2 for i SQL development tools. Confirm installed product/PTF levels for your release before compiling.
- Ability to create a library, program, HTTP instance, job queue, class, and subsystem. Run setup with an administrator profile, then use the restricted HTTP/CGI profiles at runtime.
- A way to copy the repository to the IBM i IFS, such as `scp` over SSH or ACS IFS. No Ollama or paid model API is needed for the server itself.
- A local machine with Python 3.10+ for the smoke test. Python is only a test client.

IBM documents [RPG CGI support and the QZHBCGI binding requirement](https://www.ibm.com/docs/en/i/7.6.0?topic=api-cgi-apis), [CRTSQLRPGI with source stream files](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcrtsqlrpgi.htm), and [custom HTTP server subsystems and job queues](https://www.ibm.com/support/pages/node/645335).

## 1. Put the source on IBM i

From your workstation, clone or copy the repo to an IFS directory that your build profile can read. Example with SSH enabled:

```sh
ssh builduser@your-ibmi 'mkdir -p /home/builduser/MCP4i'
scp rpgle-mcp-server/*.sqlrpgle builduser@your-ibmi:/home/builduser/MCP4i/
```

The compile commands assume `/home/builduser/MCP4i/`; change that path if yours differs. The Git checkout and source file are build inputs; the installed program is the `*PGM` object in `MCP4I`.

## 2. Create a library and dedicated server jobs

In a 5250 command line with setup authority, run these **once**. Names are IBM i system names of at most ten characters. Size the pool and job limits for your development partition; these are sample values.

```cl
CRTLIB LIB(MCP4I) TEXT('MCP4i RPG HTTP server')
CRTJOBQ JOBQ(MCP4I/MCPJOBQ) TEXT('MCP HTTP jobs')
CRTJOBD JOBD(MCP4I/MCPJOBD) JOBQ(MCP4I/MCPJOBQ) USER(QTMHHTTP) RTGDTA(MCPHTTP) JOBMSGQFL(*WRAP)
CRTCLS CLS(MCP4I/MCPCLS) RUNPTY(25) TEXT('MCP HTTP job class')
CRTSBSD SBSD(MCP4I/MCPSBS) POOLS((1 256 50 *MB)) MAXJOBS(20) TEXT('MCP HTTP subsystem')
ADDJOBQE SBSD(MCP4I/MCPSBS) JOBQ(MCP4I/MCPJOBQ) MAXACT(20) SEQNBR(10)
ADDRTGE SBSD(MCP4I/MCPSBS) SEQNBR(10) CMPVAL(MCPHTTP) PGM(QSYS/QCMD) CLS(MCP4I/MCPCLS)
```

`MCPJOBQ` queues this HTTP instance's jobs; `MCPSBS` runs them; `MCPJOBD` and `MCPCLS` select routing and execution attributes. These are **HTTP server jobs**, not one submitted `MCPHTTP` job. The HTTP directives in [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) connect the instance to these objects. IBM specifically requires the custom job queue and an **active** subsystem for HTTP jobs to run outside `QHTTPSVR` ([IBM setup procedure](https://www.ibm.com/support/pages/node/645335)). The dedicated subsystem helps isolate and monitor this instance; it is not an MCP protocol requirement.

## 3. Compile and bind the RPG program

Run this on IBM i from the build profile. The SQL precompiler creates four modules; `CRTPGM` binds them into one program with the CGI API service program. Only `MCPHTTP` has the main procedure. Each tool module uses `ctl-opt nomain` and exports its metadata and handler procedures. The source uses only the local database (`RDB(*NONE)`), so it does not need a distributed SQL package.

```cl
CRTSQLRPGI OBJ(MCP4I/MCPHTTP) SRCSTMF('/home/builduser/MCP4i/MCPHTTP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTSQLRPGI OBJ(MCP4I/MCPJSON) SRCSTMF('/home/builduser/MCP4i/MCPJSON.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTSQLRPGI OBJ(MCP4I/SYSINFO) SRCSTMF('/home/builduser/MCP4i/SYSINFO.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTSQLRPGI OBJ(MCP4I/LIBLIST) SRCSTMF('/home/builduser/MCP4i/LIBLIST.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTPGM PGM(MCP4I/MCPHTTP) MODULE(MCP4I/MCPHTTP MCP4I/MCPJSON MCP4I/SYSINFO MCP4I/LIBLIST) BNDSRVPGM(QHTTPSVR/QZHBCGI)
```

`CRTPGM` resolves the exported calls across modules; no service program is created for the tools. IBM explains [binding modules](https://www.ibm.com/docs/en/i/7.5.0?topic=steps-using-binder-create-program). If the compiler reports an error, read its listing/job log before proceeding; IBM i RPG and Db2 PTF levels may require source adjustments. This has not been compiled here because the workspace has no IBM i partition.

Give HTTP server and CGI profiles only the authority needed to traverse the library and execute this program. Review local security policy before changing authorities:

```cl
GRTOBJAUT OBJ(MCP4I) OBJTYPE(*LIB) USER(QTMHHTTP) AUT(*USE)
GRTOBJAUT OBJ(MCP4I) OBJTYPE(*LIB) USER(QTMHHTP1) AUT(*USE)
GRTOBJAUT OBJ(MCP4I/MCPHTTP) OBJTYPE(*PGM) USER(QTMHHTP1) AUT(*USE)
```

The fixed [SYSIBMADM.ENV_SYS_INFO](https://www.ibm.com/docs/ssw_ibm_i_76/rzajq/rzajqviewenvinfo.htm) and [QSYS2.LIBRARY_LIST_INFO](https://www.ibm.com/support/pages/qsys2librarylistinfo) views require no additional view authority. Do not grant broad object or data authority simply to make a failing CGI request work.

## 4. Create and configure the HTTP instance

Start the Web Administration instance if it is not already running:

```cl
STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)
```

In **IBM Web Administration for i**, use **Setup → Create HTTP Server** to create a dedicated IBM HTTP Server (Apache) instance named `MCP4I`. Choose a server root and local test port, then open the instance's configuration and add the directives in [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example). If the wizard already wrote `Listen` or `ServerName`, edit those lines rather than adding duplicates. Verify that `MCP4I/MCPSBS`, `MCP4I/MCPJOBQ`, `MCP4I/MCPJOBD`, and `MCP4I/MCPCLS` exist first. IBM documents the [instance wizard](https://www.ibm.com/docs/en/i/7.5?topic=tasks-getting-started) and [ILE CGI URL mapping](https://www.ibm.com/docs/en/i/7.4?topic=programming-setting-up-cgi-programs).

The key `ScriptAlias /mcp /QSYS.LIB/MCP4I.LIB/MCPHTTP.PGM` directive tells Apache which RPG program handles the MCP URL. This program is ordinary ILE CGI, so Nginx is not needed to invoke it; Nginx could later reverse-proxy the HTTP endpoint, but its `fastcgi_pass` expects a separate FastCGI server ([Nginx guide](https://nginx.org/en/docs/beginners_guide.html)).

This example listens only on IBM i loopback port **8088**, permits local CGI requests, and rejects any HTTP `Origin` header in RPG. It deliberately cannot be reached directly from the internet. For external clients, add a managed TLS/authentication reverse proxy after the local test and define a permitted origin policy for your deployment. Do not remove the loopback/access controls just to make an MCP client connect.

The HTTP server converts network UTF-8 JSON to the CGI job CCSID and back using `DefaultNetCCSID 1208`, `CGIJobCCSID 37`, and `CGIConvMode EBCDIC`. Check the CCSID choice for your partition; IBM explains [CGI conversion modes](https://www.ibm.com/docs/en/i/7.5.0?topic=programming-cgi-data-conversions).

## 5. Start, inspect, and stop

The RPG program is **not** a long-running socket listener. The HTTP instance owns the listener. IBM identifies `QZSRHTTP` as a request-handling job and `QZSRCGI` as a CGI job; there may be several CGI jobs. For each matching `/mcp` request, a CGI job invokes `MCPHTTP`, which reads that request and returns its MCP response ([IBM CGI job overview](https://www.ibm.com/support/pages/node/1171114)). Start the dedicated subsystem before the HTTP instance:

```cl
STRSBS SBSD(MCP4I/MCPSBS)
STRTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)
WRKACTJOB SBS(MCPSBS) JOB(MCP4I)
WRKJOBQ JOBQ(MCP4I/MCPJOBQ)
```

There is no `SBMJOB` step for the RPG program. `SBMJOB CMD(CALL MCP4I/MCPHTTP)` has no CGI request body or HTTP environment and cannot listen for MCP clients. The dedicated job queue is for the HTTP instance's jobs, which `STRTCPSVR` starts. Use `STRTCPSVR` / `ENDTCPSVR` to control the instance ([IBM HTTP command reference](https://www.ibm.com/docs/en/i/7.4.0?topic=ssw_ibm_i_74%2Fcl%2Fstrtcpsvr.html)).

```cl
ENDTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)
ENDSBS SBS(MCPSBS) OPTION(*CNTRLD) DELAY(60)
```

If startup or a tool call fails, check the HTTP instance error log and CGI job log. IBM identifies CGI jobs by program `QZSRCGI`; in this setup inspect them in `MCPSBS` ([IBM CGI troubleshooting](https://www.ibm.com/support/pages/node/1171114)).

## 6. Verify the live server

On IBM i PASE, `curl` can access `http://127.0.0.1:8088/mcp` directly. From your workstation, tunnel first if SSH is available:

```sh
ssh -N -L 8088:127.0.0.1:8088 builduser@your-ibmi
```

In another workstation terminal, from the repository root:

```sh
python3 rpgle-mcp-server/smoke_test.py http://127.0.0.1:8088/mcp
```

The script checks initialize, the initialized notification, discovery of both tools, **live** system-info and library-list reads, rejection of an unimplemented tool, malformed JSON, Origin rejection, and the unsupported GET method. It fails if the Db2 read fails. Do not paste real system identifiers from its output into a public issue or commit.

For a visual client, point the latest MCP Inspector at the **HTTP URL** rather than launching `mcp dev` on an RPG file. Inspector is a client; the IBM HTTP instance is the server. A chat application will only see this tool when its MCP settings explicitly register a reachable endpoint. External ChatGPT/Claude access also depends on that application's supported MCP transport and deployment/authentication model; neither app automatically discovers a server from the repository.

## How the code works

Start in [MCPHTTP.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle). `handleRequest` connects three stages: `readHttpRequest` validates CGI input, `parseRpcRequest` extracts JSON-RPC fields, and `dispatchRpcRequest` handles MCP methods. `listTools` is the **tool registry**; `callRegisteredTool` is the **tool router**. Neither contains tool-specific SQL.

The metadata and handler for `get_system_info` are in [SYSINFO.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/SYSINFO.sqlrpgle). The corresponding procedures for `get_library_list` are in [LIBLIST.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/LIBLIST.sqlrpgle). Each `get...Tool` procedure returns the tool's public name, description, and input schema. Each `run...Tool` procedure calls a private fixed Db2 read and wraps its result using [MCPJSON.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPJSON.sqlrpgle). Discovery does not run a query.

### Add another read-only tool

1. Create a new `TOOLNAME.sqlrpgle` module following `LIBLIST`: use `ctl-opt nomain`, export a `get...Tool` metadata procedure and a `run...Tool` handler, and keep the bounded read private.
2. Add matching prototypes to `MCPHTTP` near the existing tool prototypes. RPG return and parameter types must match exactly across modules.
3. Add the metadata result to the next `toolList(n)` entry in `listTools` and increase `toolCount`. The loop inserts commas and returns the `tools` array.
4. Add one `WHEN` for its exact name to `callRegisteredTool`, invoking its handler. **Do not edit** `readHttpRequest`, `parseRpcRequest`, or `dispatchRpcRequest` to add a tool.
5. Compile the new module with `CRTSQLRPGI`, include it in `CRTPGM MODULE(...)`, and extend the live smoke test for discovery, success, errors, and result limits.

For example, a future job-status module would add `toolList(3) = getJobStatusTool();` and `toolCount = 3;` in `listTools`, plus `when requestedTool = 'get_job_status'; toolResult = runJobStatusTool();` in the router. This sample currently handles **no-argument tools only**. A tool that takes arguments must also parse and validate them before calling its handler; never pass model-supplied SQL or CL straight through.

## Boundaries and next milestone

This is a learning implementation with two read-only tools. It does not implement `run_sql`, `run_cl`, `run_program`, job submission, or object changes. A tool annotation or name is not a security boundary; the fixed SQL, bounds, and runtime authorities are. Before exposing a non-loopback endpoint, review authentication, TLS, rate limits, audit, caller-specific authority, request deadlines, and client compatibility on the actual partition. The next step is to **compile and run the smoke test on an authorized IBM i development partition**, then record its release/PTF level and required corrections.

### References

- [MCP 2025-11-25 Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP 2025-11-25 lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [MCP 2025-11-25 tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [IBM i CGI APIs](https://www.ibm.com/docs/en/i/7.6.0?topic=api-cgi-apis)
- [IBM ILE RPG CGI example](https://www.ibm.com/support/pages/ile-rpg-cgi-programming-example)
- [IBM HTTP instance in a dedicated subsystem](https://www.ibm.com/support/pages/node/645335)
- [IBM Db2 for i JSON overview](https://www.ibm.com/docs/en/i/7.6.0?topic=data-json-concepts)

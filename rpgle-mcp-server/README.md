# RPGLE MCP server: one program, one read-only tool

This folder is the first **MCP server written in ILE RPG** in MCP4i. It is not a Python or TypeScript MCP server calling an RPG program. IBM HTTP Server for i receives `POST /mcp`, invokes the RPG program as CGI, and the RPG program parses MCP JSON-RPC, lists its tool, reads Db2 for i, and writes the MCP response.

**Status:** source and deployment recipe are ready for an IBM i development partition. This repository has not compiled or run the program on a partition yet. The live smoke test is the acceptance gate; do not treat this sample as production-verified.

## Files and reading order

| Read | What it does |
| --- | --- |
| [MCPHTTP.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle) | The only RPGLE program. Handles HTTP CGI, MCP requests, JSON, and `get_system_info`. |
| [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) | Directives to add to a dedicated IBM HTTP Server instance. |
| [smoke_test.py](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) | Tests the **deployed** RPG endpoint from a machine with Python 3.10+. No Python runs on IBM i for this server. |
| [Phase 1 tool roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) | Planned later tools and read-only limits. |

## Architecture

```text
MCP client (Inspector, app, or CLI)
    │ POST JSON-RPC to /mcp
    ▼
IBM HTTP Server for i — instance MCP4I, jobs in MCP4I/MCPSBS
    │ CGI request body + environment
    ▼
MCP4I/MCPHTTP *PGM (ILE RPG)
    ├── readHttpRequest → parseRpcRequest → dispatchRpcRequest
    ├── tools/list → listTools → getSysInfoTool (tool definition)
    └── tools/call → runSysInfoTool → readSysInfo (fixed SELECT)
                                    → asTextToolResult
    │ CGI JSON response
    ▼
MCP client displays the tool result to the model
```

The program implements the **2025-11-25 MCP Streamable HTTP request/response subset**: `initialize`, `notifications/initialized`, `ping`, `tools/list`, and `tools/call`. It returns JSON for requests and HTTP 202 for the initialization notification. There is no SSE stream, session ID, prompt, resource, batching, or arbitrary command execution in this slice. `GET /mcp` returns 405. This is intentionally one tool and one RPG program, not the entire Phase 1 catalogue.

After initialization, a tool call looks like this on the wire:

```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_system_info","arguments":{}}}
```

The RPG program returns the same `id` with an MCP `result.content` text item containing a JSON object from the fixed system-information view. `tools/list` supplies the name and input schema the client shows to the model. The model does not discover the RPG program from its filename; an MCP client must register the HTTP endpoint.

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
scp rpgle-mcp-server/MCPHTTP.sqlrpgle builduser@your-ibmi:/home/builduser/MCP4i/
```

The subsequent compile command assumes `/home/builduser/MCP4i/MCPHTTP.sqlrpgle`; change that path if yours differs. The Git checkout and source file are build inputs; the installed program is the `*PGM` object in `MCP4I`.

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

`MCPJOBQ` queues this HTTP instance's jobs; `MCPSBS` runs them; `MCPJOBD` and `MCPCLS` select routing and execution attributes. The HTTP directives in [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) connect the instance to these objects. IBM specifically requires the custom job queue and an **active** subsystem for HTTP jobs to run outside `QHTTPSVR` ([IBM setup procedure](https://www.ibm.com/support/pages/node/645335)).

## 3. Compile and bind the RPG program

Run this on IBM i from the build profile. The SQL precompiler creates a module; `CRTPGM` binds it to the CGI API service program. The source uses only the local database (`RDB(*NONE)`), so it does not need a distributed SQL package.

```cl
CRTSQLRPGI OBJ(MCP4I/MCPHTTP) SRCSTMF('/home/builduser/MCP4i/MCPHTTP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTPGM PGM(MCP4I/MCPHTTP) MODULE(MCP4I/MCPHTTP) BNDSRVPGM(QHTTPSVR/QZHBCGI)
```

If the compiler reports an error, read its listing/job log before proceeding; IBM i RPG and Db2 PTF levels may require source adjustments. This has not been compiled here because the workspace has no IBM i partition.

Give HTTP server and CGI profiles only the authority needed to traverse the library and execute this program. Review local security policy before changing authorities:

```cl
GRTOBJAUT OBJ(MCP4I) OBJTYPE(*LIB) USER(QTMHHTTP) AUT(*USE)
GRTOBJAUT OBJ(MCP4I) OBJTYPE(*LIB) USER(QTMHHTP1) AUT(*USE)
GRTOBJAUT OBJ(MCP4I/MCPHTTP) OBJTYPE(*PGM) USER(QTMHHTP1) AUT(*USE)
```

The fixed `SYSIBMADM.ENV_SYS_INFO` view [requires no additional view authority](https://www.ibm.com/docs/ssw_ibm_i_76/rzajq/rzajqviewenvinfo.htm). Do not grant broad object or data authority simply to make a failing CGI request work.

## 4. Create and configure the HTTP instance

In **IBM Web Administration for i**, create a dedicated IBM HTTP Server instance named `MCP4I`. Open its configuration and add the directives in [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example). If the wizard already wrote `Listen` or `ServerName`, edit those lines rather than adding duplicates. Verify that `MCP4I/MCPSBS`, `MCP4I/MCPJOBQ`, `MCP4I/MCPJOBD`, and `MCP4I/MCPCLS` exist first.

This example listens only on IBM i loopback port **8088**, permits local CGI requests, and rejects any HTTP `Origin` header in RPG. It deliberately cannot be reached directly from the internet. For external clients, add a managed TLS/authentication reverse proxy after the local test and define a permitted origin policy for your deployment. Do not remove the loopback/access controls just to make an MCP client connect.

The HTTP server converts network UTF-8 JSON to the CGI job CCSID and back using `DefaultNetCCSID 1208`, `CGIJobCCSID 37`, and `CGIConvMode EBCDIC`. Check the CCSID choice for your partition; IBM explains [CGI conversion modes](https://www.ibm.com/docs/en/i/7.5.0?topic=programming-cgi-data-conversions).

## 5. Start, inspect, and stop

The RPG program is **not** a long-running socket listener. The HTTP instance owns the listener and invokes the RPG CGI program for each request. Start the dedicated subsystem before the HTTP instance:

```cl
STRSBS SBSD(MCP4I/MCPSBS)
STRTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)
WRKACTJOB SBS(MCPSBS) JOB(MCP4I)
WRKJOBQ JOBQ(MCP4I/MCPJOBQ)
```

If you need to start the HTTP instance from a batch job, submit the **start command** to an already running control queue after `STRSBS` (example only; use your site's approved control queue):

```cl
SBMJOB CMD(STRTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)) JOBQ(QGPL/QBATCH)
```

Do **not** submit `CALL MCP4I/MCPHTTP` with `SBMJOB`: it has no CGI request body or HTTP environment and cannot listen for MCP clients. Also do not submit this start command to `MCPJOBQ`; that queue is for the HTTP instance's workers. The supported start/stop interface is `STRTCPSVR` / `ENDTCPSVR` ([IBM HTTP command reference](https://www.ibm.com/docs/en/i/7.4.0?topic=ssw_ibm_i_74%2Fcl%2Fstrtcpsvr.html)).

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

The script checks initialize, the initialized notification, tool discovery, one **live** system-info read, rejection of an unimplemented tool, malformed JSON, Origin rejection, and the unsupported GET method. It fails if the Db2 read fails. Do not paste real system identifiers from its output into a public issue or commit.

For a visual client, point the latest MCP Inspector at the **HTTP URL** rather than launching `mcp dev` on an RPG file. Inspector is a client; the IBM HTTP instance is the server. A chat application will only see this tool when its MCP settings explicitly register a reachable endpoint. External ChatGPT/Claude access also depends on that application's supported MCP transport and deployment/authentication model; neither app automatically discovers a server from the repository.

## How the code works

Each subprocedure has one job. Start at [`handleRequest`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L115), which only connects these stages:

| Procedure | One responsibility |
| --- | --- |
| [`readHttpRequest`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L126) | Validate the HTTP request and read its bounded CGI body. |
| [`parseRpcRequest`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L187) | Parse JSON-RPC fields and preserve the JSON type of the request ID. |
| [`dispatchRpcRequest`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L247) | Route MCP methods, including `tools/list` and `tools/call`. |
| [`listTools`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L283) | Put tool definitions in the `tools/list` response. This is the **tool registry**. |
| [`getSysInfoTool`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L295) | Construct only the `get_system_info` name, description, and input schema. This is the **tool definition**. |
| [`runSysInfoTool`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L308) | Coordinate execution of that one tool and return an MCP tool result. |
| [`readSysInfo`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L326) | Run the fixed read of [ENV_SYS_INFO](https://www.ibm.com/docs/ssw_ibm_i_76/rzajq/rzajqviewenvinfo.htm); no caller-supplied SQL reaches this procedure. |
| [`asTextToolResult`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L349) | Escape the returned data and form the MCP `content` result. |
| [`getEnv`, `rpcError`, `sendHttp`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L373) | Handle CGI variables, JSON-RPC errors, and CGI output. |

The key distinction is **defining a tool versus running it**. `getSysInfoTool` makes the public contract; `readSysInfo` reads IBM i. In `listTools`, the line below makes the definition easy to find:

```rpgle
dcl-s sysInfoTool varchar(512);
sysInfoTool = getSysInfoTool();
return '{"tools":[' + sysInfoTool + ']}';
```

When the client calls `get_system_info`, the [`tools/call` router](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L262) maps that name to `runSysInfoTool`. To add another read-only tool later, give it one definition procedure and one execution procedure, add its definition to `listTools`, and add its name/handler pair to the router. Update the live smoke test to check that the new tool appears and works. Do not put the SQL query inside the metadata procedure: the client needs the description during discovery, but should read IBM i only when it calls the tool.

## Boundaries and next milestone

This is a learning implementation with one read-only tool. It does not implement `run_sql`, `run_cl`, `run_program`, job submission, or object changes. A tool annotation or name is not a security boundary; the fixed SQL and runtime authorities are. Before exposing a non-loopback endpoint, review authentication, TLS, rate limits, audit, caller-specific authority, request deadlines, and client compatibility on the actual partition. The next useful step is to **compile and run the smoke test on your IBM i development partition**, then record the release/PTF level and any required corrections here.

### References

- [MCP 2025-11-25 Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP 2025-11-25 lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [MCP 2025-11-25 tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [IBM i CGI APIs](https://www.ibm.com/docs/en/i/7.6.0?topic=api-cgi-apis)
- [IBM ILE RPG CGI example](https://www.ibm.com/support/pages/ile-rpg-cgi-programming-example)
- [IBM HTTP instance in a dedicated subsystem](https://www.ibm.com/support/pages/node/645335)
- [IBM Db2 for i JSON overview](https://www.ibm.com/docs/en/i/7.6.0?topic=data-json-concepts)

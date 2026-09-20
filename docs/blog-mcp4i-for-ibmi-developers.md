# MCP4i: Learning MCP by Building a Server in RPGLE

An IBM i developer may know how to inspect a library, program, file, or job, but a chat model cannot see the current state of that partition on its own.

<details>
<summary>Hinglish</summary>

IBM i developer library, program, file ya job inspect kar sakta hai, lekin chat model khud se us partition ki current state nahi dekh sakta.

</details>

I started [MCP4i](https://github.com/iNewTech/MCP4i) to learn the Model Context Protocol (MCP) while building a controlled way for an AI client to ask IBM i for read-only information.

<details>
<summary>Hinglish</summary>

Maine [MCP4i](https://github.com/iNewTech/MCP4i) MCP seekhte hue banaya, taaki AI client IBM i se controlled tareeke se sirf read-only information pooch sake.

</details>

This article concentrates on the single-program RPGLE server; the other folders provide interactive MCP practice with local Ollama and fictional documents.

<details>
<summary>Hinglish</summary>

Yeh article single-program RPGLE server par focus karta hai; baaki folders local Ollama aur fictional documents ke saath interactive MCP practice ke liye hain.

</details>

## Why use RPGLE for the MCP server?

MCP lets a server advertise tools with names, descriptions, and input schemas, then lets a client list and call those tools through a defined protocol ([MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)).

<details>
<summary>Hinglish</summary>

MCP server ko tool ka naam, description aur input schema batane deta hai; phir client defined protocol se un tools ko list aur call kar sakta hai.

</details>

The IBM i community should be able to study that server-side protocol handling in a familiar language, so the first [MCPHTTP.sqlrpgle program](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle) handles the MCP request itself instead of sitting behind a Python wrapper.

<details>
<summary>Hinglish</summary>

IBM i community ko server-side protocol handling apni familiar language mein samajhni chahiye, isliye pehla `MCPHTTP.sqlrpgle` program Python wrapper ke peeche rehne ke bajay MCP request khud handle karta hai.

</details>

IBM HTTP Server for i receives `POST /mcp` and invokes the ILE RPG program as CGI, a pattern IBM documents for RPG programs ([IBM RPG CGI example](https://www.ibm.com/support/pages/ile-rpg-cgi-programming-example)).

<details>
<summary>Hinglish</summary>

IBM HTTP Server for i `POST /mcp` request receive karke ILE RPG program ko CGI ke roop mein chalata hai; IBM ne RPG ke liye is pattern ko document kiya hai.

</details>

The program uses IBM CGI APIs to read the request and write the response, while Db2 for i functions parse and generate JSON ([annotated source](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L16)).

<details>
<summary>Hinglish</summary>

Program IBM CGI APIs se request padhta aur response likhta hai, aur Db2 for i functions se JSON parse aur generate karta hai.

</details>

```text
MCP client or Inspector
        │ POST /mcp: initialize, tools/list, tools/call
        ▼
IBM HTTP Server for i (dedicated instance and subsystem)
        │ CGI request body and environment
        ▼
MCP4I/MCPHTTP *PGM (ILE RPG)
        │ fixed SELECT
        ▼
SYSIBMADM.ENV_SYS_INFO
        │ JSON-RPC tool result
        ▼
MCP client → model and user
```

The HTTP server owns the listening socket, so submitting `CALL MCP4I/MCPHTTP` with `SBMJOB` would not create a working MCP listener.

<details>
<summary>Hinglish</summary>

Listening socket HTTP server ke paas hota hai, isliye `SBMJOB` se `CALL MCP4I/MCPHTTP` submit karne par working MCP listener nahi banega.

</details>

## What the RPGLE source actually handles

The [request handler](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L91) checks the HTTP method, Origin, content type, and request size before it reads and parses the JSON body.

<details>
<summary>Hinglish</summary>

Request handler JSON body padhne aur parse karne se pehle HTTP method, Origin, content type aur request size check karta hai.

</details>

The [MCP dispatcher](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L199) implements `initialize`, `notifications/initialized`, `ping`, `tools/list`, and `tools/call` for the 2025-11-25 request-response subset.

<details>
<summary>Hinglish</summary>

MCP dispatcher 2025-11-25 ke request-response subset ke liye `initialize`, `notifications/initialized`, `ping`, `tools/list` aur `tools/call` implement karta hai.

</details>

During `tools/list`, the program advertises just one tool, `get_system_info`, with an empty input schema ([tool definition](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L205)).

<details>
<summary>Hinglish</summary>

`tools/list` ke waqt program sirf ek tool, `get_system_info`, advertise karta hai, jiska input schema empty hai.

</details>

During `tools/call`, the program accepts only that tool name and runs a fixed read of `SYSIBMADM.ENV_SYS_INFO` rather than SQL supplied by a model ([tool call and SQL](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L213)).

<details>
<summary>Hinglish</summary>

`tools/call` ke waqt program sirf wahi tool name accept karta hai aur model ke diye hue SQL ki jagah `SYSIBMADM.ENV_SYS_INFO` par fixed read chalata hai.

</details>

The result contains OS and host identity plus a local observation timestamp, and Db2 for i escapes the text before the [CGI response writer](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L299) returns it.

<details>
<summary>Hinglish</summary>

Result mein OS aur host identity ke saath local observation timestamp hota hai, aur CGI response writer ke return karne se pehle Db2 for i text ko safely escape karta hai.

</details>

This is source code ready for a development-partition trial, not a claim that it has already compiled or passed a live IBM i test.

<details>
<summary>Hinglish</summary>

Yeh source code development partition par try karne ke liye hai; iska matlab yeh nahi ki yeh IBM i par compile ya live test pass kar chuka hai.

</details>

## How to deploy the first program on IBM i

The full [RPGLE deployment guide](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md) is the command-by-command reference for copying the source to the IFS, creating the library, granting authority, configuring HTTP, and verifying the endpoint.

<details>
<summary>Hinglish</summary>

Puri RPGLE deployment guide source ko IFS mein copy karne, library banane, authority dene, HTTP configure karne aur endpoint verify karne ke liye command-by-command reference hai.

</details>

First, create the `MCP4I` library and the dedicated `MCPJOBQ`, `MCPJOBD`, `MCPCLS`, and `MCPSBS` objects using the guide's setup commands.

<details>
<summary>Hinglish</summary>

Sabse pehle guide ke setup commands se `MCP4I` library aur dedicated `MCPJOBQ`, `MCPJOBD`, `MCPCLS` aur `MCPSBS` objects banao.

</details>

Next, copy `MCPHTTP.sqlrpgle` to your IFS build directory and compile and bind the one RPGLE program with these commands, adjusting the source path for your system.

<details>
<summary>Hinglish</summary>

Phir `MCPHTTP.sqlrpgle` ko apni IFS build directory mein copy karo aur apne system ke source path ko adjust karke in commands se ek RPGLE program compile aur bind karo.

</details>

```cl
CRTSQLRPGI OBJ(MCP4I/MCPHTTP) SRCSTMF('/home/builduser/MCP4i/MCPHTTP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTPGM PGM(MCP4I/MCPHTTP) MODULE(MCP4I/MCPHTTP) BNDSRVPGM(QHTTPSVR/QZHBCGI)
```

Add the [HTTP configuration directives](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) to a dedicated `MCP4I` HTTP instance so `/mcp` maps to the program and the instance uses the new job queue and subsystem.

<details>
<summary>Hinglish</summary>

Dedicated `MCP4I` HTTP instance mein HTTP configuration directives add karo, taaki `/mcp` program se map ho aur instance nayi job queue aur subsystem use kare.

</details>

Start the subsystem before the HTTP instance, because IBM requires an active subsystem for jobs routed to a custom HTTP job queue ([IBM procedure](https://www.ibm.com/support/pages/node/645335)).

<details>
<summary>Hinglish</summary>

HTTP instance se pehle subsystem start karo, kyunki custom HTTP job queue mein route hone wale jobs ke liye IBM active subsystem require karta hai.

</details>

```cl
STRSBS SBSD(MCP4I/MCPSBS)
STRTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)
```

If your operations process uses `SBMJOB`, submit the `STRTCPSVR` start command to an already running control queue rather than submitting the RPG CGI program itself ([batch-start explanation](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md#5-start-inspect-and-stop)).

<details>
<summary>Hinglish</summary>

Agar operations process mein `SBMJOB` use hota hai, to RPG CGI program ko submit karne ke bajay `STRTCPSVR` start command ko pehle se running control queue mein submit karo.

</details>

The sample endpoint listens only on IBM i loopback, so use the guide's SSH tunnel or run the [smoke test](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) from a machine that can reach it.

<details>
<summary>Hinglish</summary>

Sample endpoint sirf IBM i loopback par listen karta hai, isliye guide wala SSH tunnel use karo ya smoke test aisi machine se chalao jo endpoint tak pahunch sake.

</details>

```sh
python3 rpgle-mcp-server/smoke_test.py http://127.0.0.1:8088/mcp
```

The test covers initialization, tool discovery, one live `get_system_info` call, and rejection of several invalid requests; keep actual host names and system output out of public logs.

<details>
<summary>Hinglish</summary>

Test initialization, tool discovery, ek live `get_system_info` call aur kuch invalid requests ki rejection check karta hai; actual host names aur system output public logs mein mat daalo.

</details>

## Practice the conversation flow with Ollama

If you do not have an IBM i development partition yet, use the [completed Python CLI](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/README.md) to practice interactive MCP tool calls with local Ollama and sample documents.

<details>
<summary>Hinglish</summary>

Agar abhi IBM i development partition nahi hai, to completed Python CLI se local Ollama aur sample documents ke saath interactive MCP tool calls practice karo.

</details>

Its [document MCP server](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/mcp_server.py), [client](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/mcp_client.py), and [chat entry point](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/main.py) show where tool registration, connection, and model interaction happen.

<details>
<summary>Hinglish</summary>

Uska document MCP server, client aur chat entry point dikhate hain ki tool registration, connection aur model interaction code mein kahan hota hai.

</details>

The folder's README provides the current `uv`, Ollama model, and run commands, while the [Python starter](https://github.com/iNewTech/MCP4i/blob/main/cli_project/README.md) and [TypeScript starter](https://github.com/iNewTech/MCP4i/blob/main/cli_project_ts/README.md) let you work through the exercises yourself.

<details>
<summary>Hinglish</summary>

Us folder ki README current `uv`, Ollama model aur run commands deti hai, aur Python aur TypeScript starters se tum exercises khud complete kar sakte ho.

</details>

These document demos are separate from the RPGLE IBM i server, and their in-memory editing tool is not an IBM i write capability.

<details>
<summary>Hinglish</summary>

Yeh document demos RPGLE IBM i server se alag hain, aur inka in-memory editing tool IBM i par write karne ki capability nahi deta.

</details>

## The read-only roadmap and vendor opportunity

The [Phase 1 roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) proposes later tools for library lists, object and file metadata, program references, jobs, source reading, and carefully guarded SQL.

<details>
<summary>Hinglish</summary>

Phase 1 roadmap mein aage library lists, object aur file metadata, program references, jobs, source reading aur carefully guarded SQL ke tools propose kiye gaye hain.

</details>

Those capabilities are designs, not tools already available from the current RPGLE server.

<details>
<summary>Hinglish</summary>

Yeh capabilities abhi design mein hain; current RPGLE server se available tools nahi hain.

</details>

For IBM i vendors, a supported MCP interface could make product metadata or diagnostics available through narrow tools, but a real offering would also need authentication, tenant boundaries, auditability, performance limits, and a tested release matrix.

<details>
<summary>Hinglish</summary>

IBM i vendors ke liye supported MCP interface product metadata ya diagnostics ko narrow tools se available kara sakta hai, lekin real offering ko authentication, tenant boundaries, auditability, performance limits aur tested release matrix bhi chahiye.

</details>

For general developers, the [learning chapters](https://github.com/iNewTech/MCP4i/tree/main/docs) and local demos provide a way to understand MCP before contributing a client, test, or user experience around IBM i.

<details>
<summary>Hinglish</summary>

General developers ke liye learning chapters aur local demos IBM i ke aas-paas client, test ya user experience contribute karne se pehle MCP samajhne ka raasta dete hain.

</details>

The next meaningful result is a development-partition compile followed by a client discovering `get_system_info` and receiving a result checked against that same partition.

<details>
<summary>Hinglish</summary>

Agla meaningful result development partition par compile karna hai, phir client mein `get_system_info` discover karke usi partition ke against checked result paana hai.

</details>

If you try it, share the IBM i release, relevant PTF level, and sanitized compile or smoke-test findings through a [GitHub issue](https://github.com/iNewTech/MCP4i/issues).

<details>
<summary>Hinglish</summary>

Agar tum ise try karo, to IBM i release, relevant PTF level aur sanitized compile ya smoke-test findings GitHub issue mein share karo.

</details>

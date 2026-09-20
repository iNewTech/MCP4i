# MCP4i: Learning MCP by Building a Server in RPGLE

An IBM i developer may know how to inspect a library, program, file, or job, but a chat model cannot see the current state of that partition on its own. I started [MCP4i](https://github.com/iNewTech/MCP4i) to learn the Model Context Protocol (MCP) while building a controlled way for an AI client to ask IBM i for read-only information. This article concentrates on the single-program RPGLE server; the other folders provide interactive MCP practice with local Ollama and fictional documents.

<details>
<summary>Hinglish</summary>

IBM i developer library, program, file ya job inspect kar sakta hai, lekin chat model khud se us partition ki current state nahi dekh sakta. Maine [MCP4i](https://github.com/iNewTech/MCP4i) MCP seekhte hue banaya, taaki AI client IBM i se controlled tareeke se sirf read-only information pooch sake. Yeh article single-program RPGLE server par focus karta hai; baaki folders local Ollama aur fictional documents ke saath interactive MCP practice ke liye hain.

</details>

## Why use RPGLE for the MCP server?

MCP lets a server advertise tools with names, descriptions, and input schemas, then lets a client list and call those tools through a defined protocol ([MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)). The IBM i community should be able to study that server-side protocol handling in a familiar language, so the first [MCPHTTP.sqlrpgle program](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle) handles the MCP request itself instead of sitting behind a Python wrapper. IBM HTTP Server for i receives `POST /mcp` and invokes the ILE RPG program as CGI, a pattern IBM documents for RPG programs ([IBM RPG CGI example](https://www.ibm.com/support/pages/ile-rpg-cgi-programming-example)). The program uses IBM CGI APIs to read the request and write the response, while Db2 for i functions parse and generate JSON ([annotated source](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L27)). The HTTP server owns the listening socket, so submitting `CALL MCP4I/MCPHTTP` with `SBMJOB` would not create a working MCP listener.

<details>
<summary>Hinglish</summary>

MCP server ko tool ka naam, description aur input schema batane deta hai; phir client defined protocol se un tools ko list aur call kar sakta hai. IBM i community ko server-side protocol handling apni familiar language mein samajhni chahiye, isliye pehla `MCPHTTP.sqlrpgle` program Python wrapper ke peeche rehne ke bajay MCP request khud handle karta hai. IBM HTTP Server for i `POST /mcp` request receive karke ILE RPG program ko CGI ke roop mein chalata hai; IBM ne RPG ke liye is pattern ko document kiya hai. Program IBM CGI APIs se request padhta aur response likhta hai, aur Db2 for i functions se JSON parse aur generate karta hai. Listening socket HTTP server ke paas hota hai, isliye `SBMJOB` se `CALL MCP4I/MCPHTTP` submit karne par working MCP listener nahi banega.

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

## What the RPGLE source actually handles

The [request handler](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L130) checks the HTTP method, Origin, content type, and request size before it reads and parses the JSON body. The [MCP dispatcher](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L251) implements `initialize`, `notifications/initialized`, `ping`, `tools/list`, and `tools/call` for the 2025-11-25 request-response subset. During `tools/list`, the program advertises just one tool, `get_system_info`, with an empty input schema ([tool definition](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L340)). The [`listTools` registry](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L287) holds the tool definitions, so a new tool does not require changes to the HTTP or JSON-RPC request procedures.

<details>
<summary>Hinglish</summary>

Request handler JSON body padhne aur parse karne se pehle HTTP method, Origin, content type aur request size check karta hai. MCP dispatcher 2025-11-25 ke request-response subset ke liye `initialize`, `notifications/initialized`, `ping`, `tools/list` aur `tools/call` implement karta hai. `tools/list` ke waqt program sirf ek tool, `get_system_info`, advertise karta hai, jiska input schema empty hai. `listTools` registry tool definitions rakhti hai; naya tool add karne ke liye HTTP ya JSON-RPC request procedures badalne ki zarurat nahi hai.

</details>

During `tools/call`, the program accepts only that tool name and runs a fixed read of `SYSIBMADM.ENV_SYS_INFO` rather than SQL supplied by a model ([tool handler](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L353) and [fixed SQL](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L371)). The [`callRegisteredTool` router](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L322) maps that name to its execution procedure. The result contains OS and host identity plus a local observation timestamp, and Db2 for i escapes the text before the [CGI response writer](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L450) returns it. This is source code ready for a development-partition trial, not a claim that it has already compiled or passed a live IBM i test.

<details>
<summary>Hinglish</summary>

`tools/call` ke waqt program sirf wahi tool name accept karta hai aur model ke diye hue SQL ki jagah `SYSIBMADM.ENV_SYS_INFO` par fixed read chalata hai. `callRegisteredTool` router us tool name ko execution procedure se jodta hai. Result mein OS aur host identity ke saath local observation timestamp hota hai, aur CGI response writer ke return karne se pehle Db2 for i text ko safely escape karta hai. Yeh source code development partition par try karne ke liye hai; iska matlab yeh nahi ki yeh IBM i par compile ya live test pass kar chuka hai.

</details>

## How to add a new read-only tool

Suppose you want a `get_user_info` tool. In [MCPHTTP.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle), write one procedure that describes the tool and another that runs its read-only IBM i lookup. Declare prototypes alongside the existing `getSysInfoTool` and `runSysInfoTool` prototypes, then follow those procedures as examples: `getUserInfoTool` returns the public name, description, and `inputSchema`; `runUserInfoTool` performs a fixed read and returns an MCP `content` result or an `isError` result. Keep the lookup out of the metadata procedure, and never accept model-supplied SQL as the lookup.

<details>
<summary>Hinglish</summary>

Maan lo tum `get_user_info` tool banana chahte ho. `MCPHTTP.sqlrpgle` mein ek procedure tool ka description banayega aur doosra IBM i par uska read-only lookup chalayega. Existing `getSysInfoTool` aur `runSysInfoTool` prototypes ke paas naye prototypes declare karo, phir un procedures ka pattern follow karo: `getUserInfoTool` public name, description aur `inputSchema` return kare; `runUserInfoTool` fixed read chalakar MCP `content` result ya `isError` result return kare. Lookup ko metadata procedure mein mat rakho, aur model se SQL lekar query mat chalao.

</details>

Once those procedures exist, add the definition to [`listTools`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L287). The program already has this future example as comments; enable it when the new procedure is real. Declare `userInfoTool` with the other local variables at the top of `listTools`, then put these lines after the existing `toolList(1)` assignment. `toolCount` must equal the number of active entries, and the loop builds the JSON array and commas for you.

<details>
<summary>Hinglish</summary>

Jab dono procedures ready hon, definition ko `listTools` mein register karo. Program mein future example comments ke roop mein pehle se diya hai; naya procedure sach mein banne par use enable karo. `listTools` ke top par baaki local variables ke saath `userInfoTool` declare karo, phir existing `toolList(1)` assignment ke baad yeh lines add karo. `toolCount` ko active entries ki ginti ke barabar rakho; loop JSON array aur commas khud banata hai.

</details>

```rpgle
// Declare with the other dcl-s lines inside listTools:
dcl-s userInfoTool varchar(512);

// Add after toolList(1) = sysInfoTool:
userInfoTool = getUserInfoTool();
toolList(2) = userInfoTool;
toolCount = 2;
```

Next, add the call handler in [`callRegisteredTool`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L322), beside the existing `SYS_INFO_TOOL` branch. The name must exactly match the `name` returned by `getUserInfoTool`; otherwise Inspector may list the tool but its call will fail. This is the only tool-specific routing change: `readHttpRequest`, `parseRpcRequest`, and `dispatchRpcRequest` remain untouched.

<details>
<summary>Hinglish</summary>

Agla step `callRegisteredTool` mein existing `SYS_INFO_TOOL` branch ke paas call handler add karna hai. Name bilkul wahi hona chahiye jo `getUserInfoTool` ke `name` field mein return hota hai; warna Inspector tool dikha sakta hai, lekin call fail hoga. Tool-specific routing mein sirf yahi change chahiye: `readHttpRequest`, `parseRpcRequest` aur `dispatchRpcRequest` ko touch nahi karna.

</details>

```rpgle
// Add inside callRegisteredTool's SELECT, before ENDSL:
when requestedTool = 'get_user_info';
  toolResult = runUserInfoTool();
```

Finally, compile the updated program on your IBM i development partition and extend the [smoke test](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) to check that `tools/list` shows the new name and `tools/call` returns its expected data. The snippets above register and route a tool; they do not implement `get_user_info` by themselves. The complete, current example remains [`get_system_info`](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle#L340).

<details>
<summary>Hinglish</summary>

Aakhir mein updated program ko IBM i development partition par compile karo aur smoke test badhao, taaki `tools/list` mein naya naam aur `tools/call` mein expected data verify ho. Upar wale snippets tool ko register aur route karte hain; woh apne aap `get_user_info` implement nahi karte. Abhi complete example `get_system_info` hi hai.

</details>

## How to deploy the first program on IBM i

The full [RPGLE deployment guide](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md) covers source transfer, authority, the HTTP instance, and testing. This sample uses a dedicated `MCP4I` library, `MCPSBS` subsystem, `MCPJOBQ` job queue, `MCPJOBD` job description, and `MCPCLS` class. These objects isolate the **HTTP server jobs**; they do not turn `MCPHTTP` into a permanently running RPG job. Create them once with the commands below, adjusting the pool and job limits for your development partition.

<details>
<summary>Hinglish</summary>

Puri RPGLE deployment guide source transfer, authority, HTTP instance aur testing cover karti hai. Is sample mein dedicated `MCP4I` library, `MCPSBS` subsystem, `MCPJOBQ` job queue, `MCPJOBD` job description aur `MCPCLS` class use hote hain. Yeh objects **HTTP server jobs** ko alag rakhte hain; `MCPHTTP` ko hamesha chalne wala RPG job nahi banate. Development partition ke hisaab se pool aur job limits adjust karke yeh commands ek baar chalao.

</details>

```cl
CRTLIB LIB(MCP4I) TEXT('MCP4i RPG HTTP server')
CRTJOBQ JOBQ(MCP4I/MCPJOBQ) TEXT('MCP HTTP jobs')
CRTJOBD JOBD(MCP4I/MCPJOBD) JOBQ(MCP4I/MCPJOBQ) USER(QTMHHTTP) RTGDTA(MCPHTTP) JOBMSGQFL(*WRAP)
CRTCLS CLS(MCP4I/MCPCLS) RUNPTY(25) TEXT('MCP HTTP job class')
CRTSBSD SBSD(MCP4I/MCPSBS) POOLS((1 256 50 *MB)) MAXJOBS(20) TEXT('MCP HTTP subsystem')
ADDJOBQE SBSD(MCP4I/MCPSBS) JOBQ(MCP4I/MCPJOBQ) MAXACT(20) SEQNBR(10)
ADDRTGE SBSD(MCP4I/MCPSBS) SEQNBR(10) CMPVAL(MCPHTTP) PGM(QSYS/QCMD) CLS(MCP4I/MCPCLS)
```

Copy `MCPHTTP.sqlrpgle` to the IFS build directory, then compile and bind the `*PGM` object in `MCP4I`. Change the source path to match your system; compiling alone does not create a network listener. The [IBM CGI setup guide](https://www.ibm.com/docs/en/i/7.4?topic=programming-setting-up-cgi-programs) confirms that an ILE RPG CGI program needs an HTTP server configuration that maps a URL to the program.

<details>
<summary>Hinglish</summary>

`MCPHTTP.sqlrpgle` ko IFS build directory mein copy karke `MCP4I` mein `*PGM` object compile aur bind karo. Source path apne system ke mutabik badlo; sirf compile karne se network listener nahi banta. IBM ki CGI setup guide bhi batati hai ki ILE RPG CGI program chalane ke liye HTTP server configuration mein URL ko program se map karna padta hai.

</details>

```cl
CRTSQLRPGI OBJ(MCP4I/MCPHTTP) SRCSTMF('/home/builduser/MCP4i/MCPHTTP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT)
CRTPGM PGM(MCP4I/MCPHTTP) MODULE(MCP4I/MCPHTTP) BNDSRVPGM(QHTTPSVR/QZHBCGI)
```

Now create the **IBM HTTP Server for i (Apache)** instance named `MCP4I` in IBM Web Administration for i: start `*ADMIN` if needed with `STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)`, open **Setup → Create HTTP Server**, choose the instance name and server root, and set a local test port. IBM documents this [instance wizard](https://www.ibm.com/docs/en/i/7.5?topic=tasks-getting-started). In its configuration, add the repository's full [httpd.conf.example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example), editing any wizard-generated `Listen` or `ServerName` lines instead of duplicating them. The key `ScriptAlias` line maps `POST /mcp` to `MCP4I/MCPHTTP`; the `HTTPStartJob*` and `HTTPSubsystemDesc` directives send the instance's server jobs to the dedicated queue and subsystem ([IBM subsystem procedure](https://www.ibm.com/support/pages/node/645335)).

<details>
<summary>Hinglish</summary>

Ab IBM Web Administration for i mein `MCP4I` naam ka **IBM HTTP Server for i (Apache)** instance banao: zarurat ho to `STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)` se `*ADMIN` start karo, **Setup → Create HTTP Server** kholo, instance name aur server root do, aur local test port set karo. Configuration mein repository wala poora `httpd.conf.example` add karo; wizard ne `Listen` ya `ServerName` pehle likha ho to duplicate karne ke bajay existing lines edit karo. `ScriptAlias` se `POST /mcp` request `MCP4I/MCPHTTP` tak pahunchti hai, aur `HTTPStartJob*` aur `HTTPSubsystemDesc` directives server jobs ko dedicated queue aur subsystem mein bhejte hain.

</details>

```apache
# Excerpt; use the linked file for the complete configuration and access rules.
Listen 127.0.0.1:8088
HTTPStartJobQueue MCP4I/MCPJOBQ
HTTPStartJobDesc MCP4I/MCPJOBD
HTTPRoutingData MCPHTTP
HTTPSubsystemDesc MCP4I/MCPSBS
ScriptAlias /mcp /QSYS.LIB/MCP4I.LIB/MCPHTTP.PGM
```

Start the subsystem and then the HTTP instance. The HTTP listener accepts requests, its CGI jobs run the RPG program for matching `/mcp` requests, and the program reads one CGI request and returns one MCP response. IBM identifies `QZSRHTTP` as a request-handling job and `QZSRCGI` as a CGI job; there may be multiple CGI jobs, so **one submitted RPG job is not responsible for every request** ([IBM CGI job overview](https://www.ibm.com/support/pages/node/1171114)). `SBMJOB CMD(CALL MCP4I/MCPHTTP)` has no role here: without an HTTP CGI request, the program has no request body or environment to process. The `MCPSBS`/`MCPJOBQ` objects are useful for server-job isolation and monitoring, but a dedicated subsystem is not required by MCP itself.

<details>
<summary>Hinglish</summary>

Pehle subsystem aur phir HTTP instance start karo. HTTP listener requests leta hai; uske CGI jobs matching `/mcp` requests par RPG program chalate hain, aur program ek CGI request padhkar ek MCP response return karta hai. IBM ke hisaab se `QZSRHTTP` request-handling job aur `QZSRCGI` CGI job hai; kai CGI jobs ho sakte hain, isliye **ek submitted RPG job saari requests handle nahi karta**. Yahan `SBMJOB CMD(CALL MCP4I/MCPHTTP)` ka koi kaam nahi hai: HTTP CGI request ke bina program ko request body aur environment milenge hi nahi. `MCPSBS` aur `MCPJOBQ` server jobs ko isolate aur monitor karne ke liye useful hain, lekin MCP protocol ke liye dedicated subsystem zaroori nahi hai.

</details>

```cl
STRSBS SBSD(MCP4I/MCPSBS)
STRTCPSVR SERVER(*HTTP) HTTPSVR(MCP4I)
```

Nginx is not needed in this first deployment: IBM's Apache-based server already knows how to invoke an ILE RPG CGI program. Nginx can later sit in front as a reverse proxy, while IBM HTTP Server still performs the RPG CGI call; its documented `fastcgi_pass` expects a FastCGI server, which this ordinary ILE CGI program is not ([Nginx FastCGI guide](https://nginx.org/en/docs/beginners_guide.html)).

<details>
<summary>Hinglish</summary>

Is pehle deployment mein Nginx ki zarurat nahi hai: IBM ka Apache-based server ILE RPG CGI program ko khud invoke kar sakta hai. Baad mein Nginx ko reverse proxy ke roop mein aage rakh sakte ho, lekin RPG CGI call IBM HTTP Server hi karega; Nginx ka `fastcgi_pass` FastCGI server expect karta hai, aur yeh normal ILE CGI program FastCGI server nahi hai.

</details>

The sample endpoint listens only on IBM i loopback, so use the guide's SSH tunnel or run the [smoke test](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) from a machine that can reach it. The test covers initialization, tool discovery, one live `get_system_info` call, and rejection of several invalid requests; keep actual host names and system output out of public logs.

<details>
<summary>Hinglish</summary>

Sample endpoint sirf IBM i loopback par listen karta hai, isliye guide wala SSH tunnel use karo ya smoke test aisi machine se chalao jo endpoint tak pahunch sake. Test initialization, tool discovery, ek live `get_system_info` call aur kuch invalid requests ki rejection check karta hai; actual host names aur system output public logs mein mat daalo.

</details>

```sh
python3 rpgle-mcp-server/smoke_test.py http://127.0.0.1:8088/mcp
```

## Practice the conversation flow with Ollama

If you do not have an IBM i development partition yet, use the [completed Python CLI](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/README.md) to practice interactive MCP tool calls with local Ollama and sample documents. Its [document MCP server](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/mcp_server.py), [client](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/mcp_client.py), and [chat entry point](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/main.py) show where tool registration, connection, and model interaction happen. The folder's README provides the current `uv`, Ollama model, and run commands, while the [Python starter](https://github.com/iNewTech/MCP4i/blob/main/cli_project/README.md) and [TypeScript starter](https://github.com/iNewTech/MCP4i/blob/main/cli_project_ts/README.md) let you work through the exercises yourself. These document demos are separate from the RPGLE IBM i server, and their in-memory editing tool is not an IBM i write capability.

<details>
<summary>Hinglish</summary>

Agar abhi IBM i development partition nahi hai, to completed Python CLI se local Ollama aur sample documents ke saath interactive MCP tool calls practice karo. Uska document MCP server, client aur chat entry point dikhate hain ki tool registration, connection aur model interaction code mein kahan hota hai. Us folder ki README current `uv`, Ollama model aur run commands deti hai, aur Python aur TypeScript starters se tum exercises khud complete kar sakte ho. Yeh document demos RPGLE IBM i server se alag hain, aur inka in-memory editing tool IBM i par write karne ki capability nahi deta.

</details>

## The read-only roadmap and vendor opportunity

The [Phase 1 roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) proposes later tools for library lists, object and file metadata, program references, jobs, source reading, and carefully guarded SQL. Those capabilities are designs, not tools already available from the current RPGLE server. For IBM i vendors, a supported MCP interface could make product metadata or diagnostics available through narrow tools, but a real offering would also need authentication, tenant boundaries, auditability, performance limits, and a tested release matrix.

<details>
<summary>Hinglish</summary>

Phase 1 roadmap mein aage library lists, object aur file metadata, program references, jobs, source reading aur carefully guarded SQL ke tools propose kiye gaye hain. Yeh capabilities abhi design mein hain; current RPGLE server se available tools nahi hain. IBM i vendors ke liye supported MCP interface product metadata ya diagnostics ko narrow tools se available kara sakta hai, lekin real offering ko authentication, tenant boundaries, auditability, performance limits aur tested release matrix bhi chahiye.

</details>

For general developers, the [learning chapters](https://github.com/iNewTech/MCP4i/tree/main/docs) and local demos provide a way to understand MCP before contributing a client, test, or user experience around IBM i. The next meaningful result is a development-partition compile followed by a client discovering `get_system_info` and receiving a result checked against that same partition. If you try it, share the IBM i release, relevant PTF level, and sanitized compile or smoke-test findings through a [GitHub issue](https://github.com/iNewTech/MCP4i/issues).

<details>
<summary>Hinglish</summary>

General developers ke liye learning chapters aur local demos IBM i ke aas-paas client, test ya user experience contribute karne se pehle MCP samajhne ka raasta dete hain. Agla meaningful result development partition par compile karna hai, phir client mein `get_system_info` discover karke usi partition ke against checked result paana hai. Agar tum ise try karo, to IBM i release, relevant PTF level aur sanitized compile ya smoke-test findings GitHub issue mein share karo.

</details>

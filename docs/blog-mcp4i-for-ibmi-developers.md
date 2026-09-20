# MCP4i: Bringing IBM i into AI Conversations, Starting with RPGLE

*An open-source learning project for IBM i developers, with a path for application teams and IBM i vendors to explore.*

Imagine joining an IBM i support call and hearing: “Which system am I connected to? What does this program reference? Which job is active?” A language model can explain what `DSPPGMREF` means, but it cannot know the current state of *your* partition. Someone must give it a controlled way to ask the system.

That is the problem behind [MCP4i](https://github.com/iNewTech/MCP4i). I am building the project in public as I learn the Model Context Protocol (MCP): first the concepts and small document demos, then a read-only IBM i server written in RPGLE. The goal is an assistant that can answer questions using observed IBM i information while preserving the boundaries IBM i teams already care about: authority, qualified names, job context, and operational scope.

## What MCP adds to an IBM i integration

MCP gives an AI application a standard way to discover a server's tools and call them. The server publishes a tool name, description, and input schema; the client presents that capability to the model and carries the model's requested call to the server. The server still decides what the tool is allowed to do. The [MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools) defines this discovery and call flow.

For IBM i, that distinction matters. A model does not receive an unrestricted 5250 session. It might see a focused tool named `get_system_info`, with no arguments, and receive a bounded result from a fixed IBM i service. Later, a separate `get_program_references` tool could take an explicitly qualified program name. The server's code and IBM i authority—not the model's wording—would determine which information can be read.

## What is in the repository today?

MCP4i has three connected tracks:

| Track | What you can use now |
| --- | --- |
| Learn MCP | [Ten chapter-by-chapter lessons](https://github.com/iNewTech/MCP4i/tree/main/docs), from why MCP exists through tool design, IBM i access, SQL boundaries, and operations. The [learning index](https://github.com/iNewTech/MCP4i/blob/main/docs/README.md) gives the order. |
| Experiment locally | [Python starter](https://github.com/iNewTech/MCP4i/tree/main/cli_project), [completed Python document demo](https://github.com/iNewTech/MCP4i/tree/main/cli_project_COMPLETE), and [TypeScript starter](https://github.com/iNewTech/MCP4i/tree/main/cli_project_ts). The Python demos use local Ollama, so the exercises do not require buying an API key. These document tools teach MCP mechanics; they do **not** connect to IBM i. |
| Build on IBM i | A [single ILE RPG program](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle) that handles MCP requests through IBM HTTP Server for i and defines one read-only `get_system_info` tool. Its [deployment guide](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md), [HTTP configuration example](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example), and [live smoke test](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) are in the same folder. |

The RPGLE source is a **prototype awaiting compilation and a live test on an IBM i development partition**. It is not a claim that every listed tool already works, or that this is ready for production deployment.

## Yes, the MCP server itself is in RPGLE

The first RPGLE slice does more than return a value to a Python server. IBM HTTP Server for i receives a request at `/mcp` and invokes `MCPHTTP` as a CGI program. The RPG program reads the request body, handles MCP's JSON-RPC methods, advertises `get_system_info`, runs one fixed Db2 for i query against `SYSIBMADM.ENV_SYS_INFO`, and writes the MCP response. IBM documents both [ILE RPG CGI support](https://www.ibm.com/support/pages/ile-rpg-cgi-programming-example) and the [CGI APIs](https://www.ibm.com/docs/en/i/7.6.0?topic=api-cgi-apis) used for this pattern.

```text
Chat app or MCP Inspector
        │ tools/list, then tools/call
        ▼
IBM HTTP Server for i
        │ CGI request
        ▼
MCPHTTP *PGM (RPGLE)
        │ fixed, read-only SQL
        ▼
SYSIBMADM.ENV_SYS_INFO
```

There is no always-running RPG `SBMJOB` listener in this design. The HTTP instance owns the listener and invokes the program for each request. The sample also creates a dedicated job queue and subsystem for that HTTP instance. [IBM's subsystem procedure](https://www.ibm.com/support/pages/node/645335) describes the required HTTP directives and routing objects.

This direct-RPGLE approach is useful to explore because it makes the MCP boundary visible to IBM i developers. You can read the protocol handling, the fixed SQL, and the CGI output in one commented source file. It also makes the tradeoffs visible: HTTP configuration, character-set conversion, authority, protocol compatibility, and client testing all need attention.

## How an IBM i developer can try it

**If you are learning MCP first**, start with [Lesson 1](https://github.com/iNewTech/MCP4i/blob/main/docs/lesson-01-why-mcp.md) and [Lesson 2](https://github.com/iNewTech/MCP4i/blob/main/docs/lesson-02-mcp-architecture.md), then run the [completed local document demo](https://github.com/iNewTech/MCP4i/blob/main/cli_project_COMPLETE/README.md). It lets you see tool discovery and tool calls without needing an IBM i connection. The [course companion guide](https://github.com/iNewTech/MCP4i/blob/main/docs/anthropic-course-guide.md) maps these exercises to Anthropic Academy's introductory MCP course.

**If you have an authorized development partition**, follow the [RPGLE deployment guide](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md) in order. It covers copying the source to the IFS, creating `MCP4I`, compiling with `CRTSQLRPGI`, binding the CGI service program with `CRTPGM`, granting the CGI profile only needed authority, configuring a dedicated HTTP instance, and starting its subsystem and server. After that, run the repository's smoke test through an SSH tunnel or from a machine that can reach the endpoint:

```sh
python3 rpgle-mcp-server/smoke_test.py http://127.0.0.1:8088/mcp
```

The smoke test asks the server to initialize, list tools, call `get_system_info`, and reject several invalid requests. A local Python interpreter runs the **test client**; Python is not part of the IBM i MCP server. The sample HTTP configuration listens on loopback only. To make a chat application use it, register a reachable MCP HTTP endpoint in that application's settings; the application will not find the server merely because the repository exists.

## Where this can go next

The [read-only tool roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) describes focused capabilities IBM i teams ask for: library lists, object and file information, recorded program references, database relations, active jobs, job status, and later source reading. These are **planned contracts**, not currently advertised by the RPGLE server. The first implementation goal is to compile and verify its single system-information tool, then add another narrow tool with its own authority and result limits.

I also want the project to be useful beyond RPGLE. A non-IBM i developer can use the Python and TypeScript demos to learn the host–client–server flow, then help with an MCP client, documentation, validation, or user experience. An IBM i vendor could evaluate whether a product-specific, read-only MCP interface would help customers investigate supported metadata and diagnostics. That would require a clear support matrix, tenant and user authorization, audit records, bounded execution, and secure deployment—not just a tool description.

One boundary is deliberate: MCP4i does not currently offer arbitrary `run_cl`, program execution, job submission, or general SQL. A later `run_sql` tool would need more than a check that text starts with `SELECT`; the entire statement and reachable objects or routines would need review. The [Phase 1 roadmap](https://github.com/iNewTech/MCP4i/blob/main/project/phase-01-readonly-tools.md) explains the proposed constraints.

## Help shape the project

If you work with IBM i, I would value feedback on the first ten tool contracts and on the RPGLE build path. If you can test on a development partition, record the IBM i release and relevant PTF levels, share sanitized compile or protocol results, and open an [issue](https://github.com/iNewTech/MCP4i/issues) or pull request. Please keep real system names, credentials, source, and customer data out of public reports.

Start at the [MCP4i repository](https://github.com/iNewTech/MCP4i). The most useful next milestone is simple and measurable: **compile the RPGLE program on IBM i, see `get_system_info` in an MCP client, call it, and verify the response against the partition.**

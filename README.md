# MCP4i — IBM i MCP Learning Bootcamp

Learn the Model Context Protocol (MCP) by designing, then building, an assistant that answers questions about an IBM i system using verified, read-only information.

The project connects AI concepts to familiar IBM i work: inspecting libraries and objects, understanding program dependencies, reading source, checking jobs, and querying approved data.

**Current stage:** Lessons 1–10, Python and TypeScript CLI starters, and a completed Python document demo are available. The CLIs use local Ollama. A one-tool RPGLE MCP server is now in source form; IBM i compilation and a live connection remain unverified.

## Start learning

1. Read the [learning roadmap](docs/00-roadmap.md) for the chapter order and milestone gates.
2. Study [Lesson 1 — Why MCP?](docs/lesson-01-why-mcp.md).
3. Continue with [Lesson 2 — MCP Architecture](docs/lesson-02-mcp-architecture.md).
4. Complete Lesson 2's design exercise using the [Phase 1 read-only tool roadmap](project/phase-01-readonly-tools.md).

Already studying Lesson 2? Start with its short recall exercise, then draw the architecture and design your first ten tools. The [learning index](docs/README.md) collects the available material.

Following Anthropic's MCP course? The [course-to-MCP4i study guide](docs/anthropic-course-guide.md) maps its exercises to our chapters and read-only project boundary.

## Run the local course demos

The [starter CLI exercise](cli_project/README.md) retains the MCP implementation TODOs. The [completed CLI example](cli_project_COMPLETE/README.md) implements tools, resources, and prompts. Both use Ollama at `http://127.0.0.1:11434` and default to the locally installed `qwen3.5:4b` model; neither requires a paid API key. They require Python 3.10+, [uv](https://docs.astral.sh/uv/getting-started/installation/), and Ollama.

For either folder, open a terminal in that folder and run:

```bash
uv sync --python 3.12
ollama pull qwen3.5:4b
uv run --python 3.12 main.py
```

In the completed CLI, try `Tell me about @deposition.md` or `/format deposition.md`. The starter CLI can answer ordinary chat questions while its MCP methods remain unfinished. The in-memory document examples can be edited by the completed demo's sample tool; they are separate from the planned read-only IBM i tools.

For the [TypeScript CLI starter](cli_project_ts/README.md), use Node.js 22.19+ and run `npm ci` followed by `npm run dev` in `cli_project_ts/`. It has the same two document tools as the current Python starter, plus `/tools` and `/read` commands for inspecting them directly. Run `npm run inspect` there to open the current MCP Inspector.

## Build the RPGLE MCP server

The [RPGLE MCP server guide](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/README.md) explains the IBM i library, compile and bind commands, dedicated job queue and subsystem, HTTP instance, start/stop commands, and live smoke test. It implements one read-only `get_system_info` tool directly in [MCPHTTP.sqlrpgle](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/MCPHTTP.sqlrpgle). Its [HTTP configuration](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/httpd.conf.example) and [smoke test](https://github.com/iNewTech/MCP4i/blob/main/rpgle-mcp-server/smoke_test.py) are separate files. This slice has not yet been compiled or tested on a real IBM i partition.

## How this bootcamp works

Each lesson moves through **theory → IBM i example → paper walkthrough → exercise → project milestone**. Explain decisions in your own words and submit the homework for review before advancing. Reading a chapter does not establish that its checks have passed.

You can complete the first two lessons without an IBM i connection, credentials, or software setup. All example systems, libraries, jobs, and results in these lessons are fictional.

## Chapter order

| Order | Topic | Availability |
| --- | --- | --- |
| 00 | Roadmap and learning method | [Available](docs/00-roadmap.md) |
| 01 | Why LLMs need tools; why MCP exists | [Available](docs/lesson-01-why-mcp.md) |
| 02 | Host, client, server; tools, resources, prompts; request flow | [Available](docs/lesson-02-mcp-architecture.md) |
| 03 | Tool contracts and boundaries | [Available](docs/lesson-03-tool-contracts.md) |
| 04 | First mock MCP server | [Available](docs/lesson-04-first-mock-server.md) |
| 05 | Connect to IBM i safely | [Available](docs/lesson-05-connect-to-ibmi.md) |
| 06 | Libraries, objects, files, and references | [Available](docs/lesson-06-inspection-tools.md) |
| 07 | Guarded SQL reads | [Available](docs/lesson-07-guarded-sql.md) |
| 08 | Jobs, source, and logs | [Available](docs/lesson-08-jobs-source-logs.md) |
| 09 | Resources, prompts, and answer quality | [Available](docs/lesson-09-resources-prompts-evaluation.md) |
| 10 | Operate and demonstrate | [Available](docs/lesson-10-operate-and-demonstrate.md) |

## Project milestones

| Milestone | Reviewable outcome | Stage |
| --- | --- | --- |
| M0 — Learning foundation | Lessons 1–2 and the read-only project scope | Documentation available |
| M1 — Design the first slice | Architecture, ten tool contracts, access boundaries, and failure cases | Next learner exercise; no code |
| M2 — First runnable slice | Discover and call `get_system_info` against fictional data | Future implementation |
| M3 — First IBM i read | Verify one bounded read on an authorized development system | RPGLE source available; live verification pending |
| M4 — Broaden the catalogue | Add supported inspection tools, then guarded SQL and source/log reads | Future implementation |
| M5 — Demonstrate reliability | Evidence-based answers, access-control checks, operating notes, and a measured support-workflow demo | Future validation |

## Phase 1 boundary

Expose read-only capabilities. Exclude data changes, arbitrary CL commands, program execution, and job submission or control. `run_sql` is a later, restricted SELECT-only capability whose complete query and dependencies must be checked; a SELECT prefix alone is insufficient.

The [Phase 1 roadmap](project/phase-01-readonly-tools.md) is the source of truth for tool names, scope, limits, and deferred capabilities.

## Repository map

```text
MCP4i/
├── README.md
├── LICENSE
├── docs/
│   ├── README.md
│   ├── 00-roadmap.md
│   ├── anthropic-course-guide.md
│   ├── lesson-01-why-mcp.md
│   ├── lesson-02-mcp-architecture.md
│   ├── lesson-03-tool-contracts.md
│   ├── lesson-04-first-mock-server.md
│   ├── lesson-05-connect-to-ibmi.md
│   ├── lesson-06-inspection-tools.md
│   ├── lesson-07-guarded-sql.md
│   ├── lesson-08-jobs-source-logs.md
│   ├── lesson-09-resources-prompts-evaluation.md
│   └── lesson-10-operate-and-demonstrate.md
├── project/
│   └── phase-01-readonly-tools.md
├── cli_project/
│   └── README.md (Ollama course starter with MCP TODOs)
├── cli_project_COMPLETE/
│   └── README.md (completed local Ollama document demo)
├── cli_project_ts/
│   └── README.md (TypeScript counterpart to the starter)
└── rpgle-mcp-server/
    ├── README.md (deploy, compile, start, and verify)
    ├── MCPHTTP.sqlrpgle (one-program MCP server)
    ├── httpd.conf.example (dedicated HTTP instance)
    └── smoke_test.py (live protocol test client)
```

The CLI exercises teach generic MCP mechanics with fictional documents. The RPGLE source begins the read-only IBM i implementation, but connectivity and runtime behavior still need verification on a development partition. Use fictional or sanitized examples in public learning material; keep credentials and real system output out of the repository.

## License

[MIT](LICENSE).

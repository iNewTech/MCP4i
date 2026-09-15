# MCP4i — IBM i MCP Learning Bootcamp

Learn the Model Context Protocol (MCP) by designing, then building, an assistant that answers questions about an IBM i system using verified, read-only information.

The project connects AI concepts to familiar IBM i work: inspecting libraries and objects, understanding program dependencies, reading source, checking jobs, and querying approved data.

**Current stage: documentation and design.** Lessons 1–10 are available. All tools and runtime milestones below are planned; there is no implemented MCP server or IBM i connection yet.

## Start learning

1. Read the [learning roadmap](docs/00-roadmap.md) for the chapter order and milestone gates.
2. Study [Lesson 1 — Why MCP?](docs/lesson-01-why-mcp.md).
3. Continue with [Lesson 2 — MCP Architecture](docs/lesson-02-mcp-architecture.md).
4. Complete Lesson 2's design exercise using the [Phase 1 read-only tool roadmap](project/phase-01-readonly-tools.md).

Already studying Lesson 2? Start with its short recall exercise, then draw the architecture and design your first ten tools. The [learning index](docs/README.md) collects the available material.

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
| M3 — First IBM i read | Verify one bounded read on an authorized development system | Future implementation |
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
│   ├── lesson-01-why-mcp.md
│   └── lesson-02-mcp-architecture.md
└── project/
    └── phase-01-readonly-tools.md
```

Runtime folders, dependencies, and implementation exercises are intentionally still deferred: these chapters complete the study material and design work, not the server implementation. Use fictional or sanitized examples in public learning material; keep credentials and real system output out of the repository.

## License

[MIT](LICENSE).

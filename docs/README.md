# MCP4i Learning Index

[Repository home](../README.md) · [Project article](blog-mcp4i-for-ibmi-developers.md) · [Roadmap](00-roadmap.md) · [Project scope](../project/phase-01-readonly-tools.md)

## Available chapters

| Read in order | Main question | What you produce |
| --- | --- | --- |
| [00 — Roadmap](00-roadmap.md) | What are we learning and building? | A view of the learning path and milestone checks |
| [01 — Why MCP?](lesson-01-why-mcp.md) | Why does an LLM need controlled access to external information? | A problem statement and a comparison of three ways to answer an IBM i question |
| [02 — MCP Architecture](lesson-02-mcp-architecture.md) | Who receives, routes, checks, and executes a request? | An architecture diagram, a request trace, and ten read-only tool designs |
| [03 — Tool Contracts](lesson-03-tool-contracts.md) | How do we make each capability testable and bounded? | Ten reviewed contracts with inputs, outputs, errors, and limits |
| [04 — First Mock Server](lesson-04-first-mock-server.md) | How do we test MCP before connecting IBM i? | A fictional `get_system_info` discovery and call design |
| [05 — Connect to IBM i](lesson-05-connect-to-ibmi.md) | How do identity, authority, release, and transport affect a read? | An authorized development-system connection plan |
| [06 — Inspection Tools](lesson-06-inspection-tools.md) | How are IBM i libraries, objects, files, and references different? | Focused metadata-tool designs with coverage limits |
| [07 — Guarded SQL](lesson-07-guarded-sql.md) | How can a SELECT boundary be enforced? | A SQL allowlist, rejection cases, and workload limits |
| [08 — Jobs, Source, and Logs](lesson-08-jobs-source-logs.md) | How do we read changing and sensitive operational data safely? | Bounded job, source, and log contracts |
| [09 — Resources and Evaluation](lesson-09-resources-prompts-evaluation.md) | How do context selection and evaluation improve answers? | Resource/prompt contracts and a grounded-answer test set |
| [10 — Operate and Demonstrate](lesson-10-operate-and-demonstrate.md) | What makes the project useful and supportable? | A measured demo script and operating guide |

The [Phase 1 tool roadmap](../project/phase-01-readonly-tools.md) accompanies the full curriculum. It describes intended capabilities, not installed tools.

## Companion course

If you are taking [Anthropic Academy's Introduction to Model Context Protocol](https://anthropic.skilljar.com/introduction-to-model-context-protocol/303756), use the [course-to-MCP4i guide](anthropic-course-guide.md) to pair its sections with these chapters. The course's Python and document-management exercises teach MCP mechanics; the project homework applies those mechanics to authorized IBM i reads.

## How to study a lesson

1. Read the objectives and attempt the opening question before consulting the explanation.
2. Work through the fictional IBM i example. Trace where every fact comes from.
3. Read the English and Hinglish summaries to check your mental model.
4. Use the linked primary reading and selected video sections to reinforce the topic.
5. Complete the homework without copying the worked example.
6. Submit the answers for review. Correct any failed check before moving on.

The video references supplement these self-contained lessons. Some course access requires sign-in or enrollment; implementation demonstrations can use an older protocol version. Follow the lesson's version note for protocol details.

## Your next study session: Lesson 2

Start at [Lesson 2](lesson-02-mcp-architecture.md), recall why a model cannot know a live job status without evidence, and then trace `get_job_status` through the architecture. Finish by designing the first ten tools listed in the project roadmap.

No homework has been graded in this repository. Keep personal answers and review notes outside the published lessons; if a private `.learning/` folder is introduced later, it must be ignored by Git before storing personal material.

## Implementation boundary

Lessons 1–10 are now available as study material. A separate [one-tool RPGLE server](../rpgle-mcp-server/README.md) has source and deployment instructions, but has not been compiled or tested on IBM i. The course's remaining implementation exercises and live connection still require validation.

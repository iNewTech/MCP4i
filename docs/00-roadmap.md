# 00 — Learning and Project Roadmap

[Learning index](README.md) · [Next: Lesson 1](lesson-01-why-mcp.md)

## The outcome

Build toward an IBM i assistant that can answer questions such as:

- “Which development partition supplied this information?”
- “What objects are in the approved application library?”
- “What recorded dependencies does this program have?”
- “What is the observed status of this specific job?”

A useful answer names its source, states when it was observed, and acknowledges missing or incomplete evidence. A convincing sentence alone is not a successful result.

This is also practice in Forward Deployed Engineering (FDE): understand a user's workflow, choose a defensible scope, integrate with an existing system, and demonstrate measurable value. That emphasis follows the customer-delivery responsibilities described in [OpenAI's FDE role](https://openai.com/careers/forward-deployed-engineer-(fde)-sf-san-francisco/).

## Learning method and prerequisites

Bring basic familiarity with IBM i libraries, objects, jobs, and files. The lessons define new AI terms as they appear. Lessons 1–2 require only reading and written design work; access to a real partition comes later.

Use **theory → example → paper demo → exercise → project feature** for every chapter. A paper demo means tracing fictional requests and results without running a system. Plan study time around your schedule; passing depends on demonstrated reasoning, not hours spent.

For every design decision, explain the user need, the input and output, the allowed access, one failure case, and how you would check the result.

## Chapter sequence

Lessons 1–10 are now written as study material. The rows define the intended order and project gates; implementation remains future work.

| Chapter | Learn | Project contribution |
| --- | --- | --- |
| [01 — Why MCP?](lesson-01-why-mcp.md) | Model knowledge, live evidence, tool use, standardized integration | Explain the customer problem and read-only scope |
| [02 — MCP Architecture](lesson-02-mcp-architecture.md) | Host/client/server responsibilities; tools, resources, prompts; request flow | M1: draw the system and design ten tool contracts |
| 03 — Tool contracts and boundaries | Names, descriptions, input rules, output shapes, errors, authority | Review contracts and select compatible host, protocol, and SDK versions |
| 04 — First mock MCP server | Discovery, calling one tool, inspecting results | M2: fictional `get_system_info` demonstration |
| 05 — Connect to IBM i | Identity, connection configuration, IBM i Services, release support | M3: first verified read on a development partition |
| 06 — Libraries, objects, and references | Naming, library-list context, metadata, dependency limitations | M4: focused inspection tools; defer unsupported methods |
| 07 — Guarded SQL reads | SELECT subset, nested operations, routine access, result and execution limits | M4: `run_sql` only after the SQL boundary review |
| 08 — Jobs, source, and logs | Qualified job IDs, source members, paging, timestamps, sensitive fields | M4: bounded operational and source reads |
| 09 — Resources, prompts, and answer quality | Context selection, reusable workflows, evidence, misleading retrieved text | Candidate schema resources and diagnostic prompts; evaluation cases |
| 10 — Operate and demonstrate | Logging, recovery, latency, capacity, access checks, workflow impact | M5: reproducible demo and operating guide |

Security and failure handling belong in every chapter. Chapter 10 consolidates the evidence. RAG (retrieving relevant material before answering) and agents with longer tool workflows are later extensions, after the read-only foundation is reliable.

## Milestones and gates

| Milestone | Required evidence before proceeding |
| --- | --- |
| M0 — Learning foundation | Available curriculum and scope; learner explains why current system facts require evidence |
| M1 — Design the first slice | Ten contracts, a component diagram, a successful request trace, three failure traces, and a defense of access and result limits |
| M2 — First runnable slice | A compatible client discovers and calls the mock tool; fictional data is labeled; invalid input produces a clear error |
| M3 — First IBM i read | Authorized development-system read matches a trusted comparison; wrong-target and access-denied cases are handled; credentials stay outside prompts and source control |
| M4 — Broaden the catalogue | Each enabled tool has a verified backend, bounded output, documented limitations, and access checks; SQL passes its separate gate |
| M5 — Demonstrate reliability | Repeatable success and failure cases, supported-system notes, operating instructions, and observed workflow measurements |

**Current position:** M0 documentation is available; M1 is the next design exercise. No learner assessment, runtime milestone, or IBM i compatibility check is recorded as passed.

At each review, change one constraint. For example: “The support team now has 20 users,” or “Program-reference metadata is unavailable on this partition.” Defend which part of the design changes and why. Fix individual failed checks before advancing; an average quiz score does not override them.

## Phase 1 delivery order

1. Design the first ten focused tools in the [tool roadmap](../project/phase-01-readonly-tools.md).
2. Later, implement one fictional-data tool to learn the MCP exchange.
3. Connect that narrow capability to an authorized development environment.
4. Add the remaining supported inspection tools in small, reviewable increments.
5. Add restricted SQL, source reading, and logs only after their access and workload limits are established.
6. Demonstrate a complete support question with traceable evidence and explicit uncertainty.

Read-only describes permitted operations on the target system. It still requires data-access limits and workload control. Arbitrary commands, program execution, job changes, and database writes remain outside this phase.

## Measure a useful outcome

For a future demo, use a fixed set of fictional or sanitized support questions. Record answer correctness, source and timestamp coverage, denied-request behavior, response time, and the manual steps saved. Measure a baseline before claiming improvement.

Start with one learner and one request at a time. Before expanding, estimate peak concurrent users, calls per question, and average query duration. Use that estimate to propose a concurrency cap and a timeout, then validate them on the target workload. Those values are design assumptions until measured.

## Summary

**English:** Learn the problem, design a bounded interface, prove one read, then expand with evidence.

**Hinglish:** Pehle problem samjho, limited interface design karo, ek read verify karo, phir evidence ke saath features badhao.

Continue to [Lesson 1](lesson-01-why-mcp.md), or resume [Lesson 2](lesson-02-mcp-architecture.md).

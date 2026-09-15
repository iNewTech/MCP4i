# Lesson 3 — Tool Contracts and Boundaries

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Phase 1 catalogue](../project/phase-01-readonly-tools.md)

**Project milestone:** finish M1. Turn the first ten read-only ideas into contracts another engineer could implement and review.

## Why this lesson matters

A tool contract is the agreement between a caller and a server. It says what a tool is for, what inputs are valid, what comes back, and what happens when the request cannot be completed. A vague description such as “get information about an object” leaves too many decisions to runtime.

For an FDE, this is the point where a customer request becomes a bounded deliverable. Before choosing an SDK, ask: who needs the answer, which system is authoritative, how fresh must it be, what access is permitted, and how will we detect a wrong answer?

## 1. Anatomy of a contract

Every Phase 1 tool should document:

1. User question and intended user.
2. Name, purpose, and when not to use it.
3. Required and optional arguments, types, normalization, and validation.
4. Target and authority boundary.
5. Success result, evidence fields, and completeness limits.
6. Invalid, denied, missing, unsupported, and timeout outcomes.
7. Row, byte, time, and concurrency limits.
8. Ordering, paging, and consistency expectations.
9. Audit and redaction behavior.
10. Acceptance checks and a known limitation.

MCP tool definitions use JSON Schema for input validation. The schema documents a boundary; it does not replace server-side checks. Treat tool descriptions and annotations as untrusted when they come from an untrusted server. Read the [MCP tools specification](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

### Worked contract: `get_job_status`

| Field | Decision |
| --- | --- |
| User question | “What state did DEV report for this exact job?” |
| Input | `job_number`, `user`, `name`; all required strings, normalized without silently changing identity |
| Reject | Missing component, malformed identifier, wildcard, target override, or excessive diagnostic detail |
| Success | Qualified ID, raw reported state, normalized display state if mapped, target, observation time, and field limitations |
| Not visible | A distinct outcome when authority prevents us from confirming whether a match exists |
| Limits | One job, one bounded read, configured deadline; no polling loop |
| Safety | Never cancel, hold, release, submit, or modify the job |
| Check | Compare a fictional response with a trusted fixture and verify the wrong target is rejected |

“Job not found” and “job not visible” can have different security meanings. The contract must specify which distinction the backend is allowed to reveal.

## 2. Names that help models and people

Use a stable verb-plus-object name such as `get_object_info`, `list_members`, or `read_source`. The name should be unique, predictable, and free of hidden side effects. Descriptions should state the scope and exclusion: “Read metadata for one qualified object; does not read records or execute the object.”

Avoid names that expose implementation details (`call_qsys_api`) or imply unsafe breadth (`do_anything`). If a backend changes, the user-facing contract should remain stable when the behavior remains stable.

## 3. Result design and errors

Return structured fields where the host can preserve them, plus a concise human-readable summary. Include provenance: target, timestamp, scope, and whether the result was truncated. Errors should be typed conceptually even if the first mock uses text:

| Class | Example | User-facing meaning |
| --- | --- | --- |
| Invalid input | Job number missing | Correct the request |
| Denied | Caller lacks authority | Access was not granted; do not guess |
| Not visible | Backend hides existence | No conclusion about existence |
| Unsupported | Release lacks required service | Capability is unavailable on this target |
| Timeout | Backend exceeded deadline | Observation was not obtained |
| Backend failure | Connection dropped | Retry policy or operator action is needed |

An empty list is a valid result only when the lookup completed successfully. Do not turn an error into an empty success.

## Paper walkthrough

A support engineer asks for objects in `APPLIB` matching `ORD*`.

1. The host selects `list_objects` and supplies `library=APPLIB`, `pattern=ORD*`, `type=*FILE`, `limit=100`.
2. The server rejects `library=QSYS` if that library is outside this caller's configured scope.
3. The adapter performs a bounded metadata read.
4. The response says 12 objects returned, ordered by qualified name, observed at a timestamp, with `next_page` absent.
5. The answer says “12 visible *FILE objects matched in APPLIB on DEV,” not “these are all files on the system.”

If the backend times out after reading 10 objects, return a timeout or partial-result contract only if partial results are explicitly defined. Otherwise, report failure and avoid implying completeness.

## Exercise

Complete the ten contracts in the Phase 1 roadmap. Then choose one contract and defend it under these changed constraints: the target library has 2 million objects and the support team asks for results in 2 seconds. Explain which filters, paging, indexes, or limits change and what must be measured.

Do not write implementation code. A good answer makes it possible to write tests without deciding behavior later.

## Homework and gate

- Define all ten starter contracts.
- Add one success fixture and four failure fixtures for two tools.
- Identify one ambiguity in each of `get_library_list`, `list_libraries`, and `get_database_relations`.
- Explain why an input schema cannot authorize a target by itself.

Gate: every tool has an explicit scope, bounded output, provenance, and failure semantics. Revise before Lesson 4.

## Summary

**English:** A tool contract turns a broad request into testable behavior with clear evidence and limits.

**Hinglish:** Tool contract broad request ko testable behavior mein badalta hai, jisme evidence, limits, aur failures clear hote hain.

## Reading and video

- Primary: [MCP tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools), especially schemas and `tools/call`.
- IBM context: [IBM i Services](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Creating an MCP Server”; focus on the interface before the framework.

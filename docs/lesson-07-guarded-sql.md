# Lesson 7 — Guarded SQL Reads

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [SQL policy](../project/phase-01-readonly-tools.md)

**Project milestone:** M4 SQL gate. Keep generic SQL disabled until the parser, authority, workload, and evidence checks pass.

## Why generic SQL is difficult

SQL is a language, not a single read operation. A statement that starts with `SELECT` can invoke views, routines, nested expressions, or data-change constructs. It can also scan far more rows than the caller expects. A regular expression or first-keyword check cannot prove safety.

The first version should prefer fixed, parameterized queries behind focused tools. A generic `run_sql` tool is a later capability for approved use cases.

## 1. Define the allowed subset

The policy must specify:

- one statement only;
- approved SELECT forms and whether `WITH` is supported;
- approved schemas, tables/views, columns, and functions;
- parameterized values and allowlisted identifiers;
- row, byte, duration, and concurrency caps;
- ordering and paging requirements;
- redaction and audit behavior.

Reject writes, DDL, authority changes, calls, procedural blocks, multiple statements, exports, lock-for-update behavior, and unsupported syntax. Review reachable views and routines, not only surface keywords.

IBM documentation distinguishes read and modifying SQL data classifications and documents data-change table references. See the [IBM SQL reference](https://www.ibm.com/docs/ssw_ibm_i_75/db2/rbafztabref.htm) and the [Phase 1 policy](../project/phase-01-readonly-tools.md).

## 2. Parse, authorize, execute, explain

The safe conceptual sequence is:

1. Parse the complete statement with a Db2 for i-compatible parser or a deliberately narrow grammar.
2. Validate structure and reject unsupported forms.
3. Authorize every referenced object and approved column.
4. Bind values and apply server caps.
5. Execute using a least-privilege identity.
6. Return bounded rows with target, timestamp, ordering, and truncation information.
7. Audit the safe query shape without logging sensitive values by default.

Database privileges and server policy reinforce each other. Neither a model instruction nor a tool annotation is sufficient.

## Paper walkthrough

Allowed: “Show the first 20 orders for customer `C42` from the approved view.”

1. The server checks the view and columns against the allowlist.
2. The customer value is bound as a parameter.
3. The query has a deterministic order and server row cap.
4. The result includes 20 rows, `truncated=true` if more remain, target, and observation time.

Rejected: “SELECT * FROM APPLIB.ORDERS; UPDATE ...” because it contains multiple statements. Also reject a SELECT that reaches an unapproved routine or an unsupported data-change construct, even when its first token is SELECT.

## Workload and data exposure

A small response does not guarantee a small database workload. Enforce execution time, inspect plans where appropriate, restrict joins and functions, and monitor concurrency. Minimize sensitive columns before results reach the model. Explain whether row-level security or masking is supplied by IBM i, the database, or MCP4i.

## Homework and gate

- Write an allowlist for one fictional reporting view.
- Classify five statements as allowed, rejected, or requiring review; explain why.
- Design timeout, row, byte, and concurrency limits.
- List four ways a query could expose data outside the apparent table.
- Changed constraint: 20 users submit reports simultaneously. Explain whether to queue, reject, or degrade requests and what measurements decide.

Gate: the learner can explain why parsing the full statement, authorizing dependencies, and limiting work are all required. No generic SQL implementation is authorized by this lesson.

## Summary

**English:** SELECT-only is a policy and enforcement problem, not a keyword filter.

**Hinglish:** SELECT-only sirf keyword check nahi; complete parsing, authority, dependencies, aur workload limits ka problem hai.

## Reading and video

- Primary: [IBM SQL data-change references](https://www.ibm.com/docs/ssw_ibm_i_75/db2/rbafztabref.htm), [IBM i Services](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm).
- MCP: [Tools specification](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Creating an MCP Server”; focus on validating a domain-specific tool rather than copying a generic executor.

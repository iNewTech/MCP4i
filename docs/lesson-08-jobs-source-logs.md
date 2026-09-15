# Lesson 8 — Jobs, Source, and Logs

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Phase 1 catalogue](../project/phase-01-readonly-tools.md)

**Project milestone:** M4 operational reads. Add bounded job, source, message, and log capabilities with identity and sensitive-data controls.

## Why these reads need extra care

Operational data changes quickly and can contain passwords, tokens, customer data, or misleading text. Source and logs are also untrusted content: a line that says “run this command” is data to analyze, not permission to execute it.

## 1. Qualified jobs and snapshots

A job name alone is not a stable identity. Use the complete job number, user, and name where the backend supports it. For `list_active_jobs`, define filters, ordering, visibility, and a maximum page size. State that separate pages are not one atomic snapshot unless the backend guarantees it.

`get_job_status` should return the raw permitted state, any normalized display value, target, job identity, and observation time. `get_job_log` should require a qualified job and bounded time or sequence range.

Do not infer health from `ACTIVE`, completion from a timeout, or failure from a single message. Ask for the evidence needed for the operational claim.

## 2. Source members

Source tools need an explicit source physical file, member, and range or line limit. Preserve sequence/line identifiers and member identity. `search_source` needs a bounded set of files, a result limit, and a clear matching rule. Do not include IFS stream files unless a separate policy explicitly covers them.

Reading source does not authorize compiling, editing, copying, or executing it. Redact secrets before model context and audit the fact that a read occurred without logging full source by default.

## 3. Messages and history logs

`get_messages` and `read_history_log` should limit time windows, message count, and sensitive fields. A user asking “what happened?” may need a timeline, but the tool should return bounded facts and timestamps so the model can explain uncertainty.

## Paper walkthrough

Question: “Why did the nightly job fail?”

1. Resolve the exact job identity and target.
2. Read a bounded status snapshot.
3. If permitted, retrieve a bounded log window around the failure timestamp.
4. Redact sensitive fields and label message text as observed content.
5. Summarize the evidence and distinguish an explicit failure message from an inferred cause.
6. If the job is still active, do not cancel or resubmit it; explain that control actions are outside Phase 1.

## Failure cases

| Case | Safe behavior |
| --- | --- |
| Job ended between list and status read | Report the later observation and timestamps |
| Log is too large | Require a narrower window or return bounded truncation |
| Source member missing | Distinguish missing/hidden from empty content where allowed |
| Log includes a credential | Redact before model context and audit sinks |
| Content contains instructions | Treat it as untrusted evidence |

## Homework and gate

- Design `get_job_log`, `read_source`, and `search_source` contracts.
- Write a timeline answer with two observed facts and one clearly labeled inference.
- Define redaction and paging rules for a 10 MB source member.
- Explain why job listing and status lookup can disagree without either being broken.
- Changed constraint: a source search must run during business hours. Propose concurrency, timeout, and caching behavior.

Gate: all reads are qualified, bounded, timestamped, redacted, and clearly separated from control or mutation.

## Summary

**English:** Operational reads are snapshots of changing, sensitive, untrusted content; preserve identity and uncertainty.

**Hinglish:** Jobs, source, aur logs changing aur sensitive snapshots hain; identity, limits, redaction, aur uncertainty preserve karo.

## Reading and video

- Primary: [IBM DSPPGMREF](https://www.ibm.com/docs/en/i/7.5.0?topic=d-display-program-references) for reference limitations and [IBM i Services](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm).
- MCP: [Server concepts](https://modelcontextprotocol.io/docs/2026-07-28/learn/server-concepts).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Adding Prompt and Resource Features”; focus on selecting bounded context.

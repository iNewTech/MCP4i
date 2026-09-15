# Lesson 10 — Operate and Demonstrate the IBM i Assistant

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Lesson 9](lesson-09-resources-prompts-evaluation.md)

**Project milestone:** M5. Produce a reproducible, measured support-workflow demonstration and an operating guide.

## What “done” means

A demo is not a screenshot of a successful chat. It should show a user question, the permitted tool path, evidence with target and time, a useful answer, and a failure handled honestly. An operator should be able to repeat the scenario and understand what to do when a dependency fails.

## 1. Operational design

Document:

- supported IBM i releases, services, PTF assumptions, and authorities;
- target configuration and secret handling;
- enabled tool catalogue and per-tool limits;
- timeout, retry, paging, and concurrency behavior;
- logs, metrics, audit fields, redaction, and retention;
- deployment and rollback steps;
- incident response for wrong target, leakage, overload, and stale data.

Measure request count, duration, backend duration, timeout rate, denied requests, result size, truncation, and evaluation failures. Keep model latency separate from IBM i latency so the right team can diagnose it.

## 2. Capacity and recovery

Start with an estimate: users × questions per minute × tool calls per question. Add the expected concurrent backend jobs and average query duration. Use conservative caps until measured. A queue can protect IBM i but add waiting time; rejection protects latency but reduces availability. Choose deliberately.

Recover without hiding uncertainty. Retry a transient connection failure within a deadline, but do not retry a denied request. If the target identity cannot be established, fail closed. Preserve correlation IDs across host, MCP client, server, and backend logs without exposing credentials.

## 3. Customer-facing demonstration

Use a fixed, fictional or sanitized question set. Show:

1. “Which partition answered?”
2. “What is the status of this exact job?”
3. “Which objects are recorded as program references?”
4. A denied request.
5. A timeout or unsupported capability.
6. A request outside Phase 1, such as `run_cl` or `update_record`.

For each, display evidence, timestamp, limits, and the next safe action. Measure a manual baseline: time to answer, number of screens or commands, and correction rate. Compare it with the assistant after the evaluation set passes.

## 4. FDE delivery conversation

Ask the support team what decision the answer enables, not only which feature they want. Confirm who owns authority, who handles incidents, what data may leave IBM i, and what success metric matters. A small reliable workflow is a better first deployment than a catalogue no one trusts.

## Final exercise

Write an operating guide and a five-minute demo script. Include the architecture, supported scope, sample transcripts, metrics, rollback, and three known limitations. Defend this changed constraint: latency must remain under 3 seconds for 95% of status lookups while IBM i is under peak load. Explain which cap or feature you would change, what you would measure, and what behavior is allowed to degrade.

## M5 gate

- [ ] The demo is repeatable from a clean configuration.
- [ ] Every claim is traceable to a returned observation or labeled inference.
- [ ] Wrong target, denied, timeout, unsupported, and out-of-scope requests are visible.
- [ ] Limits, logs, redaction, and recovery are documented.
- [ ] The workflow has a measured baseline and a meaningful outcome metric.
- [ ] Operators know how to disable a tool or roll back safely.

Passing this gate means the learning project has a defensible demonstration. It does not mean the system is ready for unrestricted production or write operations.

## Summary

**English:** Production value comes from reliable evidence, safe failure, measurable workflow impact, and clear ownership.

**Hinglish:** Production value reliable evidence, safe failure, measurable workflow impact, aur clear ownership se aata hai.

## Reading and video

- Primary: [MCP architecture and transport](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture), [MCP tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).
- FDE context: [OpenAI FDE role](https://openai.com/careers/forward-deployed-engineer-(fde)-sf-san-francisco/).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Creating and Deploying Remote Servers” and “Conclusion”; focus on operating evidence and handoff.

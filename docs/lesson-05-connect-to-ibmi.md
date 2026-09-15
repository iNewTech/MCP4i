# Lesson 5 — Connect to IBM i Safely

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Phase 1 boundary](../project/phase-01-readonly-tools.md)

**Project milestone:** M3. Verify one bounded read against an authorized development partition.

## Why connection design comes first

“Connect to IBM i” is not one decision. We must choose the host and transport, the IBM i connection method, the identity, the release and service support, timeout behavior, and how we prove the result came from the intended partition.

Never test first against production because it is convenient. The first target must be a designated development environment with a known baseline and a least-privilege identity.

## 1. Trust boundaries

The host may be on a developer laptop, the MCP4i server may run as a local process or service, and IBM i may be remote. Credentials belong in protected configuration or a secret manager, never in a model argument, prompt, source file, or tool result.

The server must bind the allowed target in trusted configuration. A model cannot ask to change `DEV` to `PROD` or provide a new password as a normal tool argument.

## 2. Backend selection

IBM i Services provide SQL views, procedures, and functions for many system questions. Their availability and behavior depend on the IBM i release, Technology Refresh, and PTF level. Verify a service on the actual partition and record its required authority. See IBM's [Services overview](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm).

For each tool, compare:

| Choice | Question to answer |
| --- | --- |
| IBM i Service | Is the service documented and available on this release? |
| Database metadata | Does it answer the exact question or only a related one? |
| System API | Can it be read without command execution or temporary writes? |
| Existing dataset | Who updates it, how old can it be, and what coverage is missing? |

Do not call a display command that writes an outfile and claim the overall operation is read-only. A backend that creates or replaces objects is outside Phase 1 until separately reviewed.

## 3. Identity and authority

Use a dedicated service identity with the smallest required read authority. Test three identities or cases: allowed, denied, and target not available. Map IBM i authority errors into safe user-facing outcomes without exposing secrets or unnecessary internal details.

Connection pooling needs special care. If several users share a backend job, the result must identify the actual job context and apply per-user authorization before the shared read. Never assume a pooled connection has the user's interactive library list.

## Paper walkthrough: first real read

1. Confirm the target label and host identity through an out-of-band operator check.
2. Configure one identity with only the rights needed for `get_system_info`.
3. Run the same question against the mock and the development partition.
4. Compare returned system identity and release with a trusted operator observation.
5. Record timestamp, release/PTF context, authority, duration, and unavailable fields.
6. Disconnect and review logs for credentials or sensitive output.

Success means “the bounded observation matched the trusted comparison,” not “the connection opened.”

## Failure and recovery

Retry transient network failures only within a deadline and a small attempt budget. Do not retry invalid input or denied authority. If identity is uncertain, fail closed. A timeout does not mean the job ended or the object is absent.

## Homework and gate

- Write a target and identity checklist for a fictional DEV partition.
- Choose a backend for `get_system_info` and list the release/authority evidence required.
- Draw the credential and data paths.
- Define three safe error messages for denied, unavailable, and timeout outcomes.
- Change the constraint: the server must support DEV and QA. Explain how target binding and result provenance prevent cross-environment confusion.

Gate: one read is reproducible, authorized, target-identified, compared with trusted evidence, and free of credential leakage. No production connection is implied by completing this lesson.

## Summary

**English:** IBM i connectivity is a security and evidence problem as well as a driver problem.

**Hinglish:** IBM i connection sirf driver ka kaam nahi; security, authority, target identity, aur evidence bhi design karna hota hai.

## Reading and video

- Primary: [IBM i Services](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm) and [MCP transport overview](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture#transport-layer).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Creating and Deploying Remote Servers”; focus on authentication and deployment boundaries, not copy-paste setup.

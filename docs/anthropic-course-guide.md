# Anthropic MCP Course: MCP4i Study Guide

[Learning index](README.md) · [Project roadmap](00-roadmap.md)

The [Anthropic Academy course shared by the learner](https://anthropic.skilljar.com/introduction-to-model-context-protocol/303756) is a useful companion to this bootcamp. Anthropic's [course catalogue](https://anthropic.skilljar.com/) and [course outline](https://anthropic-partners.skilljar.com/introduction-to-model-context-protocol) describe Python exercises for building an MCP server and client, inspecting tools, and using resources and prompts. The course lists Python, JSON, and HTTP familiarity as prerequisites. Registration is advertised as free; sign-in may be required to view lessons.

The MCP4i chapters remain the main study path. Use the course to see the protocol in action, then answer the IBM i design question for that chapter. Its document-management examples include editing; those operations are outside MCP4i Phase 1.

Before the Python exercises, use Astral's [uv overview](https://docs.astral.sh/uv/) and [installation instructions](https://docs.astral.sh/uv/getting-started/installation/) to choose the method for your operating system. After installing, `uv --version` confirms that the command is available. Lessons 1–3 are reading and design work, so uv is only needed when you start the hands-on exercises.

| Anthropic course section | Study alongside | Translate the example into MCP4i |
| --- | --- | --- |
| Introducing MCP; MCP clients | [Lessons 1–2](lesson-01-why-mcp.md) | Draw host, client, server, and IBM i; trace one `get_job_status` request and result. |
| Project setup; defining tools; server Inspector | [Lessons 3–4](lesson-03-tool-contracts.md) | Specify the `get_system_info` contract, then inspect a fictional, clearly labeled read result. |
| Implementing a client | [Lesson 4](lesson-04-first-mock-server.md) | Trace discovery, call, error, and response handling for the mock server. |
| Defining and accessing resources | [Lesson 9](lesson-09-resources-prompts-evaluation.md) | Design a bounded URI for approved schema metadata and state its freshness and access rules. |
| Defining prompts; prompts in the client | [Lesson 9](lesson-09-resources-prompts-evaluation.md) | Design a dependency-explanation prompt that separates observed references from inference. |
| Final assessment | After [Lesson 9](lesson-09-resources-prompts-evaluation.md) | Use it to check MCP concepts; complete the MCP4i homework and review gates separately. |

## How to use the exercises

1. Watch a course section after reading its mapped MCP4i lesson.
2. Pause before the course demonstration and predict which component sends the next request and what the response must contain.
3. Complete the course exercise in its own environment if available. Keep any sample editing operation away from an IBM i connection.
4. Write the corresponding MCP4i design answer using fictional data. Record a failure case and the source of every asserted fact.
5. Compare any protocol message or SDK call in the course with the chosen MCP specification and SDK version before using it in a future implementation. Course videos may show an older startup exchange.

The course teaches generic MCP mechanics. It does not verify IBM i service availability, release support, object authority, SQL safety, or this project's read-only boundary. Use [IBM i Services documentation](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm) and the [Phase 1 tool policy](../project/phase-01-readonly-tools.md) for those decisions.

**English:** Learn MCP mechanics from the course, then defend each IBM i read with a precise contract and evidence.

**Hinglish:** Course se MCP mechanics seekho, phir har IBM i read ke liye exact contract aur evidence define karo.

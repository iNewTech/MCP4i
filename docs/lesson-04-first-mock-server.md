# Lesson 4 — First Mock MCP Server

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Previous: Tool contracts](lesson-03-tool-contracts.md)

**Project milestone:** M2. Demonstrate discovery and one safe call with fictional data. This lesson describes the design and test plan; it does not add runtime code.

## Why mock first?

A mock server is a small stand-in that returns predictable, labeled data. It lets us test the MCP exchange, argument validation, errors, and answer grounding before credentials, network behavior, and IBM i release differences complicate the diagnosis.

The mock must make its fiction obvious. It is useful for protocol behavior, not proof that an IBM i backend works.

## 1. The smallest useful slice

Implement later only one capability first: `get_system_info` with an empty argument object and a fixed fictional response. The host should be able to discover the tool, propose a call, receive a result, and show the evidence.

The minimum test scenarios are:

| Scenario | Expected observation |
| --- | --- |
| Discover | Tool has a stable name, description, and input schema |
| Valid call | Result says `fictional: true`, includes target and timestamp, and has no credentials |
| Unknown tool | Clear protocol/tool error |
| Unexpected argument | Validation error; no backend operation |
| Simulated failure | Error remains distinct from an empty successful result |
| Repeated call | Same fixture semantics; no hidden state change |

## 2. Discovery and call mental model

The host's client asks what the server supports, caches the tool definition according to protocol guidance, and makes a call only after the model proposes it. The server validates the call again. A model suggestion is never proof that an input is valid.

The exact startup method depends on the negotiated MCP version and SDK. Current MCP documentation and older course examples may show different discovery or initialization names. Pin a compatible version during implementation and test the messages at the wire boundary. See the [architecture overview](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture) and [tools specification](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

## 3. Testable server shape

Use a skeleton like this when implementation begins, leaving the exercise body for the learner:

```text
server = create_server(identity, capabilities)
server.register_tool(get_system_info_contract, handler=get_system_info_stub)
server.start(transport_config)
```

The important design is the separation between contract, handler, transport, and fixture. Do not let a test fixture silently become a production credential or target.

## Paper walkthrough

1. A host connects to `mcp4i-mock` and discovers one tool.
2. The model proposes `get_system_info`.
3. The host sends an empty argument object.
4. The mock returns: `target=DEV-MOCK`, `release=fictional-7.5`, `observed_at=...`, `fictional=true`.
5. The host asks the model to answer using only the returned fields.
6. The response says “The mock reports ...” and does not call the result a real IBM i observation.

If the model says “your production partition is IBM i 7.5,” the evaluation has found a grounding failure even though the sentence sounds plausible.

## Operational choices

Keep logs on stderr or a structured test sink, never inside the protocol result by accident. Give the mock a deterministic clock or inject the timestamp so tests can compare results. Keep the transport choice separate from the fake backend. The same fixture should be callable through the selected local transport and, later, through an integration test client.

## Homework and gate

- Write a discovery transcript in plain language.
- Specify the fictional result schema and three invalid calls.
- Define how a test proves that no IBM i connection was opened.
- Write one grounded answer and one hallucinated answer; explain the difference.
- Change the constraint: the mock must serve 10 concurrent clients. Identify what remains deterministic and what must be measured.

Gate: the design distinguishes a protocol test from an IBM i compatibility test, labels fiction, and handles invalid requests without side effects.

## Summary

**English:** A mock isolates protocol behavior and grounding before external-system risk is introduced.

**Hinglish:** Mock server protocol aur grounding test karta hai, bina real IBM i connection ke risk ke.

## Reading and video

- Primary: [MCP architecture example](https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture) and [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Creating an MCP Server” and “Creating an MCP Client”; focus on discovery and error paths.

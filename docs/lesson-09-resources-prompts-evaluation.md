# Lesson 9 — Resources, Prompts, and Answer Quality

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Lesson 8](lesson-08-jobs-source-logs.md)

**Project milestone:** design optional resources and prompts, then create an evaluation set for evidence-based answers.

## 1. Tools, resources, and prompts together

Tools perform bounded operations. Resources give the application addressable context. Prompts provide user-selected templates for repeatable workflows. The distinction matters because control and freshness differ.

For MCP4i, a schema resource might identify the structure of an approved table; a source member could be a resource only if the host can select and bound it safely. A prompt such as `explain_program_dependencies` can require the model to separate recorded references, database relations, and inference. The prompt does not grant extra authority or execute every tool it mentions.

Read the [MCP server concepts guide](https://modelcontextprotocol.io/docs/2026-07-28/learn/server-concepts) and [resources specification](https://modelcontextprotocol.io/specification/2026-07-28/server/resources).

## 2. Grounded answering

An answer is grounded when its claims are supported by the evidence supplied for that turn. “The job is ACTIVE” needs a job status result, target, and observation time. “The program will fail after changing file X” is a prediction that may require more evidence and should not be stated as fact.

Use a simple claim table during review:

| Claim | Evidence | Status |
| --- | --- | --- |
| Job was ACTIVE | Status result at 09:30 UTC | Supported snapshot |
| Job is healthy | No health metric provided | Unsupported |
| Program references ORDERS | Recorded reference result | Supported with coverage limit |

Retrieved source, logs, and descriptions can contain misleading instructions. The host and server policy outrank those strings.

## 3. Evaluation before polish

An **evaluation** is a repeatable test of quality. Build a small set of fictional questions with expected evidence, safe behavior, and failure cases. Measure correctness, target/source attribution, unsupported claims, refusal behavior, latency, and result completeness.

Include adversarial cases: ambiguous jobs, wrong library, denied access, stale program references, SQL write attempts, prompt injection in source comments, and partial pages. A fluent answer that violates a boundary fails the evaluation.

## Paper workflow

Prompt: “Explain why `BILLING` uses `ORDERS`.”

1. Select a user prompt that asks for a dependency explanation.
2. Retrieve the approved program-reference result and, separately, file metadata if needed.
3. Ask the model to label observed references, missing evidence, and inference.
4. Evaluate whether it claims runtime behavior from build metadata.
5. Record the failure category if it does.

## Homework and gate

- Define one resource URI and one prompt contract with scope and freshness rules.
- Create 15 fictional evaluation cases: five successes, five access/availability failures, and five adversarial inputs.
- Define pass criteria for evidence attribution and unsupported claims.
- Explain when a resource should be selected manually rather than injected automatically.
- Changed constraint: source text can contain malicious instructions. Describe the trust boundary and test case.

Gate: resources and prompts have clear control models, and the evaluation set tests safety and evidence quality rather than only happy-path wording.

## Summary

**English:** Better answers come from selecting the right evidence and measuring claims, not from adding more instructions alone.

**Hinglish:** Better answer sirf prompt se nahi; sahi evidence selection aur claim evaluation se aata hai.

## Reading and video

- Primary: [MCP server concepts](https://modelcontextprotocol.io/docs/2026-07-28/learn/server-concepts) and [resources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources).
- FDE context: [OpenAI FDE role](https://openai.com/careers/forward-deployed-engineer-(fde)-sf-san-francisco/) — connect evaluation to customer outcomes.
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Adding Prompt and Resource Features” and “Conclusion”; focus on what must be evaluated.

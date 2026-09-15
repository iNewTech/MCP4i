# Lesson 6 — Libraries, Objects, Files, and References

[Learning index](README.md) · [Roadmap](00-roadmap.md) · [Phase 1 catalogue](../project/phase-01-readonly-tools.md)

**Project milestone:** M4 begins with focused metadata tools whose coverage and naming rules are explicit.

## The inspection problem

IBM i support language is compact but ambiguous. “Find ORDERS” may mean a library object, SQL table, source member, program reference, or a file relationship. A dependable server makes the intended question explicit before reading.

## 1. Keep concepts separate

- A **library list** is ordered job context.
- A **library catalogue** is a set of visible libraries.
- An **object** has a qualified identity and object type.
- A **file** can describe database structure and members; it is not automatically a source file.
- **Program references** are recorded build/update metadata, not a complete runtime dependency graph.
- **Database relations** describe database-level relationships, not every program that uses a file.

This distinction prevents a fluent answer from collapsing several IBM i concepts into one.

## 2. Naming and qualification

Define whether each input uses IBM i object notation, SQL naming, or both. Do not silently convert `LIB/OBJ` to `LIB.OBJ` when the conversion could change meaning. Require an object type where names can collide. Normalize case only according to a documented backend rule and preserve the observed spelling when useful.

For patterns, define wildcard syntax, maximum breadth, ordering, and whether hidden/system objects are included. A default whole-system scan is a workload risk.

## 3. Metadata quality

Every result should state what was observed and what is unavailable. For example, an object-information tool may provide owner and size but not every authority detail. A program-reference result should include its source and retrieval date and say that dynamic references may be absent.

IBM's [DSPPGMREF documentation](https://www.ibm.com/docs/en/i/7.5.0?topic=d-display-program-references) explains that references are stored when programs or packages are created or updated and may not reflect later movement or dynamic behavior.

## Paper walkthrough

Question: “Which programs depend on `APPLIB/ORDERS`?”

1. Clarify whether the user wants recorded program references, database relationships, or runtime behavior.
2. If they want recorded reverse references, use the later `get_file_references` contract.
3. Return each recorded program, source metadata, and coverage limitations.
4. Explain that a dynamic call or stale build metadata may not appear.
5. Offer a separate database-relations lookup only if they also need referential structure.

The correct answer may be “the requested evidence is incomplete.” That is more useful than a falsely complete dependency graph.

## Exercise

For one fictional library, design example inputs and outputs for `list_libraries`, `list_objects`, `get_object_info`, `get_file_info`, `get_program_references`, and `get_database_relations`. Include an ambiguous name, an unauthorized library, an empty result, and a stale-reference warning.

Changed constraint: the library contains 500,000 objects and the user asks for all metadata. Explain why you require filters, paging, and a result limit, and what an asynchronous future design would need to preserve.

## Homework and gate

- Build a terminology map for library, object, file, member, program, and relationship.
- Write one acceptance check that catches a mistaken library list.
- Write one check that catches a program-reference result presented as runtime truth.
- Identify which Phase 1 capabilities must remain unsupported if the target release lacks a documented read backend.

Gate: the learner can classify the question before selecting a tool and can state the limits of each metadata source.

## Summary

**English:** Precise IBM i vocabulary is part of tool safety; metadata is evidence with coverage limits.

**Hinglish:** IBM i mein exact terminology tool safety ka part hai; metadata evidence hai, complete truth nahi.

## Reading and video

- Primary: [DSPPGMREF](https://www.ibm.com/docs/en/i/7.5.0?topic=d-display-program-references), [IBM i Services](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm).
- Video: [DeepLearning.AI MCP course](https://www.deeplearning.ai/courses/mcp-build-rich-context-ai-apps-with-anthropic), “Connecting the MCP Chatbot to Reference Servers”; classify the external data source before choosing a tool.

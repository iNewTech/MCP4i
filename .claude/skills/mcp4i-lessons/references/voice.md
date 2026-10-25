# MCP4i prose habits

Read this before drafting a full chapter. It is the difference between a chapter that
reads like the existing ten and a chapter that reads like a generic tutorial pasted in.

## Contents

- [The governing habit: claim only what is established](#the-governing-habit)
- [Sentence-level patterns](#sentence-level-patterns)
- [Words and constructions to avoid](#words-and-constructions-to-avoid)
- [Defining terms](#defining-terms)
- [Tables](#tables)
- [Fictional data](#fictional-data)
- [Hinglish](#hinglish)

## The governing habit

Every chapter repeatedly draws the line between what a result proves and what it does not.
This is the curriculum's whole thesis, so it shows up as a sentence pattern:

- "That observation does not establish that the job is healthy, making progress, or
  certain to complete. Those are different questions requiring different evidence."
- "An empty list is a valid result only when the lookup completed successfully. Do not
  turn an error into an empty success."
- "A small response does not guarantee a small database workload."
- "Recorded references may not describe every runtime dependency."

When you finish a section, ask what a reader could now wrongly conclude, and write the
sentence that closes it off. If you cannot find one, the section is probably too shallow.

The same habit applies to the repository itself. Write "has not been compiled or tested
on a real IBM i partition," not "ready to deploy." Write "these are design assumptions
until measured," not "this handles 20 concurrent users."

## Sentence-level patterns

**Lead with the difficulty, then resolve it.**

> SQL is a language, not a single read operation. A statement that starts with `SELECT`
> can invoke views, routines, nested expressions, or data-change constructs.

**Assign responsibility to software, never to the model.** The model *proposes*; the
application *checks and executes*; the server *authorizes*. "Writing a command in a chat
message does not itself execute it."

**Name the FDE framing where it fits.** Several chapters connect a technical decision to
the customer-delivery job: "For an FDE, this is the point where a customer request becomes
a bounded deliverable." Use it when the decision is about scope or defensibility, not as
decoration.

**Use direct address for instructions, third person for description.** "Reject writes,
DDL, authority changes, calls." / "The server verifies the configured target."

**Second-person plural for the project.** "Our first phase answers inspection questions."

## Words and constructions to avoid

| Avoid | Why | Instead |
| --- | --- | --- |
| "simply", "just", "easy" | The curriculum's point is that these things are not simple | State the actual step count |
| "powerful", "seamless", "robust" | Unmeasured praise | Name the measured property |
| "production-ready", "guaranteed" | Claims the repository cannot support | "verified on a development partition", "bounded by a configured deadline" |
| "the AI decides" | Misassigns execution authority | "the model proposes; the server authorizes" |
| Exclamation marks, second-person cheerleading | Off-register for this curriculum | Plain declarative sentences |
| Emoji | Not used anywhere in `docs/` | — |
| "etc.", "and so on" | Hides the boundary that the lesson is teaching | Finish the list or say why it is open-ended |

Heavy ALL-CAPS imperatives (MUST, NEVER) do not appear in the lessons. The chapters
persuade by explaining consequences, because a learner who understands why a limit exists
can defend it under a changed constraint.

## Defining terms

Bold the term, define it inline, move on:

> A **large language model (LLM)** generates language using patterns learned during
> training and the information supplied in its current **context**: the material available
> while producing an answer.

Define AI and protocol vocabulary: context, tool, resource, prompt, host, client, server,
schema, grounding, evaluation. Do not define IBM i vocabulary: library list, `*LIBL`,
qualified job identifier, source member, subsystem, job queue, `DSPPGMREF`. Readers came
in knowing those, and defining them signals the chapter was written for someone else.

## Tables

Tables carry structured comparison, not prose that was chopped up. The working shapes:

- Gap / IBM i example / what the application needs
- Aspect / prompt-and-response / tool-enabled
- Field / decision (a worked tool contract)
- Error class / example / user-facing meaning
- User question / planned capability / important limit
- Topics to revisit / primary reading / video focus

Keep cells to a clause or a short sentence. Three or four columns maximum.

## Fictional data

State it once, near the top, when a chapter leans on examples: "All identifiers and
observations in this lesson are fictional. These are paper exercises, not results from
your system."

House identifiers, reused so examples accumulate meaning across chapters:

| Thing | Value |
| --- | --- |
| System / partition | `DEV` |
| Application library | `APPLIB` |
| Objects | `APPLIB/ORDERS` (`*FILE`), `APPLIB/ORDENT` (`*PGM`) |
| Object pattern | `ORD*` |
| Job | `123456/DEMOUSER/NIGHTLY` |
| Customer key | `C42` |
| Timestamp | `2026-09-15T09:30:00Z` (ISO-8601, UTC) |
| Tools | `get_system_info`, `get_library_list`, `list_libraries`, `list_objects`, `get_object_info`, `get_program_references`, `get_database_relations`, `list_members`, `read_source`, `get_job_status`, `run_sql` |

Check `project/phase-01-readonly-tools.md` before inventing a tool name; the catalogue is
the authority and a drifted name breaks the cross-references.

## Hinglish

Roman-script Hindi carrying English technical terms. Not a word-for-word translation of
the English line — the same idea, said the way a colleague would say it out loud.

Keep in English: tool contract, evidence, limits, failures, parsing, authority, workload,
read-only, snapshot, redaction, protocol, request, response, target, timestamp.

Carry in Hindi: the verbs and connective grammar — `karta hai`, `banata hai`, `chahiye`,
`zaroori hai`, `alag cheezein hain`, `sirf ... nahi`, `ke saath`, `mein`, `aur`, `phir`.

Worked pairs from the existing chapters:

> **English:** Explaining a system is different from observing its current state.
>
> **Hinglish:** System ka concept samajhna aur uski current state dekhna alag cheezein
> hain; current answer ke liye fresh evidence chahiye.

> **English:** A tool contract turns a broad request into testable behavior with clear
> evidence and limits.
>
> **Hinglish:** Tool contract broad request ko testable behavior mein badalta hai, jisme
> evidence, limits, aur failures clear hote hain.

> **English:** SELECT-only is a policy and enforcement problem, not a keyword filter.
>
> **Hinglish:** SELECT-only sirf keyword check nahi; complete parsing, authority,
> dependencies, aur workload limits ka problem hai.

Notice that the Hinglish line often carries slightly more detail than the English one —
it is where the chapter's caveats get restated plainly. That is intentional; keep it.
No Devanagari, no transliteration of the English technical terms.

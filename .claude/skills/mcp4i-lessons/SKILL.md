---
name: mcp4i-lessons
description: Write, revise, and audit chapters of the MCP4i curriculum — the IBM i MCP learning bootcamp in docs/. Use this skill whenever the user asks for a new lesson or chapter (Lesson 11 and beyond), wants an existing docs/lesson-NN-*.md edited, expanded, split, or retitled, asks to add homework, a paper walkthrough, a milestone gate, or a Hinglish summary to the curriculum, wants the roadmap and learning-index tables brought back in sync after a lesson changes, or asks whether the lessons are still consistent with each other. Trigger even when the request is as short as "add a chapter on RAG" or "fix lesson 6" and says nothing about conventions, because the conventions that make a chapter fit — milestone gates, the fictional-data rule, paired English/Hinglish summaries, and three separate registration points — are invisible from the prompt alone and are the main thing that goes wrong without this skill.
---

# Writing MCP4i lessons

## What this curriculum is actually teaching

MCP4i teaches IBM i developers to build an MCP server that answers questions about a
real partition using verified, read-only evidence. The protocol content is the surface.
The real subject is **epistemic discipline**: an answer names its source, states when it
was observed, and admits what it does not cover. A fluent sentence is not a result.

That subject constrains how the lessons themselves are written. A chapter that promises
more than the repository can demonstrate teaches the opposite of its own content. This is
why `docs/README.md` says "No homework has been graded in this repository" and why the
repo README says the RPGLE server "has not been compiled or tested on a real IBM i
partition." Hold that line. When you are unsure whether something works, write what is
actually known, the same way the lesson asks the learner to.

The second audience constraint: readers know IBM i (libraries, objects, jobs, members)
and are new to AI vocabulary. Define every AI term on first use in the chapter where it
appears; never define `*LIBL`, a job queue, or a source member.

## Read these before writing a word

1. `docs/00-roadmap.md` — chapter sequence, the M0–M5 milestone gates, and the
   "Current position" paragraph. A new chapter must say which milestone it serves.
2. `docs/README.md` — the learning index table and "How to study a lesson".
3. The two neighbouring lessons (`lesson-NN-1`, `lesson-NN+1`). Match their density,
   heading depth, and whether they carry per-section summaries. Neighbours are a better
   style guide than any rule in this file.
4. `project/phase-01-readonly-tools.md` — the tool catalogue, the SQL policy, and the
   "Explicitly outside Phase 1" list. Never invent a tool name that contradicts it.

If the topic touches the RPGLE server, also read `rpgle-mcp-server/README.md` so the
chapter does not claim a verification that has not happened.

## The shape of a lesson

`assets/lesson-template.md` holds the skeleton with annotations. The order below is what
every existing chapter follows; deviating breaks the learner's habit of skimming.

```
# Lesson N — Title Case Topic          H1, em dash, matches the roadmap row
[Learning index](README.md) · …        nav line, mirror the neighbours' variant
**Project milestone:** …               (or **Project connection:** for conceptual chapters)
**Learning objectives:** …             optional; used by the heavier chapters
## Opening question / Recall before reading / Why <topic> is difficult
## 1. First concept
## 2. Second concept                   two to five numbered sections
## Paper walkthrough                   fictional trace, numbered steps
## Exercise                            optional, when the design work needs its own space
## Homework and gate                   bullets, then a one-line "Gate:" sentence
## Summary                             **English:** / **Hinglish:** pair
## Reading and video                   primary doc, IBM context, video section
```

Length runs 65–110 lines for a focused chapter and up to ~280 for a foundational one.
Do not pad a short chapter to look substantial.

**Opening.** Start with the difficulty, not with a definition. Lesson 1 opens with an
operator's question; Lesson 7 opens with "SQL is a language, not a single read operation."
Chapters after the first often open with `## Recall before reading` — three or four
questions from the previous chapter, because spaced recall is the curriculum's method.

**Numbered sections.** One idea each, led by prose rather than a bullet list. Tables carry
comparisons (gap/example/need, error class/example/meaning, field/decision). A Mermaid
`flowchart LR` is welcome where a boundary is the point; do not draw one per section.

**Paper walkthrough.** Every chapter traces a fictional request end to end in numbered
steps, then names what the result does *not* establish. Include the rejected or denied
path too — Lesson 3 rejects `library=QSYS`, Lesson 7 rejects a multi-statement query.
Fictional identifiers follow house style: library `APPLIB`, system `DEV`, job
`123456/DEMOUSER/NIGHTLY`, customer `C42`, ISO-8601 UTC timestamps.

**Homework and gate.** Four to six items the learner writes rather than codes, at least
one of which is a *changed constraint* ("20 users submit reports simultaneously",
"program-reference metadata is unavailable on this partition") — re-defending a design
under a new constraint is how the roadmap tests understanding. Close with a single
`Gate:` sentence naming the evidence needed before the next chapter. Foundational
chapters may use a `### Review checks` checkbox list and a `**Delayed recall:**` line.

**Reading and video.** Primary specification link, an IBM documentation link, and a
DeepLearning.AI course section with a note on what to focus on. State access caveats
(sign-in, older protocol version) when they apply. Use the protocol version already used
across `docs/` rather than a newer one you assume exists.

## The paired summaries

Every chapter ends with a `## Summary` containing exactly this pair:

```
**English:** One sentence naming the transferable idea.

**Hinglish:** Wahi idea, Roman script Hindi-English mix.
```

The Hinglish line is not a translation exercise — it is how the bootcamp's readers
actually talk shop. Keep technical terms in English (`tool contract`, `evidence`,
`parsing`, `authority`, `read-only`) and carry the grammar in Hindi: "Tool contract broad
request ko testable behavior mein badalta hai, jisme evidence, limits, aur failures clear
hote hain." Roman script only, no Devanagari. It should sound like a colleague explaining
over chai, not like machine output.

Long conceptual chapters (Lessons 1 and 2, roughly 150+ lines) also close each numbered
section with the same pair, so a reader can check their mental model before the next idea
lands. Shorter procedural chapters carry the pair only in `## Summary`. Match whichever
your neighbours do. `references/voice.md` has more Hinglish examples and the phrasing
habits that separate this curriculum's prose from generic tutorial writing — read it
before drafting a full chapter.

## Register the chapter in three places

A lesson file alone is invisible. After writing, update:

1. `docs/00-roadmap.md` — a row in the chapter-sequence table (`Chapter | Learn | Project
   contribution`), plus the milestone table and "Current position" paragraph if the
   chapter introduces or changes a gate.
2. `docs/README.md` — a row in the available-chapters table (`Read in order | Main
   question | What you produce`), and the "Your next study session" pointer if the new
   chapter becomes the next thing to study.
3. `README.md` at the repo root — only the "Current stage" line, and only if the chapter
   count or project status genuinely changed.

Also fix the neighbours' nav lines if the new chapter sits between two existing ones.
Run `python3 .claude/skills/mcp4i-lessons/scripts/check_lessons.py` afterwards; it catches
the registration and link mistakes that are easy to miss by eye.

## Revising an existing lesson

Read the whole file first and make the smallest edit that does the job. These chapters are
cross-referenced and the milestone framing is load-bearing, so preserve the H1, the nav
line, the milestone line, and the gate sentence unless the request is specifically about
them. If a revision changes what the chapter produces, the roadmap and index rows describe
it and must change too. If a revision moves content across chapters, check that the
"Explicitly outside Phase 1" boundary still holds in both.

## Auditing

`scripts/check_lessons.py` validates the mechanical conventions across `docs/`: filename
and H1 format, the nav line, the milestone line, the presence of a paper walkthrough,
homework, gate, and the English/Hinglish pair, relative links that resolve, and whether
each chapter appears in both tables.

```bash
python3 .claude/skills/mcp4i-lessons/scripts/check_lessons.py          # all lessons
python3 .claude/skills/mcp4i-lessons/scripts/check_lessons.py docs/lesson-06-inspection-tools.md
```

The script cannot judge voice, accuracy, or whether a claim overreaches. When the user
asks for an audit, run it, then read the chapters yourself for the things it misses:
overclaiming, undefined AI jargon, missing "what this does not establish" framing, tool
names that drifted from the Phase 1 catalogue, and paper walkthroughs that show only the
happy path.

## Before handing it back

- Every factual claim about the repository matches the repository's actual state.
- Fictional data is labelled as fictional.
- Nothing in the chapter authorises a write, a command, or a program call.
- Every AI term new to this chapter is defined; no IBM i term is.
- The checker passes, or you can explain each remaining warning.

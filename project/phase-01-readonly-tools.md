# Phase 1 — Read-only IBM i Tools

[Repository home](../README.md) · [Learning roadmap](../docs/00-roadmap.md) · [Lesson 2 design exercise](../docs/lesson-02-mcp-architecture.md)

## Purpose and status

Let an authorized user ask questions about IBM i and receive bounded, traceable observations. Phase 1 covers system identity, library context, object and file metadata, recorded dependencies, job inspection, approved SQL reads, source reading, and logs.

**This is a design roadmap.** Source for one `get_system_info` tool now exists in the [RPGLE MCP server](../rpgle-mcp-server/README.md), but it has not been compiled or verified against a target partition. The remaining tools are designs. A tool becomes available only after its backend, permissions, and limits are verified.

Use descriptive snake_case names. Expose the user's information need, such as `get_program_references`, instead of an arbitrary command runner. References to familiar IBM i commands describe the information users want; they are not instructions to execute those commands behind a tool.

## First 10 read-only tools

These are the starter candidates for Lesson 2 homework. Design all ten; implement and validate them incrementally in later lessons. Do not treat their numbering as a guarantee that all ten backends are available.

All tools use a target fixed by trusted server configuration. Library, object, and job arguments must remain within the caller's authorized scope. Result fields below are proposed minimum contracts, subject to explicit support checks.

| # | Tool | User need and proposed inputs | Proposed result and important boundary |
| --- | --- | --- | --- |
| 1 | `get_system_info` | Identify the connected environment; no target-switching argument | Observed system/partition identity, release, selected supported system attributes, timestamp; distinguish configured labels from observed values |
| 2 | `get_library_list` | Inspect the library list for the adapter's current IBM i connection job | Ordered libraries, entry categories where available, and connection-job context; not the user's separate interactive job |
| 3 | `list_libraries` | Find accessible libraries using an optional name pattern and bounded page size | Visible matching libraries and descriptions; absence means no visible match in this scope |
| 4 | `list_objects` | List objects in one explicit library; filter by allowed object type and name pattern | Qualified names, types, descriptions, and paging information; no whole-system wildcard scan by default |
| 5 | `get_object_info` | Inspect one object using library, object name, and object type | Qualified identity, owner, size and relevant timestamps where supported; authority metadata only when permitted |
| 6 | `get_program_references` | Inspect recorded references for one qualified program or supported service program | Referenced object identities, types, usage information where available, metadata source, and completeness limitations; never execute the program |
| 7 | `get_file_info` | Describe one qualified database file | File kind, record formats/columns, supported type and key metadata, member summary; reading descriptions does not imply reading records |
| 8 | `get_database_relations` | Inspect relationships for a qualified database file/table | Supported physical/logical dependencies and/or referential-constraint relationships, each labeled by kind and direction; not a list of all programs using the file |
| 9 | `list_active_jobs` | Inspect visible active jobs using narrow filters such as subsystem, user, or name | Qualified job IDs, observed states, selected permitted attributes, and snapshot time; bounded result set |
| 10 | `get_job_status` | Inspect one job by complete `number/user/name` identifier | Observed state, permitted diagnostic attributes, and timestamp; distinguish not found/visible, denied, ended if verifiable, and unavailable |

### Identity and naming rules

- `get_library_list` is a connection/job-context question. `list_libraries` is a catalogue search. Never silently substitute one for the other.
- Use explicit qualified targets for object and file inspection. Define handling of IBM i system names versus SQL schema/table names before implementation; do not assume their naming rules are interchangeable.
- Resolve ambiguous job names before reading status. A job name alone is insufficient for the single-job contract.
- Define normalization explicitly. For example, preserve the raw observed job state if returning a simplified label, and document the mapping.
- If using pooled IBM i connections later, report the actual backend job context used for each read. Do not imply that it shares the user's interactive library list.

## Remaining Phase 1 catalogue

These capabilities remain in the read-only roadmap. Add them after the initial slice and the relevant review, not all at once.

| Area | Tool | Intended scope and gate |
| --- | --- | --- |
| Programs | `list_programs` | Bounded program discovery in an approved library; may reuse the object-listing contract |
| Programs | `get_program_info` | Inspect permitted attributes for one program; no program invocation |
| Reverse references | `get_file_references` | Identify programs recorded as referencing a file, using a verified read-only metadata source; declare coverage and freshness |
| Members | `list_members` | List members and metadata within one approved database file |
| Members | `read_member` | Read a bounded set of records from an explicitly permitted member; define how the member is selected without creating aliases or objects |
| Source | `list_source_members` | Discover members in one approved source physical file |
| Source | `read_source` | Return a bounded range from one source member, preserving member identity and line/sequence information |
| Source | `search_source` | Search approved source files/members using a bounded query and result limit; no unrestricted system-wide scan |
| SQL | `run_sql` | Run one permitted SELECT query over approved data; requires the SQL gate below |
| Jobs | `get_job_log` | Read a bounded segment of a permitted job log; no reply or job-control action |
| Messages | `get_messages` | Read a bounded selection from an authorized message queue; do not remove messages or reply |
| Logs | `read_history_log` | Read a bounded time window; filter and limit sensitive output |

An IBM i source member belongs to a source physical file. Integrated File System (IFS) stream-file access would require a separate, explicit path policy; it is not implicitly included by these member tools.

## Program references and file relationships

Keep three questions separate:

1. **Program → referenced objects:** `get_program_references`.
2. **File → database relationships:** `get_database_relations`.
3. **File → programs recorded as using it:** later `get_file_references`.

Recorded program references are not a complete runtime trace. Names stored at build/update time may differ from current resolution, and dynamic references may be incomplete. Return coverage and source limitations rather than claiming a full dependency graph. IBM describes these qualifications in [DSPPGMREF](https://www.ibm.com/docs/en/i/7.5.0?topic=d-display-program-references) and [displaying objects used by programs](https://www.ibm.com/docs/en/i/7.6.0?topic=administration-displaying-objects-used-by-programs).

**Backend gate:** Some familiar display-command workflows create or replace database output files or produce spool output. IBM documents those effects for [DSPPGMREF output](https://www.ibm.com/docs/en/i/7.5.0?topic=d-display-program-references). Creating a temporary output file and deleting it afterward would still introduce writes and command execution into this phase.

Prefer an available, documented read interface. If a capability cannot be obtained within the agreed read-only boundary on the target release, leave it unsupported and document the gap. Do not invent an equivalent SQL service or silently add a command fallback. An existing, separately maintained metadata dataset may be considered later only if its access, coverage, and age are explicit; this server must not refresh it by executing write operations.

## Read-only SQL policy

`run_sql` means **a restricted SELECT capability**, not arbitrary SQL with a promise to avoid writes. Enable it only after the following design is implemented and checked in a later chapter.

### Allowed shape

- Exactly one statement in a deliberately narrow, read-only SELECT subset.
- Only approved schemas, tables/views, columns, and reviewed read-only functions.
- Bound values for data parameters; explicit validation and allowlisting for identifiers.
- Server-enforced row, response-size, execution-time, and concurrency limits.

A common table expression introduced with `WITH` may be supported only when the whole statement, including nested expressions, passes the same read-only checks. Unsupported syntax must be rejected until reviewed.

### Rejected operations

- INSERT, UPDATE, DELETE, MERGE, and data changes nested inside a query.
- CREATE, ALTER, DROP, TRUNCATE, GRANT, REVOKE, and other schema or authority changes.
- CALL, command-execution wrappers, procedural blocks, multiple statements, and unapproved routines or external actions.
- Export/write destinations, lock-for-update behavior, and any syntax outside the approved subset.

### Why a SELECT prefix is insufficient

Inspect the parsed structure of the **entire statement**, using tooling that understands the supported Db2 for i syntax. Keyword-prefix checks and regular-expression blocklists cannot establish this boundary. IBM documents [data-change table references](https://www.ibm.com/docs/ssw_ibm_i_75/db2/rbafztabref.htm), which make nested operations a concrete concern.

Also review reachable views and routines. A read-looking expression must not become a path to an unapproved routine or indirect operation. Database/object authority, routine privileges, and server policy must all enforce the intended scope; a “read-only” connection option or tool annotation alone is not enough.

Start with fixed, parameterized inspection queries for the focused tools. Keep the generic `run_sql` capability disabled until its stricter review passes.

### SQL gate evidence

- [ ] Approved reads produce expected bounded results on the target system.
- [ ] Direct writes, nested writes, multiple statements, prohibited routines, and unsupported syntax are rejected.
- [ ] Queries cannot read outside approved objects or expose forbidden columns through alternate paths.
- [ ] Timeouts and response limits are enforced; fetching only a few rows does not substitute for bounding database work.
- [ ] Errors, audit records, and returned data omit credentials and unnecessary sensitive values.

## Shared contracts and operating limits

These are proposed learning defaults, not measured production settings: one development target, one active request at a time, 100 rows by default, at most 1,000 rows where a tool supports paging, at most 64 KiB of returned content, and a five-second deadline. Validate feasibility and override per tool during design review; callers may request smaller limits but cannot raise server caps.

| Concern | Required behavior |
| --- | --- |
| Authority | Use a dedicated identity with only the required read access; enforce caller-specific scope before any shared connection is used |
| Target selection | Bind permitted environments in trusted configuration; do not accept an arbitrary host or credential as a model argument |
| Results | Include source/target, observed time, scope, and completeness; list reads identify returned count and any truncation or next page |
| Paging | Define ordering and continuation; changing job lists are not a transactionally consistent snapshot across pages |
| Sensitive information | Minimize fields; apply redaction before model context and before logs; do not log raw credentials, source, or SQL values by default |
| Errors | Separate invalid input, denied access, unsupported capability, missing/hidden target, and timeout where authority allows; do not return empty success for failures |
| Recovery | No automatic retry for denied or invalid requests; tightly bound transient retries and preserve uncertainty when the deadline expires |
| Audit | Record tool name, caller identity, safe target identifiers, duration, outcome, and result count outside the chat transcript |
| Content trust | Treat object descriptions, messages, and source text as evidence, not instructions that can change policy |

Here, **read-only** forbids intentional changes to target business data, objects, configuration, or job state through exposed capabilities or their backend workarounds. It does not claim that reads consume no resources or that the operating system performs no internal logging or temporary query work.

## Explicitly outside Phase 1

| Capability | Deferred names/examples | Why excluded |
| --- | --- | --- |
| Arbitrary CL | `run_cl` | Can change configuration, data, objects, or job state |
| Program execution | `run_program` | A program can have effects not visible from its name |
| Job submission | `submit_job` / SBMJOB | Creates work and changes system state |
| Job control | `cancel_job`, `hold_job`, `release_job` | Changes another job's execution |
| Data mutation | `insert_record`, `update_record`, `delete_record` | Changes business data |
| Source/object mutation | Editing, compiling, creating aliases/outfiles, deleting temporary objects | Violates this phase's operational scope |

These were discussed as possible future phases. They are not enabled through a Phase 1 “confirm” button or a hidden generic executor. Future write capabilities need a separate scope, specific authorization design, and recovery plan.

## Delivery checkpoints

1. **M1 — Design:** complete the ten contracts and traces from [Lesson 2](../docs/lesson-02-mcp-architecture.md).
2. **M2 — Mock:** later discover and call only `get_system_info` using clearly fictional data.
3. **M3 — Connect:** later verify that one read on an authorized development system matches a trusted observation.
4. **M4 — Expand:** add supported focused tools; review guarded SQL, source, and logs before enabling them.
5. **M5 — Validate:** demonstrate representative questions and failures, access boundaries, bounded execution, and useful evidence in answers.

For each backend, record the IBM i release, required PTF/service level, authority, and any unavailable fields. IBM's [Services overview](https://www.ibm.com/docs/ssw_ibm_i_75/rzajq/rzajqservicessys.htm) points to release and enhancement information. Neither a tool's name nor this roadmap proves compatibility with your partition.

## Summary

**English:** Start with focused inspection contracts. Add broader reads only when their authority, dependencies, workload, and evidence quality are controlled.

**Hinglish:** Pehle focused inspection tools design karo. Broader reads tab add karo jab permissions, dependencies, workload, aur evidence quality ki boundaries clear hon.

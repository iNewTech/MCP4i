# MCPLIB: IBM i MCP application source

This directory is the **multi-server application** track. It keeps IBM i objects in one application library, `MCPLIB`, while each named MCP server gets its own configuration and tool tables. The existing [single-server tutorial](../README.md) is still useful for learning the protocol.

This milestone supplies source, DDS administration screens, two sample read-only handlers, a wrapper generator for existing IBM i programs, and two equivalent application compile paths. It does **not** provision an IBM HTTP Server instance yet, so it cannot serve live MCP traffic until that infrastructure step is complete. No live IBM i compile has been performed from this workstation.

## Source map

| Source | IBM i objects | Purpose |
| --- | --- | --- |
| [sql/SCHEMA.sql](sql/SCHEMA.sql), [sql/UPGRADE_GENERATION.sql](sql/UPGRADE_GENERATION.sql) | `MCPCAT`, `MCPCFGT`, `MCPTOOLT` `*FILE` | One-time catalog/templates and an additive upgrade for existing tool tables. `CRTMCPSRV` allocates per-server `Snnnnnnn` and `Tnnnnnnn` files. |
| [dds/MCPSRVD.dspf](dds/MCPSRVD.dspf), [dds/MCPTOOLD.dspf](dds/MCPTOOLD.dspf) | `MCPSRVD`, `MCPTOOLD` `*DSPF` | 5250 screens for server and tool details. DDS is copied to `MCPLIB/QDDSSRC` before compilation. |
| [rpg/MCPSRVAD.sqlrpgle](rpg/MCPSRVAD.sqlrpgle), [rpg/MCPTOOAD.sqlrpgle](rpg/MCPTOOAD.sqlrpgle) | `MCPSRVAD`, `MCPTOOAD` `*PGM` | Validate the screen input and save server/tool rows. |
| [rpg/MCPSRVOP.sqlrpgle](rpg/MCPSRVOP.sqlrpgle) | `MCPSRVOP` `*PGM` | Start/end wrapper; rejects an unprovisioned HTTP instance. |
| [rpg/MCPHTTP.sqlrpgle](rpg/MCPHTTP.sqlrpgle), [rpg/MCPREG.sqlrpgle](rpg/MCPREG.sqlrpgle), [rpg/MCPJSON.sqlrpgle](rpg/MCPJSON.sqlrpgle) | `MCPHTTP` `*PGM` and modules | CGI request handling, per-server tool lookup, and JSON response creation. |
| [rpg/MCSYSINF.sqlrpgle](rpg/MCSYSINF.sqlrpgle), [rpg/MCLIBLST.sqlrpgle](rpg/MCLIBLST.sqlrpgle) | `MCSYSINF`, `MCLIBLST` `*PGM` | Independent sample handlers for `get_system_info` and `get_library_list`. |
| [copy/MCPABI.rpgleinc](copy/MCPABI.rpgleinc) | Source include | Documents the fixed four-parameter handler interface. |
| [tools/](tools/) | Workstation/IFS source generator | Produces a standalone RPG MCP handler from reviewed program metadata or an editable template. Generated source is reviewed and compiled separately. |
| [examples/customer-tool.json](examples/customer-tool.json) | Example manifest | Demonstrates a confirmed by-reference native program signature; replace it with the real target contract before generating a callable wrapper. |
| [cmd/](cmd/) | Seven `*CMD` objects | `CRTMCPSRV`, `CHGMCPSRV`, `STRMCPSRV`, `ENDMCPSRV`, `ADDMCPTOOL`, `EDTMCPTOOL`, `RMVMCPTOOL`. |
| [Makefile](Makefile), [cl/BLDMCPLIB.clle](cl/BLDMCPLIB.clle) | Build entry points | Compile from IFS using PASE GNU make or an ILE CL driver. |

## Build on IBM i from the IFS

Put this entire `mcplib` directory in the IBM i IFS, for example `/home/builduser/mcplib`. Use an account that can create objects in `MCPLIB` and compile RPG, CL, DDS, and SQL. The build binds `MCPHTTP` to `QHTTPSVR/QZHBCGI`, so that IBM HTTP Server service program must be installed before compiling, even though the HTTP instance is provisioned later. In a PASE shell:

```sh
cd /home/builduser/mcplib
make schema  # first installation only; creates the three data files
make app     # compiles DDS, modules, programs, and seven commands
```

`make app` checks that the schema exists and never runs `RUNSQLSTM`, drops a table, or replaces rows. Run it again after editing application source. `make schema` is intentionally explicit and will fail if its tables already exist; it is not an upgrade or migration command. The build compiles the two DDS stream files through `QDDSSRC`, because `CRTDSPF` uses source members rather than `SRCSTMF`. The SQL RPG and command compilers read their source directly from IFS stream files. `make app` intentionally does not rebuild customer tool handlers.

If MCPLIB was installed **before** the `GENMODE`, `TGTLIB`, and `TGTPGM` columns were added, stop each HTTP instance serving `MCPHTTP` and let in-flight requests finish before changing the registry tables. Then run the additive upgrade before rebuilding the application:

```sh
cd /home/builduser/mcplib
make upgrade-generation
make app
```

The upgrade script checks the empty `MCPTOOLT` template and each existing server's tool table, adds missing columns, and leaves existing rows as mode `M`. It is designed to be rerunnable; it does not call the one-time `SCHEMA.sql`. Inspect the RUNSQLSTM job log/listing if any `ALTER TABLE` fails. After `make app` succeeds, restart the HTTP instance(s) and verify a known tool before restoring client traffic. A fresh installation from this revision needs only `make schema` followed by `make app`.

To launch the same IFS build from your workstation, transfer the source directory and use SSH:

```sh
scp -r rpgle-mcp-server/mcplib USER@IBMI:/home/USER/
ssh USER@IBMI 'cd /home/USER/mcplib && make schema && make app'
```

Replace `USER`, `IBMI`, and the IFS path with your own values. On subsequent builds, run only `make app`. On a workstation with Python 3, `make check` runs the source contract tests, and `make -n app` previews the IBM i commands without executing them. Those checks cannot establish that RPG, DDS, or CL compiles on your partition.

## Equivalent ILE CL build

The [CL driver](cl/BLDMCPLIB.clle) accepts `SCHEMA` or `APP` plus the absolute IFS directory. Bootstrap it on IBM i after the source directory is in the IFS. Run the first command only if `MCPLIB` does not already exist:

```cl
CRTLIB LIB(MCPLIB) TEXT('MCP for i application')
CRTBNDCL PGM(MCPLIB/BLDMCPLIB) SRCSTMF('/home/builduser/mcplib/cl/BLDMCPLIB.clle') DFTACTGRP(*NO) ACTGRP(*CALLER) REPLACE(*YES)
CALL PGM(MCPLIB/BLDMCPLIB) PARM(('SCHEMA' (*CHAR 10)) ('/home/builduser/mcplib' (*CHAR 256)))
CALL PGM(MCPLIB/BLDMCPLIB) PARM(('APP' (*CHAR 10)) ('/home/builduser/mcplib' (*CHAR 256)))
```

Use the `SCHEMA` call only for the first install; use `APP` for later code rebuilds. Recompile `BLDMCPLIB` with the `CRTBNDCL` command above when its own source changes. The explicit parameter lengths matter: a bare character literal on IBM i `CALL` normally occupies at least 32 bytes, while this program declares a 10-byte mode and a 256-byte path. The `APP` branch follows the same application object order and preserves registry data, just like the Makefile.

For an existing installation, stop MCP HTTP traffic as described above. After recompiling `BLDMCPLIB`, invoke its additive `UPGRADE` mode once before `APP`, then restart and verify the HTTP instance(s):

```cl
CALL PGM(MCPLIB/BLDMCPLIB) PARM(('UPGRADE' (*CHAR 10)) ('/home/builduser/mcplib' (*CHAR 256)))
CALL PGM(MCPLIB/BLDMCPLIB) PARM(('APP' (*CHAR 10)) ('/home/builduser/mcplib' (*CHAR 256)))
```

## First administration path

Use a 5250 session that supports 27×132 display size (`*DS4`). After the build, put `MCPLIB` on the interactive job's library list and run `CRTMCPSRV SERVER(DEMO)` to enter a display name, port, capability, and settings on the server screen. The server screen accepts up to 128 characters for the saved library list. `ADDMCPTOOL SERVER(DEMO)` opens the tool screen; its description field accepts up to 128 characters. `TOOL('get_system_info')` is optional and prefills the name. New servers and tools begin in draft. `EDTMCPTOOL SERVER(DEMO) TOOL('get_system_info')` requires the existing name and can publish a reviewed READ handler. `RMVMCPTOOL` also requires the existing name and retires a handler without deleting its row.

For the two supplied sample handlers, choose mode `M` (manual existing handler), enter `MCPLIB/MCSYSINF` or `MCPLIB/MCLIBLST` in the **handler** fields, and leave the three argument names blank; the examples reject nonempty arguments. Mode `M` requires that the handler `*PGM` already exist. The **target** fields are for a different, native IBM i program that a generated wrapper will call; do not put a program with its own parameter list into the handler fields. The runtime always calls a handler using the [four-parameter MCP ABI](copy/MCPABI.rpgleinc), never using the native program's arbitrary signature.

## Adapt an existing IBM i program

The tool screen offers three modes:

| Mode | Use | What the screen saves |
| --- | --- | --- |
| `M` | You wrote an MCP ABI handler yourself. | Its existing library and program. |
| `G` | Generate a wrapper from an exact, reviewed program signature. | Native target and future wrapper names; tool stays draft. |
| `T` | Start from an editable wrapper template. | Native target and future wrapper names; tool stays draft. |

`G` and `T` do not compile or run a native target when you press Enter. They record a draft tool; source generation, review, compilation, and publication are separate steps. The target and handler are two different `*PGM` objects. For example, a future MCP handler `MCPLIB/CUSTLOOK` might call an existing application program `APPLIB/GETCUST`. `G` supports `char`, `int`, and `packed` by-reference parameters, with at most three public input or input/output parameters and 32 native parameters total. The current 5250 screen has three argument slots. Choose `T` and edit the wrapper for a more complex signature. These modes support synchronous calls in this milestone; a submitted batch job needs its own request/result workflow.

First verify the target program's parameter order, by-reference types, lengths, decimal positions, and input/output meaning from its source or a maintained interface contract. If an RPG program was compiled with PCML in its bound module, IBM i can retrieve that interface with [QBNRPII](https://www.ibm.com/docs/en/i/7.5.0?topic=q-retrieve-program-interface-information-qbnrpii); [PGMINFO(*PCML)](https://www.ibm.com/docs/en/i/7.5.0?topic=command-description-crtbndrpg) controls PCML generation for RPG. This version does **not** discover a complete callable signature from an arbitrary `*PGM` or import PCML automatically. `signatureConfirmed` in the manifest is your explicit statement that you have checked it. A mistaken native signature can produce an incorrect program call even if the JSON schema is valid.

For a hypothetical `APPLIB/GETCUST` with `CUSTNO CHAR(10)` input and `CUSTNAME CHAR(50)` output, copy [examples/customer-tool.json](examples/customer-tool.json) and replace its example interface with your actual program contract. Its contents are:

```json
{
  "mode": "G",
  "handler": {"library": "MCPLIB", "program": "CUSTLOOK"},
  "target": {"library": "APPLIB", "program": "GETCUST"},
  "signatureConfirmed": true,
  "callingConvention": "by_reference",
  "parameters": [
    {"name": "CUSTNO", "jsonName": "customer_no", "type": "char", "length": 10, "direction": "in", "required": true},
    {"name": "CUSTNAME", "jsonName": "customer_name", "type": "char", "length": 50, "direction": "out"}
  ]
}
```

The manifest is a **native call contract**, not a claim that the target is safe to expose. In the `ADDMCPTOOL` screen, enter public tool name, description, mode `G`, target `APPLIB/GETCUST`, handler `MCPLIB/CUSTLOOK`, READ capability, draft state, and argument 1 as `customer_no`, type `string`, required `Y`. Leave argument slots 2 and 3 blank. The JSON name and type on the screen must match the generator's schema. Output-only parameters are returned in the tool result and do not consume screen argument slots. Generate the source and a schema for comparison:

```sh
cd rpgle-mcp-server/mcplib
mkdir -p generated
python3 tools/generate_handler.py --manifest customer-tool.json \
  --output generated/CUSTLOOK.sqlrpgle \
  --schema-out generated/CUSTLOOK.schema.json
```

The source filename must match `handler.program`. By default the generator writes a `.schema.json` sidecar next to the RPG source; `--schema-out` chooses another path. It will not overwrite an existing generated file unless you deliberately pass `--force`.

A generated `G` handler rejects unknown top-level JSON fields and an explicit JSON `null`. If an optional input is absent, the native program receives initialized blank or zero storage for that parameter. Db2 `JSON_VALUE` can convert supported scalar values to the declared SQL type, so this wrapper does not enforce exact JSON primitive types at runtime; test the inputs your client may send.

Inspect the generated RPG, compare `CUSTLOOK.schema.json` with the 5250 tool arguments, and review the native call and program authority. Copy the generated source to the IBM i IFS with the rest of `mcplib`, then compile only this wrapper on IBM i:

```sh
cd /home/builduser/mcplib
make handler HANDLER_SRC=/home/builduser/mcplib/generated/CUSTLOOK.sqlrpgle \
  HANDLER_PGM=CUSTLOOK HANDLER_LIB=MCPLIB
```

The handler library must already exist and the `HANDLER_LIB/HANDLER_PGM` pair must match the draft tool's handler fields.

The equivalent direct CL commands are:

```cl
CRTSQLRPGI OBJ(MCPLIB/CUSTLOOK) SRCSTMF('/home/builduser/mcplib/generated/CUSTLOOK.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('/home/builduser/mcplib/copy') COMPILEOPT('INCDIR(''/home/builduser/mcplib/copy'')') REPLACE(*YES)
CRTPGM PGM(MCPLIB/CUSTLOOK) MODULE(MCPLIB/CUSTLOOK) REPLACE(*YES)
```

For mode `T`, use the same manifest layout with `"mode": "T"` and omit `signatureConfirmed` and `parameters` if you do not yet know the call. The generator emits an MCP ABI handler with a commented example of the target call. It deliberately returns an error until you edit and compile it, so an unimplemented template does not appear to succeed. For `M`, you supply your own program with the fixed MCP ABI and skip generation.

After a wrapper compiles, test it with controlled inputs and verify its results and authority in the CGI job context. Reopen the draft with `EDTMCPTOOL`, confirm the handler object and matching arguments, then set state `A` only if the tool is READ (`R`) and the call is safe to expose. The tool becomes visible through `tools/list` only after publication. If you change an active handler or its argument schema, first return the tool to draft, review it, and publish it again.

The server capability (`R`, `W`, or `D`) is stored as a policy ceiling; this version only activates `R` tools. Review the handler's IBM i authority and behavior before publication: metadata alone does not make code read-only.

The CGI advertises `get_system_info` and `get_library_list` through `tools/list` after they are published. Long tool lists use `nextCursor`; the client sends that value as `params.cursor` to read the next page. Initialization negotiates the supported `2025-03-26` or `2025-11-25` MCP version. The saved library-list and timeout fields are catalog settings for the next infrastructure milestone; this CGI does not yet apply them to handler jobs.

`STRMCPSRV` requires a separately provisioned IBM HTTP Server instance and reports that it is missing until that deployment step is done. After provisioning the instance named `DEMO` with the saved port, run `CHGMCPSRV SERVER(DEMO)` and set its state to `A` (active); only then run `STRMCPSRV SERVER(DEMO)`. The commands do not create or reconfigure the HTTP instance. Its worker invokes `MCPHTTP` as CGI for each request; no dedicated `SBMJOB`, job queue, or subsystem is needed for the CGI program itself. The future Apache configuration must convert the RPG program's EBCDIC output to UTF-8 on the network, using IBM HTTP Server's `CGIConvMode EBCDIC` and `DefaultNetCCSID 1208` settings.

## IBM references

- [Copy From Stream File (`CPYFRMSTMF`)](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcpyfrmstmf.html) explains copying DDS into a source physical file member.
- [Create SQL ILE RPG Object (`CRTSQLRPGI`)](https://www.ibm.com/docs/en/i/7.5.0?topic=c-create-sql-ile-rpg-object) documents compilation from IFS source stream files.
- [Call Program (`CALL`)](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcall.htm) documents explicit character parameter lengths.
- [CGI data conversions](https://www.ibm.com/docs/en/i/7.5.0?topic=programming-cgi-data-conversions) explains the HTTP server encoding settings for an EBCDIC CGI program.

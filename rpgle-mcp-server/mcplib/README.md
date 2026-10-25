# MCPLIB: IBM i MCP application source

This directory is the **multi-server application** track. It keeps IBM i objects in one application library, `MCPLIB`, while each named MCP server gets its own configuration and tool tables. The existing [single-server tutorial](../README.md) is still useful for learning the protocol.

This milestone supplies source, DDS administration screens, two sample read-only handlers, and two equivalent compile paths. It does **not** provision an IBM HTTP Server instance yet, so it cannot serve live MCP traffic until that infrastructure step is complete. No live IBM i compile has been performed from this workstation.

## Source map

| Source | IBM i objects | Purpose |
| --- | --- | --- |
| [sql/SCHEMA.sql](sql/SCHEMA.sql) | `MCPCAT`, `MCPCFGT`, `MCPTOOLT` `*FILE` | One-time catalog and empty table templates. `CRTMCPSRV` allocates per-server `Snnnnnnn` and `Tnnnnnnn` files. |
| [dds/MCPSRVD.dspf](dds/MCPSRVD.dspf), [dds/MCPTOOLD.dspf](dds/MCPTOOLD.dspf) | `MCPSRVD`, `MCPTOOLD` `*DSPF` | 5250 screens for server and tool details. DDS is copied to `MCPLIB/QDDSSRC` before compilation. |
| [rpg/MCPSRVAD.sqlrpgle](rpg/MCPSRVAD.sqlrpgle), [rpg/MCPTOOAD.sqlrpgle](rpg/MCPTOOAD.sqlrpgle) | `MCPSRVAD`, `MCPTOOAD` `*PGM` | Validate the screen input and save server/tool rows. |
| [rpg/MCPSRVOP.sqlrpgle](rpg/MCPSRVOP.sqlrpgle) | `MCPSRVOP` `*PGM` | Start/end wrapper; rejects an unprovisioned HTTP instance. |
| [rpg/MCPHTTP.sqlrpgle](rpg/MCPHTTP.sqlrpgle), [rpg/MCPREG.sqlrpgle](rpg/MCPREG.sqlrpgle), [rpg/MCPJSON.sqlrpgle](rpg/MCPJSON.sqlrpgle) | `MCPHTTP` `*PGM` and modules | CGI request handling, per-server tool lookup, and JSON response creation. |
| [rpg/MCSYSINF.sqlrpgle](rpg/MCSYSINF.sqlrpgle), [rpg/MCLIBLST.sqlrpgle](rpg/MCLIBLST.sqlrpgle) | `MCSYSINF`, `MCLIBLST` `*PGM` | Independent sample handlers for `get_system_info` and `get_library_list`. |
| [copy/MCPABI.rpgleinc](copy/MCPABI.rpgleinc) | Source include | Documents the fixed four-parameter handler interface. |
| [cmd/](cmd/) | Seven `*CMD` objects | `CRTMCPSRV`, `CHGMCPSRV`, `STRMCPSRV`, `ENDMCPSRV`, `ADDMCPTOOL`, `EDTMCPTOOL`, `RMVMCPTOOL`. |
| [Makefile](Makefile), [cl/BLDMCPLIB.clle](cl/BLDMCPLIB.clle) | Build entry points | Compile from IFS using PASE GNU make or an ILE CL driver. |

## Build on IBM i from the IFS

Put this entire `mcplib` directory in the IBM i IFS, for example `/home/builduser/mcplib`. Use an account that can create objects in `MCPLIB` and compile RPG, CL, DDS, and SQL. In a PASE shell:

```sh
cd /home/builduser/mcplib
make schema  # first installation only; creates the three data files
make app     # compiles DDS, modules, programs, and seven commands
```

`make app` checks that the schema exists and never runs `RUNSQLSTM`, drops a table, or replaces rows. Run it again after editing application source. `make schema` is intentionally explicit and will fail if its tables already exist; it is not an upgrade or migration command. The build compiles the two DDS stream files through `QDDSSRC`, because `CRTDSPF` uses source members rather than `SRCSTMF`. The SQL RPG and command compilers read their source directly from IFS stream files.

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

## First administration path

After the build, put `MCPLIB` on the interactive job's library list and run `CRTMCPSRV SERVER(DEMO)` to enter a display name, port, capability, and settings on the 5250 screen. This first screen accepts up to 128 characters for the saved library list and tool description. `ADDMCPTOOL SERVER(DEMO)` opens the tool screen, where you enter the public name, description, handler, and arguments. `TOOL('get_system_info')` is optional and prefills the name; enter `MCPLIB` and `MCSYSINF` as the reviewed handler library and program. Add `get_library_list` with `MCLIBLST` the same way. New servers and tools begin in draft. `EDTMCPTOOL SERVER(DEMO) TOOL('get_system_info')` requires the existing name and can publish a reviewed READ handler. `RMVMCPTOOL` also requires the existing name and retires a handler without deleting its row.

The server capability (`R`, `W`, or `D`) is stored as a policy ceiling; this version only activates `R` tools. A handler program must implement the [fixed ABI](copy/MCPABI.rpgleinc). Registering an existing program with a different signature requires a small adapter `*PGM`. Review the handler's IBM i authority and behavior before publication: metadata alone does not make code read-only. To change an active handler or its argument schema, save the tool as draft, review it, and publish it again with `EDTMCPTOOL`.

The CGI advertises `get_system_info` and `get_library_list` through `tools/list` after they are published. Long tool lists use `nextCursor`; the client sends that value as `params.cursor` to read the next page. Initialization negotiates the supported `2025-03-26` or `2025-11-25` MCP version. The saved library-list and timeout fields are catalog settings for the next infrastructure milestone; this CGI does not yet apply them to handler jobs.

`STRMCPSRV` requires a separately provisioned IBM HTTP Server instance and reports that it is missing until that deployment step is done. The eventual HTTP worker invokes `MCPHTTP` as CGI for each request; no dedicated `SBMJOB`, job queue, or subsystem is needed for the CGI program itself. The future Apache configuration must convert the RPG program's EBCDIC output to UTF-8 on the network, using IBM HTTP Server's `CGIConvMode EBCDIC` and `DefaultNetCCSID 1208` settings.

## IBM references

- [Copy From Stream File (`CPYFRMSTMF`)](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcpyfrmstmf.html) explains copying DDS into a source physical file member.
- [Create SQL ILE RPG Object (`CRTSQLRPGI`)](https://www.ibm.com/docs/en/i/7.5.0?topic=c-create-sql-ile-rpg-object) documents compilation from IFS source stream files.
- [Call Program (`CALL`)](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcall.htm) documents explicit character parameter lengths.
- [CGI data conversions](https://www.ibm.com/docs/en/i/7.5.0?topic=programming-cgi-data-conversions) explains the HTTP server encoding settings for an EBCDIC CGI program.

# MCPLIB application build from an IBM i PASE shell.
# Run once: make schema. Rebuild code without touching rows: make app.
# GNU make is used only to order IBM i CL commands; `system` runs them.

LIB := MCPLIB
SRCROOT ?= $(CURDIR)
SYSTEM ?= system -K
RPGOPT = COMPILEOPT('INCDIR(''$(SRCROOT)/copy'')')

.PHONY: help schema upgrade-catalog upgrade-generation app handler ensure-library verify-schema dds-source displays modules programs commands check
.NOTPARALLEL:

help:
	@echo 'IBM i PASE: make schema (once), then make app (repeatable)'
	@echo 'Existing installation: stop HTTP/admin traffic, make upgrade-generation, make app, then restart'
	@echo 'One generated tool: make handler HANDLER_SRC=/absolute/path/TOOL.sqlrpgle HANDLER_PGM=TOOL [HANDLER_LIB=MCPLIB]'
	@echo 'Developer workstation: make check; make -n app previews CL commands'

# A generated wrapper is a separate *PGM and is compiled only after its
# source has been reviewed. It is intentionally not a prerequisite of app:
# app must never replace customer handlers or publish draft tools.
HANDLER_LIB ?= $(LIB)
HANDLER_SRC ?=
HANDLER_PGM ?=

handler:
	@test -n '$(HANDLER_SRC)' && test -n '$(HANDLER_PGM)' || { echo 'Set HANDLER_SRC and HANDLER_PGM'; exit 2; }
	@test -f '$(HANDLER_SRC)' || { echo 'Handler source not found: $(HANDLER_SRC)'; exit 2; }
	$(SYSTEM) "CRTSQLRPGI OBJ($(HANDLER_LIB)/$(HANDLER_PGM)) SRCSTMF('$(HANDLER_SRC)') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(HANDLER_LIB)/$(HANDLER_PGM)) MODULE($(HANDLER_LIB)/$(HANDLER_PGM)) REPLACE(*YES)"

ensure-library:
	@$(SYSTEM) "CHKOBJ OBJ($(LIB)) OBJTYPE(*LIB)" >/dev/null 2>&1 || $(SYSTEM) "CRTLIB LIB($(LIB)) TEXT('MCP for i application')"

# This target is deliberately never a prerequisite of `app`. RUNSQLSTM
# creates the shared catalog/templates and must run only during installation.
schema: ensure-library
	$(SYSTEM) "RUNSQLSTM SRCSTMF('$(SRCROOT)/sql/SCHEMA.sql') COMMIT(*NONE) NAMING(*SQL)"

# Rename the shared server registry and templates in place. Each script
# accepts already-renamed tables, but stops on missing or ambiguous pairs.
# Keep this target out of the fresh-install schema/app dependency chain.
upgrade-catalog: ensure-library
	$(SYSTEM) "RUNSQLSTM SRCSTMF('$(SRCROOT)/sql/RENAME_SERVERS.sql') COMMIT(*NONE) NAMING(*SQL) ERRLVL(10)"
	$(SYSTEM) "RUNSQLSTM SRCSTMF('$(SRCROOT)/sql/RENAME_TEMPLATES.sql') COMMIT(*NONE) NAMING(*SQL) ERRLVL(10)"

# Add generation metadata in place to an older installation. Rename the
# catalog first because the column upgrade reads the per-server tool files
# from MCPSERVERS. Do not run `schema` again against an existing installation.
upgrade-generation: upgrade-catalog verify-schema
	$(SYSTEM) "RUNSQLSTM SRCSTMF('$(SRCROOT)/sql/UPGRADE_GENERATION.sql') COMMIT(*NONE) NAMING(*SQL)"

verify-schema: ensure-library
	$(SYSTEM) "CHKOBJ OBJ($(LIB)/MCPSERVERS) OBJTYPE(*FILE)"
	$(SYSTEM) "CHKOBJ OBJ($(LIB)/MCPCFGTMPL) OBJTYPE(*FILE)"
	$(SYSTEM) "CHKOBJ OBJ($(LIB)/MCPTOOLTPL) OBJTYPE(*FILE)"

# Display-file creation requires DDS in a source physical file. Copying DDS
# source members does not touch the three SQL data files or generated rows.
dds-source: verify-schema
	@$(SYSTEM) "CHKOBJ OBJ($(LIB)/QDDSSRC) OBJTYPE(*FILE)" >/dev/null 2>&1 || $(SYSTEM) "CRTSRCPF FILE($(LIB)/QDDSSRC) RCDLEN(112) TEXT('MCP display DDS source')"
	$(SYSTEM) "CPYFRMSTMF FROMSTMF('$(SRCROOT)/dds/MCPSRVD.dspf') TOMBR('/QSYS.LIB/$(LIB).LIB/QDDSSRC.FILE/MCPSRVD.MBR') MBROPT(*REPLACE) CVTDTA(*AUTO) STMFCCSID(1208) ENDLINFMT(*LF)"
	$(SYSTEM) "CPYFRMSTMF FROMSTMF('$(SRCROOT)/dds/MCPTOOLD.dspf') TOMBR('/QSYS.LIB/$(LIB).LIB/QDDSSRC.FILE/MCPTOOLD.MBR') MBROPT(*REPLACE) CVTDTA(*AUTO) STMFCCSID(1208) ENDLINFMT(*LF)"

displays: dds-source
	$(SYSTEM) "CRTDSPF FILE($(LIB)/MCPSRVD) SRCFILE($(LIB)/QDDSSRC) SRCMBR(MCPSRVD) REPLACE(*YES)"
	$(SYSTEM) "CRTDSPF FILE($(LIB)/MCPTOOLD) SRCFILE($(LIB)/QDDSSRC) SRCMBR(MCPTOOLD) REPLACE(*YES)"

# The SQL precompiler accepts IFS stream files. Its INCDIR is for SQL INCLUDE;
# COMPILEOPT passes the same directory to the RPG compiler for /COPY.
modules: displays
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPJSON) SRCSTMF('$(SRCROOT)/rpg/MCPJSON.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPREG) SRCSTMF('$(SRCROOT)/rpg/MCPREG.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPHTTP) SRCSTMF('$(SRCROOT)/rpg/MCPHTTP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/SYSINFHND) SRCSTMF('$(SRCROOT)/rpg/SYSINFHND.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPLIBLIST) SRCSTMF('$(SRCROOT)/rpg/MCPLIBLIST.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPSRVAD) SRCSTMF('$(SRCROOT)/rpg/MCPSRVAD.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPTOOLADD) SRCSTMF('$(SRCROOT)/rpg/MCPTOOLADD.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"
	$(SYSTEM) "CRTSQLRPGI OBJ($(LIB)/MCPSRVOP) SRCSTMF('$(SRCROOT)/rpg/MCPSRVOP.sqlrpgle') OBJTYPE(*MODULE) COMMIT(*NONE) RDB(*NONE) OUTPUT(*PRINT) RPGPPOPT(*LVL2) INCDIR('$(SRCROOT)/copy') $(RPGOPT) REPLACE(*YES)"

programs: modules
	$(SYSTEM) "CRTPGM PGM($(LIB)/MCPHTTP) MODULE($(LIB)/MCPHTTP $(LIB)/MCPREG $(LIB)/MCPJSON) BNDSRVPGM(QHTTPSVR/QZHBCGI) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(LIB)/SYSINFHND) MODULE($(LIB)/SYSINFHND) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(LIB)/MCPLIBLIST) MODULE($(LIB)/MCPLIBLIST) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(LIB)/MCPSRVAD) MODULE($(LIB)/MCPSRVAD) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(LIB)/MCPTOOLADD) MODULE($(LIB)/MCPTOOLADD) REPLACE(*YES)"
	$(SYSTEM) "CRTPGM PGM($(LIB)/MCPSRVOP) MODULE($(LIB)/MCPSRVOP) BNDDIR(QSYS/QC2LE) REPLACE(*YES)"
	$(SYSTEM) "CRTBNDCL PGM($(LIB)/BLDMCPLIB) SRCSTMF('$(SRCROOT)/cl/BLDMCPLIB.clle') DFTACTGRP(*NO) ACTGRP(*CALLER) REPLACE(*YES)"

commands: programs
	$(SYSTEM) "CRTCMD CMD($(LIB)/CRTMCPSRV) PGM($(LIB)/MCPSRVAD) SRCSTMF('$(SRCROOT)/cmd/CRTMCPSRV.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/CHGMCPSRV) PGM($(LIB)/MCPSRVAD) SRCSTMF('$(SRCROOT)/cmd/CHGMCPSRV.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/STRMCPSRV) PGM($(LIB)/MCPSRVOP) SRCSTMF('$(SRCROOT)/cmd/STRMCPSRV.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/ENDMCPSRV) PGM($(LIB)/MCPSRVOP) SRCSTMF('$(SRCROOT)/cmd/ENDMCPSRV.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/ADDMCPTOOL) PGM($(LIB)/MCPTOOLADD) SRCSTMF('$(SRCROOT)/cmd/ADDMCPTOOL.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/EDTMCPTOOL) PGM($(LIB)/MCPTOOLADD) SRCSTMF('$(SRCROOT)/cmd/EDTMCPTOOL.cmd') REPLACE(*YES)"
	$(SYSTEM) "CRTCMD CMD($(LIB)/RMVMCPTOOL) PGM($(LIB)/MCPTOOLADD) SRCSTMF('$(SRCROOT)/cmd/RMVMCPTOOL.cmd') REPLACE(*YES)"

app: commands

# Fast structural checks run on a workstation; they do not compile IBM i code.
check:
	python3 -m unittest discover -s tests -p 'test_*.py'

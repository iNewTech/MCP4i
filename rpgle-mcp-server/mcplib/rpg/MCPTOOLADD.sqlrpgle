**free
// Shared command processing program for ADDMCPTOOL, EDTMCPTOOL, and
// RMVMCPTOOL. The command's MODE parameter chooses add, edit, or retire.
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio);
dcl-f MCPTOOLD workstn usropn extdesc('MCPLIB/MCPTOOLD')
  extfile('MCPLIB/MCPTOOLD');
dcl-pi *n;
  mode char(1) const;
  serverId char(10) const;
  publicName char(64) const;
end-pi;
dcl-pr validName ind;
  name char(10) const;
end-pr;
dcl-pr validArg ind;
  name char(128) const;
  kind char(7) const;
  required char(1) const;
end-pr;
dcl-pr addArg;
  name char(128) const;
  kind char(7) const;
  required char(1) const;
end-pr;
dcl-s tableName char(10);
dcl-s sqlText varchar(4096);
dcl-s schemaJson varchar(2048);
dcl-s properties varchar(1800);
dcl-s requiredList varchar(1000);
dcl-s toolName varchar(64);
dcl-s description varchar(256);
dcl-s arg1 varchar(128);
dcl-s arg2 varchar(128);
dcl-s arg3 varchar(128);
dcl-s previousSchema varchar(2048);
dcl-s previousLib char(10);
dcl-s previousPgm char(10);
dcl-s previousMode char(1);
dcl-s previousTargetLib char(10);
dcl-s previousTargetPgm char(10);
dcl-s originalState char(1);
dcl-s loadedTs varchar(26);
dcl-s ok ind;
exec sql set option commit = *none, naming = *sql;
toolName = %trim(publicName);
if not validName(serverId) or
   (mode <> 'A' and mode <> 'E' and mode <> 'X') or
   (mode <> 'A' and
     (toolName = '' or
      %check('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-':
             toolName) <> 0));
  dsply 'Invalid server, tool name or operation.';
  *inlr = *on;
  return;
endif;
exec sql select TOOLFILE into :tableName from MCPLIB.MCPCAT
  where SRVID = :serverId and STATE <> 'X';
if sqlcode <> 0 or %len(%trim(tableName)) <> 8 or
   %subst(tableName:1:1) <> 'T' or
   %check('0123456789':%subst(tableName:2:7)) <> 0;
  dsply 'Unknown server or invalid table mapping.';
  *inlr = *on;
  return;
endif;
if mode = 'X';
  sqlText = 'UPDATE MCPLIB.' + %trim(tableName) +
    ' SET STATE = ''X'', CHGBY = CURRENT_USER,' +
    ' CHGTS = CURRENT_TIMESTAMP WHERE TOOLNAME = ?';
  exec sql prepare retireStmt from :sqlText;
  if sqlcode = 0;
    exec sql execute retireStmt using :toolName;
  endif;
  if sqlcode <> 0 or sqlerrd(3) <> 1;
    dsply 'Tool retirement failed or tool not found.';
  else;
    dsply 'Tool retired.';
  endif;
  *inlr = *on;
  return;
endif;
open MCPTOOLD;
// ADDMCPTOOL may prefill this field, but a new name can be typed here.
// Edit uses the command's name as an immutable lookup key.
TNAME = toolName;
TLVL = 'R';
TSTATE = 'D';
GMODE = 'M';
AT1 = 'string'; AT2 = 'string'; AT3 = 'string';
AR1 = 'N'; AR2 = 'N'; AR3 = 'N';
if mode = 'E';
  sqlText = 'SELECT DESCR, HDLLIB, HDLPGM, GENMODE, TGTLIB, TGTPGM,' +
    ' TOOL_LVL, STATE,' +
    ' ARG1NAME, ARG1TYPE, ARG1REQ, ARG2NAME, ARG2TYPE, ARG2REQ,' +
    ' ARG3NAME, ARG3TYPE, ARG3REQ, SCHEMAJSON,' +
    ' CHAR(CHGTS) FROM MCPLIB.' + %trim(tableName) +
    ' WHERE TOOLNAME = ?';
  exec sql prepare loadStmt from :sqlText;
  if sqlcode = 0;
    exec sql declare loadCur cursor for loadStmt;
    exec sql open loadCur using :toolName;
    if sqlcode = 0;
      exec sql fetch loadCur into :TDESC, :HLIB, :HPGM, :GMODE,
        :TLIB, :TPGM, :TLVL, :TSTATE,
        :AN1, :AT1, :AR1, :AN2, :AT2, :AR2, :AN3, :AT3, :AR3,
        :previousSchema, :loadedTs;
      ok = sqlcode = 0;
      if ok;
        previousLib = HLIB;
        previousPgm = HPGM;
        previousMode = GMODE;
        previousTargetLib = TLIB;
        previousTargetPgm = TPGM;
        originalState = TSTATE;
      endif;
      exec sql close loadCur;
    endif;
  endif;
  if not ok;
    close MCPTOOLD;
    dsply 'Cannot load tool.';
    *inlr = *on;
    return;
  endif;
endif;
ERRMSG = 'G/T save draft. Build wrapper and review target authority before A.';
dow *on;
  exfmt TOOLREC;
  if *in03;
    leave;
  endif;
  ERRMSG = '';
  if mode = 'E' and %trim(TNAME) <> toolName;
    ERRMSG = 'Tool name cannot change here; add a new tool instead.';
    iter;
  endif;
  if mode = 'A';
    toolName = %trim(TNAME);
    if toolName = '' or
       %check('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-':
              toolName) <> 0;
      ERRMSG = 'Enter a tool name using letters, digits, dot, dash or underscore.';
      iter;
    endif;
  endif;
  if %trim(TDESC) = '' or not validName(HLIB) or not validName(HPGM);
    ERRMSG = 'Description and explicit uppercase library/program are required.';
    iter;
  endif;
  // The native target and MCP handler are distinct *PGM objects. The handler
  // always receives the four-parameter MCP ABI; a generated handler may call
  // the selected target with its separately reviewed native parameter list.
  if GMODE <> 'M' and GMODE <> 'G' and GMODE <> 'T';
    ERRMSG = 'Mode must be M (manual), G (generate), or T (template).';
    iter;
  endif;
  if GMODE = 'M';
    if TLIB <> '' or TPGM <> '';
      ERRMSG = 'Manual mode uses the handler directly; clear target fields.';
      iter;
    endif;
  else;
    if not validName(TLIB) or not validName(TPGM);
      ERRMSG = 'Generated modes need an uppercase target library/program.';
      iter;
    endif;
    if HLIB = TLIB and HPGM = TPGM;
      ERRMSG = 'Handler and native target must be different programs.';
      iter;
    endif;
  endif;
  if %check('RWD':TLVL) <> 0 or %check('DAX':TSTATE) <> 0 or
     (TSTATE = 'A' and TLVL <> 'R');
    ERRMSG = 'States: D draft, A active, X retired. Only READ (R) can be active.';
    iter;
  endif;
  if mode = 'A' and TSTATE <> 'D';
    ERRMSG = 'New tools must be draft (D); use EDTMCPTOOL after review to publish.';
    iter;
  endif;
  if not validArg(AN1:AT1:AR1) or not validArg(AN2:AT2:AR2) or
     not validArg(AN3:AT3:AR3) or
     (AN1 <> '' and (AN1 = AN2 or AN1 = AN3)) or
     (AN2 <> '' and AN2 = AN3);
    ERRMSG = 'Arguments need unique names, supported types, and Y/N required flags.';
    iter;
  endif;
  // G/T are intentionally saved as draft before source generation. A manual
  // tool, or any tool being published, must already have a compiled handler.
  if GMODE = 'M' or TSTATE = 'A';
    sqlText = 'CHKOBJ OBJ(' + %trim(HLIB) + '/' + %trim(HPGM) +
              ') OBJTYPE(*PGM)';
    exec sql call QSYS2.QCMDEXC(:sqlText);
    if sqlcode <> 0;
      ERRMSG = 'Qualified handler *PGM does not exist or is not accessible.';
      iter;
    endif;
  endif;
  if GMODE = 'G' or GMODE = 'T';
    sqlText = 'CHKOBJ OBJ(' + %trim(TLIB) + '/' + %trim(TPGM) +
              ') OBJTYPE(*PGM)';
    exec sql call QSYS2.QCMDEXC(:sqlText);
    if sqlcode <> 0;
      ERRMSG = 'Qualified target *PGM does not exist or is not accessible.';
      iter;
    endif;
  endif;
  clear properties;
  clear requiredList;
  ok = *on;
  addArg(AN1:AT1:AR1); addArg(AN2:AT2:AR2); addArg(AN3:AT3:AR3);
  if not ok;
    ERRMSG = 'Cannot generate JSON schema.';
    iter;
  endif;
  if %len(properties) + %len(requiredList) + 80 > 2048;
    ERRMSG = 'Schema exceeds 2048 bytes; shorten argument names.';
    iter;
  endif;
  schemaJson = '{"type":"object","properties":{' + properties +
    '},"required":[' + requiredList + '],"additionalProperties":false}';
  if mode = 'E' and originalState = 'A' and TSTATE = 'A' and
     (HLIB <> previousLib or HPGM <> previousPgm or
      GMODE <> previousMode or TLIB <> previousTargetLib or
      TPGM <> previousTargetPgm or
      schemaJson <> previousSchema);
    ERRMSG = 'Save handler, target or schema changes as draft; then review.';
    iter;
  endif;
  description = %trim(TDESC);
  arg1 = %trim(AN1); arg2 = %trim(AN2); arg3 = %trim(AN3);
  if mode = 'A';
    sqlText = 'INSERT INTO MCPLIB.' + %trim(tableName) +
      ' (DESCR, HDLLIB, HDLPGM, GENMODE, TGTLIB, TGTPGM,' +
      ' TOOL_LVL, STATE, SCHEMAJSON,' +
      ' ARG1NAME, ARG1TYPE, ARG1REQ, ARG2NAME, ARG2TYPE, ARG2REQ,' +
      ' ARG3NAME, ARG3TYPE, ARG3REQ, TOOLNAME, CRTBY, CHGBY)' +
      ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,' +
      ' CURRENT_USER, CURRENT_USER)';
  else;
    sqlText = 'UPDATE MCPLIB.' + %trim(tableName) +
      ' SET DESCR=?, HDLLIB=?, HDLPGM=?, GENMODE=?, TGTLIB=?, TGTPGM=?,' +
      ' TOOL_LVL=?, STATE=?,' +
      ' SCHEMAJSON=?, ARG1NAME=?, ARG1TYPE=?, ARG1REQ=?,' +
      ' ARG2NAME=?, ARG2TYPE=?, ARG2REQ=?, ARG3NAME=?, ARG3TYPE=?,' +
      ' ARG3REQ=?, CHGBY=CURRENT_USER, CHGTS=CURRENT_TIMESTAMP' +
      ' WHERE TOOLNAME=? AND CHAR(CHGTS)=?';
  endif;
  exec sql prepare saveStmt from :sqlText;
  if sqlcode = 0;
    if mode = 'A';
      exec sql execute saveStmt using :description, :HLIB, :HPGM,
        :GMODE, :TLIB, :TPGM,
        :TLVL, :TSTATE, :schemaJson, :arg1, :AT1, :AR1, :arg2, :AT2,
        :AR2, :arg3, :AT3, :AR3, :toolName;
    else;
      exec sql execute saveStmt using :description, :HLIB, :HPGM,
        :GMODE, :TLIB, :TPGM,
        :TLVL, :TSTATE, :schemaJson, :arg1, :AT1, :AR1, :arg2, :AT2,
        :AR2, :arg3, :AT3, :AR3, :toolName, :loadedTs;
    endif;
  endif;
  ok = sqlcode = 0 and sqlerrd(3) = 1;
  if not ok;
    if mode = 'E' and sqlcode = 0 and sqlerrd(3) = 0;
      ERRMSG = 'Tool changed while screen was open; cancel and reopen.';
    else;
      ERRMSG = 'Save failed: duplicate name, missing row, or database error. Check job log.';
    endif;
    iter;
  endif;
  leave;
enddo;
close MCPTOOLD;
*inlr = *on;
return;

dcl-proc validName;
  dcl-pi *n ind; name char(10) const; end-pi;
  if name = '';
    return *off;
  endif;
  return %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':%subst(name:1:1)) = 0 and
    %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_':%trim(name)) = 0;
end-proc;

dcl-proc validArg;
  dcl-pi *n ind;
    name char(128) const;
    kind char(7) const;
    required char(1) const;
  end-pi;
  return (kind = 'string' or kind = 'integer' or kind = 'number' or
          kind = 'boolean') and (required = 'Y' or required = 'N') and
         (name <> '' or required = 'N');
end-proc;

dcl-proc addArg;
  dcl-pi *n;
    name char(128) const;
    kind char(7) const;
    required char(1) const;
  end-pi;
  dcl-s quotedName varchar(800);
  dcl-s typeJson varchar(100);
  if name = '' or not ok;
    return;
  endif;
  // Db2 escapes user text; never concatenate raw field names into JSON.
  exec sql values json_array(trim(:name) returning varchar(800)),
    json_object('type' value trim(:kind) returning varchar(100))
    into :quotedName, :typeJson;
  if sqlcode <> 0;
    ok = *off;
    return;
  endif;
  quotedName = %subst(quotedName:2:%len(quotedName)-2);
  if %len(properties) + %len(quotedName) + %len(typeJson) + 2 > 1800 or
     %len(requiredList) + %len(quotedName) + 1 > 1000;
    ok = *off;
    return;
  endif;
  if properties <> ''; properties += ','; endif;
  properties += quotedName + ':' + typeJson;
  if required = 'Y';
    if requiredList <> ''; requiredList += ','; endif;
    requiredList += quotedName;
  endif;
end-proc;

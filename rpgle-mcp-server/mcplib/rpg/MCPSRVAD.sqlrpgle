**free
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio);
dcl-f MCPSRVD workstn extdesc('MCPLIB/MCPSRVD')
  extfile('MCPLIB/MCPSRVD');
dcl-pi *n;
  mode char(1) const;
  serverId char(10) const;
end-pi;
dcl-pr runSql ind;
  statement varchar(4096) const;
end-pr;
dcl-s sqlText varchar(4096);
dcl-s cfgFile char(10);
dcl-s toolFile char(10);
dcl-s serial int(10);
dcl-s serialName packed(7:0);
dcl-s cfgMade ind inz(*off);
dcl-s toolMade ind inz(*off);
dcl-s lockHeld ind inz(*off);
dcl-s ok ind;
dcl-s displayName varchar(64);
dcl-s libraryList varchar(2750);
dcl-s oldLibl varchar(2750);
dcl-s oldTime int(10);
dcl-s portNumber int(10);
dcl-s timeLimit int(10);
dcl-s loadedTs varchar(26);
dcl-s stale ind inz(*off);
exec sql set option commit = *none, naming = *sql;
if serverId = '' or
   %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':%subst(serverId:1:1)) <> 0 or
   %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_':%trim(serverId)) <> 0 or
   (mode <> 'C' and mode <> 'E');
  dsply 'Invalid server ID or operation.';
  *inlr = *on;
  return;
endif;
SPORT = 8080; SMAX = 'R'; SSTATE = 'D'; STIME = 30;
if mode = 'E';
  exec sql select DISPNAME, PORT, MAXLVL, STATE, CFGFILE, TOOLFILE,
    CHAR(CHGTS)
    into :SNAME, :SPORT, :SMAX, :SSTATE, :cfgFile, :toolFile,
         :loadedTs
    from MCPLIB.MCPSERVERS where SRVID = :serverId;
  ok = sqlcode = 0;
  if ok;
    ok = %len(%trim(cfgFile)) = 8 and %subst(cfgFile:1:1) = 'S' and
         %check('0123456789':%subst(cfgFile:2:7)) = 0;
  endif;
  if ok;
    sqlText = 'SELECT LIBLIST, TIMEOUT FROM MCPLIB.' + %trim(cfgFile) +
              ' WHERE CFGID = 1';
    exec sql prepare cfgRead from :sqlText;
    if sqlcode = 0;
      exec sql declare cfgCur cursor for cfgRead;
      exec sql open cfgCur;
      if sqlcode = 0;
        exec sql fetch cfgCur into :oldLibl, :oldTime;
        ok = sqlcode = 0;
        exec sql close cfgCur;
      else;
        ok = *off;
      endif;
    else;
      ok = *off;
    endif;
  endif;
  if not ok or %len(oldLibl) > 128;
    dsply 'Cannot load settings (screen limit: 128 LIBLIST).';
    exsr unlock;
    *inlr = *on;
    return;
  endif;
  SLIBL = oldLibl; STIME = oldTime;
endif;
dow *on;
  exfmt SRVREC;
  if *in03; leave; endif;
  ERRMSG = '';
  if SNAME = '' or SPORT < 1024 or SPORT > 65535 or
     STIME < 1 or STIME > 3600 or %check('RWD':SMAX) <> 0 or
     %check('DAX':SSTATE) <> 0;
    ERRMSG = 'Name required; port 1024-65535; timeout 1-3600; capability R/W/D; state D/A/X.';
    iter;
  endif;
  if mode = 'C' and SSTATE <> 'D';
    ERRMSG = 'Create in draft (D). Provision Apache before activating the server.';
    iter;
  endif;
  displayName = %trim(SNAME); libraryList = %trim(SLIBL);
  portNumber = SPORT; timeLimit = STIME;
  // Lock only during the save. The user may spend minutes on EXFMT; holding
  // the catalog lock while waiting would block other administrators.
  sqlText = 'ALCOBJ OBJ((MCPLIB/MCPSERVERS *FILE *EXCLRD)) WAIT(0)';
  exec sql call QSYS2.QCMDEXC(:sqlText);
  if sqlcode <> 0;
    ERRMSG = 'Catalog busy or unavailable. Retry later.';
    iter;
  endif;
  lockHeld = *on;
  stale = *off;
  if mode = 'C';
    cfgMade = *off; toolMade = *off;
    // Catalog lock prevents allocation races between these command programs.
    exec sql select coalesce(max(integer(substr(CFGFILE,2,7))),0) + 1
      into :serial from MCPLIB.MCPSERVERS;
    if sqlcode <> 0 or serial > 9999999;
      ERRMSG = 'Cannot allocate a server table number.';
      exsr unlock;
      iter;
    endif;
    serialName = serial;
    cfgFile = 'S' + %digits(serialName);
    toolFile = 'T' + %digits(serialName);
    cfgMade = runSql('CREATE TABLE MCPLIB.' + %trim(cfgFile) +
      ' LIKE MCPLIB.MCPCFGTMPL INCLUDING COLUMN DEFAULTS');
    ok = cfgMade;
    if ok;
      ok = runSql('ALTER TABLE MCPLIB.' + %trim(cfgFile) +
        ' ADD PRIMARY KEY (CFGID)');
    endif;
    if ok;
      ok = runSql('ALTER TABLE MCPLIB.' + %trim(cfgFile) +
        ' ADD CHECK (CFGID = 1 AND TIMEOUT BETWEEN 1 AND 3600)');
    endif;
    if ok;
      toolMade = runSql('CREATE TABLE MCPLIB.' + %trim(toolFile) +
        ' LIKE MCPLIB.MCPTOOLTPL INCLUDING COLUMN DEFAULTS');
      ok = toolMade;
    endif;
    if ok;
      ok = runSql('ALTER TABLE MCPLIB.' + %trim(toolFile) +
        ' ADD PRIMARY KEY (TOOLNAME)');
    endif;
    if ok;
      ok = runSql('ALTER TABLE MCPLIB.' + %trim(toolFile) +
        ' ADD CHECK (TOOL_LVL IN (''R'', ''W'', ''D'')' +
        ' AND STATE IN (''D'', ''A'', ''X'')' +
        ' AND (STATE <> ''A'' OR TOOL_LVL = ''R'')' +
        ' AND GENMODE IN (''M'', ''G'', ''T'')' +
        ' AND ARG1TYPE IN (''string'', ''integer'',' +
        ' ''number'', ''boolean'')' +
        ' AND ARG1REQ IN (''Y'', ''N'')' +
        ' AND ARG2TYPE IN (''string'', ''integer'',' +
        ' ''number'', ''boolean'')' +
        ' AND ARG2REQ IN (''Y'', ''N'')' +
        ' AND ARG3TYPE IN (''string'', ''integer'',' +
        ' ''number'', ''boolean'')' +
        ' AND ARG3REQ IN (''Y'', ''N''))');
    endif;
    if ok;
      // Constraint names must be unique within MCPLIB, so derive one from
      // this server's table number. The upgrade script uses the same name.
      ok = runSql('ALTER TABLE MCPLIB.' + %trim(toolFile) +
        ' ADD CONSTRAINT G' + %subst(toolFile:2:7) +
        ' CHECK (GENMODE = ''M'' OR' +
        ' (TGTLIB <> '''' AND TGTPGM <> ''''))');
    endif;
    if ok;
      sqlText = 'INSERT INTO MCPLIB.' + %trim(cfgFile) +
        ' (CFGID, LIBLIST, TIMEOUT) VALUES (1, ?, ?)';
      exec sql prepare cfgSave from :sqlText;
      ok = sqlcode = 0;
      if ok;
        exec sql execute cfgSave using :libraryList, :timeLimit;
        ok = sqlcode = 0;
      endif;
    endif;
    if ok;
      exec sql INSERT INTO MCPLIB.MCPSERVERS
        (SRVID, DISPNAME, PORT, CFGFILE, TOOLFILE, MAXLVL, STATE, CRTBY, CHGBY)
        values (:serverId, :displayName, :portNumber, :cfgFile, :toolFile,
                :SMAX, 'D', CURRENT_USER, CURRENT_USER);
      ok = sqlcode = 0;
    endif;
    if not ok;
      // Drop only objects created by this invocation. A failed CREATE may
      // refer to a pre-existing object and must never trigger its deletion.
      if toolMade;
        if not runSql('DROP TABLE MCPLIB.' + %trim(toolFile));
          dsply 'Cleanup failed; inspect orphan tool table.';
        endif;
      endif;
      if cfgMade;
        if not runSql('DROP TABLE MCPLIB.' + %trim(cfgFile));
          dsply 'Cleanup failed; inspect orphan config table.';
        endif;
      endif;
      ERRMSG = 'Create failed. Check duplicate ID/port, orphan files, authority, and job log.';
      exsr unlock;
      iter;
    endif;
  else;
    // Refresh compensation values after acquiring the lock. Another
    // administrator may have edited this server while this screen was open.
    exec sql open cfgCur;
    if sqlcode = 0;
      exec sql fetch cfgCur into :oldLibl, :oldTime;
      ok = sqlcode = 0;
      exec sql close cfgCur;
    else;
      ok = *off;
    endif;
    if not ok;
      ERRMSG = 'Cannot refresh current settings; retry the change.';
      exsr unlock;
      iter;
    endif;
    // COMPENSATION under COMMIT(*NONE): preserve old config if catalog
    // uniqueness rejects the port change. A crash between statements still
    // requires operator reconciliation; see task report before deployment.
    sqlText = 'UPDATE MCPLIB.' + %trim(cfgFile) +
      ' SET LIBLIST=?, TIMEOUT=? WHERE CFGID=1';
    exec sql prepare cfgChange from :sqlText;
    ok = sqlcode = 0;
    if ok;
      exec sql execute cfgChange using :libraryList, :timeLimit;
      ok = sqlcode = 0 and sqlerrd(3) = 1;
    endif;
    if ok;
      exec sql update MCPLIB.MCPSERVERS set DISPNAME=:displayName,
        PORT=:portNumber, MAXLVL=:SMAX, STATE=:SSTATE,
        CHGBY=CURRENT_USER, CHGTS=CURRENT_TIMESTAMP
        where SRVID=:serverId and CHAR(CHGTS)=:loadedTs;
      stale = sqlcode = 0 and sqlerrd(3) = 0;
      ok = sqlcode = 0 and sqlerrd(3) = 1;
      if not ok;
        exec sql execute cfgChange using :oldLibl, :oldTime;
        if sqlcode <> 0;
          dsply 'Config recovery failed. Inspect database/job log.';
        endif;
      endif;
    endif;
    if not ok;
      if stale;
        ERRMSG = 'Server changed while screen was open; cancel and reopen.';
      else;
        ERRMSG = 'Change failed. Check port uniqueness and job log.';
      endif;
      exsr unlock;
      iter;
    endif;
  endif;
  leave;
enddo;
exsr unlock;
*inlr = *on;
return;
begsr unlock;
  if lockHeld;
    sqlText = 'DLCOBJ OBJ((MCPLIB/MCPSERVERS *FILE *EXCLRD))';
    exec sql call QSYS2.QCMDEXC(:sqlText);
    lockHeld = *off;
  endif;
endsr;
dcl-proc runSql;
  dcl-pi *n ind; statement varchar(4096) const; end-pi;
  exec sql execute immediate :statement;
  return sqlcode = 0;
end-proc;

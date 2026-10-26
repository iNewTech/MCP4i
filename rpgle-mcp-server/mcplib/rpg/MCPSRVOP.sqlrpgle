**free
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio);
dcl-pi *n;
  mode char(1) const;
  serverId char(10) const;
end-pi;
dcl-pr access int(10) extproc('access');
  path pointer value options(*string);
  accessMode int(10) value;
end-pr;
dcl-s sqlText varchar(1024);
dcl-s configPath varchar(256);
dcl-s serverState char(1);
exec sql set option commit = *none, naming = *sql;
if serverId = '' or
   %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ':%subst(serverId:1:1)) <> 0 or
   %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_':%trim(serverId)) <> 0 or
   (mode <> 'S' and mode <> 'E');
  dsply 'Invalid server ID or operation.';
  *inlr = *on;
  return;
endif;
exec sql select STATE into :serverState from MCPLIB.MCPSERVERS
  where SRVID = :serverId;
if sqlcode <> 0;
  dsply 'Server not found or catalog unavailable.';
  *inlr = *on;
  return;
endif;
// Infrastructure contract: provision /www/ID/conf/httpd.conf and matching
// IBM HTTP instance before invoking this command. CRTMCPSRV creates data only.
configPath = '/www/' + %trim(serverId) + '/conf/httpd.conf';
if access(%trim(configPath):0) <> 0;
  dsply 'Provision the IBM HTTP instance before start/end.';
  *inlr = *on;
  return;
endif;
if mode = 'S';
  if serverState <> 'A';
    dsply 'Activate server with CHGMCPSRV before starting.';
    *inlr = *on;
    return;
  endif;
  sqlText = 'STRTCPSVR SERVER(*HTTP) HTTPSVR(' + %trim(serverId) + ')';
else;
  sqlText = 'ENDTCPSVR SERVER(*HTTP) HTTPSVR(' + %trim(serverId) + ')';
endif;
exec sql call QSYS2.QCMDEXC(:sqlText);
if sqlcode <> 0;
  dsply 'HTTP instance command failed; inspect job log.';
else;
  dsply 'HTTP instance command accepted; verify job status.';
endif;
*inlr = *on;
return;

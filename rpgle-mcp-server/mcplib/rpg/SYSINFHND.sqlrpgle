**free
// SYSINFHND is the standalone *PGM handler for get_system_info.
// The registry calls it without binding it into MCPHTTP. It returns data,
// not MCP/HTTP.
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

/copy 'MCPABI.rpgleinc'

dcl-pi *n;
  argsJson char(8192);
  resultJson char(8192);
  resultLen int(10);
  statusCode int(10);
end-pi;
dcl-s inputJson varchar(8192);
dcl-s payloadJson varchar(4096);
dcl-s validArgs int(10);

clear resultJson;
resultLen = 0;
statusCode = 1;
inputJson = %trim(argsJson);

// The advertised schema has no fields. Reject unexpected fields instead
// of silently ignoring a caller's arguments.
exec sql values case
  when :inputJson is json object with unique keys and
       not json_exists(:inputJson, '$.*') then 1 else 0 end
  into :validArgs;
if sqlcode <> 0 or validArgs <> 1;
  *inlr = *on;
  return;
endif;

exec sql
  select json_object(
           'os_name' value os_name,
           'os_version' value os_version,
           'os_release' value os_release,
           'host_name' value host_name,
           'observed_at_local' value char(current_timestamp)
           returning varchar(4096))
    into :payloadJson
    from sysibmadm.env_sys_info;
if sqlcode = 0 and payloadJson <> '';
  resultJson = %trim(payloadJson);
  resultLen = %len(%trim(payloadJson));
  statusCode = 0;
endif;
*inlr = *on;
return;

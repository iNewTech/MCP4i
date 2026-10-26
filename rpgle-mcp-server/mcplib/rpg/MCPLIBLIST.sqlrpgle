**free
// Standalone *PGM handler for get_library_list. It reads the CGI request
// job's library list, not the MCP user's separate interactive job.
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

/copy 'MCPABI.rpgleinc'

dcl-c MAX_LIBRARIES 40;

dcl-pi *n;
  argsJson char(8192);
  resultJson char(8192);
  resultLen int(10);
  statusCode int(10);
end-pi;
dcl-s inputJson varchar(8192);
dcl-s validArgs int(10);
dcl-s ordinalPosition int(10);
dcl-s libraryName varchar(10);
dcl-s entryType varchar(15);
dcl-s entryJson varchar(256);
dcl-s payloadJson varchar(4096);
dcl-s observedAt varchar(26);
dcl-s returnedCount int(10) inz(0);
dcl-s truncatedJson varchar(5) inz('false');

clear resultJson;
resultLen = 0;
statusCode = 1;
inputJson = %trim(argsJson);

// This first sample tool also advertises a no-argument schema.
exec sql values case
  when :inputJson is json object with unique keys and
       not json_exists(:inputJson, '$.*') then 1 else 0 end
  into :validArgs;
if sqlcode <> 0 or validArgs <> 1;
  *inlr = *on;
  return;
endif;

exec sql declare libCursor cursor for
  select ordinal_position, system_schema_name, "TYPE"
    from qsys2.library_list_info
   order by ordinal_position;

exec sql values char(current_timestamp) into :observedAt;
if sqlcode <> 0;
  *inlr = *on;
  return;
endif;
payloadJson = '{"scope":"current_cgi_job",' +
  '"observed_at_local":"' + %trim(observedAt) + '",' +
  '"libraries":[';

exec sql open libCursor;
if sqlcode <> 0;
  *inlr = *on;
  return;
endif;
dow *on;
  exec sql fetch libCursor into :ordinalPosition, :libraryName,
    :entryType;
  if sqlcode = 100;
    leave;
  endif;
  if sqlcode <> 0;
    exec sql close libCursor;
    *inlr = *on;
    return;
  endif;
  if returnedCount >= MAX_LIBRARIES;
    truncatedJson = 'true';
    leave;
  endif;
  exec sql values json_object(
    'position' value :ordinalPosition,
    'library' value :libraryName,
    'type' value :entryType
    returning varchar(256)) into :entryJson;
  if sqlcode <> 0;
    exec sql close libCursor;
    *inlr = *on;
    return;
  endif;
  if %len(payloadJson) + %len(%trim(entryJson)) + 110 > 4096;
    truncatedJson = 'true';
    leave;
  endif;
  if returnedCount > 0;
    payloadJson += ',';
  endif;
  payloadJson += %trim(entryJson);
  returnedCount += 1;
enddo;
exec sql close libCursor;
if sqlcode <> 0;
  *inlr = *on;
  return;
endif;
payloadJson += '],"returned_count":' + %char(returnedCount) +
  ',"truncated":' + truncatedJson + '}';
resultJson = payloadJson;
resultLen = %len(payloadJson);
statusCode = 0;
*inlr = *on;
return;

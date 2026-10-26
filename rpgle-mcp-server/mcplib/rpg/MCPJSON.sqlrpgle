**free
// Shared MCP text-result formatter. Each tool passes its own JSON payload.
// Db2 JSON_OBJECT escapes it as a string before it enters the MCP envelope.
ctl-opt nomain option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

dcl-proc asTextToolResult export;
  dcl-pi *n varchar(8192);
    payloadJson varchar(4096) const;
  end-pi;
  dcl-s messageText varchar(4096);
  // Leave room in the 8192-character result for the MCP content envelope.
  dcl-s contentJson varchar(8100);

  // Copy the procedure input to a local SQL host variable.
  messageText = payloadJson;
  exec sql
    values json_object('type' value 'text',
                       'text' value :messageText
                       returning varchar(8100))
      into :contentJson;
  if sqlcode <> 0;
    return '{"content":[{"type":"text",' +
      '"text":"Could not format tool result."}],' +
      '"isError":true}';
  endif;
  return '{"content":[' + %trim(contentJson) +
    '],"isError":false}';
end-proc;

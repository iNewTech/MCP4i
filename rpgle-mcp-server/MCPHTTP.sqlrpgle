**free
// One ILE RPG program is both the MCP protocol handler and the IBM i reader.
// IBM HTTP Server invokes it as CGI for each POST /mcp request.
// Read this file top to bottom: CGI input -> JSON-RPC dispatch -> CGI output.
// Tool metadata and tool execution live in separate named subprocedures.
// Only the fixed get_system_info tool touches IBM i data in this lesson.
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

// All SQL is local and read-only. The same rule is set in the build command.
exec sql set option commit = *none, naming = *sql;

// IBM's RPG CGI example uses x'15' as the output line-feed character.
// MAX_BODY is also the advertised HTTP LimitRequestBody in the config file.
dcl-c LF x'15';
dcl-c MAX_BODY 16384;
dcl-c SYS_INFO_TOOL 'get_system_info';

// IBM's QUSEC API error structure. Supplying 16 bytes returns error details
// instead of sending an unhandled escape message into the CGI job.
dcl-ds apiError qualified;
  bytesProvided int(10) inz(16);
  bytesAvailable int(10) inz(0);
  exceptionId char(7);
  reserved char(1);
end-ds;

// QtmhGetEnv reads CGI variables set by IBM HTTP Server, not shell variables.
dcl-pr QtmhGetEnv extproc('QtmhGetEnv');
  receiver char(1) options(*varsize);
  receiverLength int(10) const;
  valueLength int(10);
  variableName char(1) const options(*varsize);
  nameLength int(10) const;
  errorCode likeds(apiError);
end-pr;

// QtmhRdStin reads the POST body. This does not open a network socket.
dcl-pr QtmhRdStin extproc('QtmhRdStin');
  receiver char(1) options(*varsize);
  receiverLength int(10) const;
  valueLength int(10);
  errorCode likeds(apiError);
end-pr;

// QtmhWrStout sends CGI headers followed by the JSON body to HTTP Server.
dcl-pr QtmhWrStout extproc('QtmhWrStout');
  data char(1) const options(*varsize);
  dataLength int(10) const;
  errorCode likeds(apiError);
end-pr;

// These prototypes are a map of the lesson. The first four procedures handle
// transport and MCP routing; tool registration/execution stays below them.
dcl-pr handleRequest;
end-pr;

dcl-pr readHttpRequest ind;
end-pr;

dcl-pr parseRpcRequest ind;
end-pr;

dcl-pr dispatchRpcRequest;
end-pr;

// TOOL REGISTRY: listTools joins tool definitions for tools/list.
// TOOL DEFINITION: getSysInfoTool returns metadata, never reads IBM i data.
dcl-pr listTools varchar(8192);
end-pr;

dcl-pr callRegisteredTool varchar(8192);
  requestedTool varchar(64) const;
end-pr;

dcl-pr getSysInfoTool varchar(512);
end-pr;

// TOOL EXECUTION: runSysInfoTool coordinates the fixed read and MCP result.
dcl-pr runSysInfoTool varchar(8192);
end-pr;

dcl-pr readSysInfo varchar(4096);
end-pr;

dcl-pr asTextToolResult varchar(8192);
  systemJson varchar(4096) const;
end-pr;

dcl-pr getEnv varchar(1024);
  name varchar(64) const;
end-pr;

dcl-pr rpcError varchar(1024);
  requestId varchar(510) const;
  code int(10) const;
  message varchar(64) const;
end-pr;

dcl-pr sendHttp;
  status varchar(64) const;
  body varchar(16384) const;
  extraHeader varchar(128) const;
end-pr;

// Only values shared across request stages are global. Each CGI invocation
// handles one request; subprocedure-only buffers are declared locally below.
// An arbitrary SQL runner or caller-selected IBM i system is not present.
dcl-s requestJson varchar(MAX_BODY);
dcl-s methodName varchar(64);
dcl-s rpcVersion varchar(16);
dcl-s toolName varchar(64);
dcl-s idRaw varchar(510);

// CGI starts here once per HTTP request. There is no forever loop or SBMJOB.
handleRequest();
*inlr = *on;
return;

dcl-proc handleRequest;
  // The main procedure is a reading map: HTTP -> JSON-RPC -> MCP response.
  if readHttpRequest() = *off;
    return;
  endif;
  if parseRpcRequest() = *off;
    return;
  endif;
  dispatchRpcRequest();
end-proc;

dcl-proc readHttpRequest;
  dcl-pi *n ind;
  end-pi;
  dcl-s lengthText varchar(1024);
  dcl-s httpMethod varchar(1024);
  dcl-s contentType varchar(1024);
  dcl-s contentLength int(10);
  dcl-s bytesRead int(10);
  dcl-s rawInput char(MAX_BODY);

  // Streamable HTTP sends MCP messages by POST. GET would require a server
  // event stream, which this first one-tool version does not implement.
  httpMethod = getEnv('REQUEST_METHOD');
  if httpMethod <> 'POST';
    sendHttp('405 Method Not Allowed': '': 'Allow: POST');
    return *off;
  endif;

  // Reject browser-origin requests to avoid DNS-rebinding exposure. The
  // sample listener is loopback-only; remote deployment needs its own policy.
  if getEnv('HTTP_ORIGIN') <> '';
    sendHttp('403 Forbidden': '': '');
    return *off;
  endif;

  // CGI supplies CONTENT_TYPE without an HTTP_ prefix. A charset suffix is
  // allowed, but the request must still be JSON.
  contentType = %xlate('ABCDEFGHIJKLMNOPQRSTUVWXYZ':
                       'abcdefghijklmnopqrstuvwxyz':
                       getEnv('CONTENT_TYPE'));
  if %scan('application/json': contentType) <> 1;
    sendHttp('415 Unsupported Media Type': '': '');
    return *off;
  endif;

  // Check digits and width BEFORE %INT, so an oversized number cannot cause
  // an RPG numeric conversion exception. Never allocate from client input.
  lengthText = getEnv('CONTENT_LENGTH');
  if lengthText = '' or %len(lengthText) > 5 or
     %check('0123456789': lengthText) <> 0;
    sendHttp('400 Bad Request': '': '');
    return *off;
  endif;
  contentLength = %int(lengthText);
  if contentLength < 1 or contentLength > MAX_BODY;
    sendHttp('413 Content Too Large': '': '');
    return *off;
  endif;

  // QtmhRdStin provides the body already converted to the CGI job CCSID by
  // the HTTP instance's CGIConvMode EBCDIC setting.
  clear rawInput;
  QtmhRdStin(rawInput: contentLength: bytesRead: apiError);
  if bytesRead <> contentLength or apiError.bytesAvailable > 0;
    sendHttp('400 Bad Request': '': '');
    return *off;
  endif;
  requestJson = %subst(rawInput: 1: bytesRead);
  return *on;
end-proc;

dcl-proc parseRpcRequest;
  dcl-pi *n ind;
  end-pi;
  dcl-s validJson int(10);
  dcl-s idWrapped varchar(512);

  // Db2 for i parses JSON; no substring matching of method or tool names.
  // The unique-key check avoids accepting ambiguous JSON such as two methods.
  // Example input: {"jsonrpc":"2.0","id":1,"method":"tools/list"}.
  // Missing scalar properties become empty strings, then fail dispatch.
  exec sql
    select case when :requestJson is json object with unique keys
                then 1 else 0 end
      into :validJson
      from sysibm.sysdummy1;
  if sqlcode <> 0 or validJson <> 1;
    sendHttp('200 OK': rpcError('null': -32700: 'Parse error'): '');
    return *off;
  endif;

  exec sql
    select coalesce(json_value(:requestJson, '$.jsonrpc'
             returning varchar(16)), ''),
           coalesce(json_value(:requestJson, '$.method'
             returning varchar(64)), ''),
           coalesce(json_value(:requestJson, '$.params.name'
             returning varchar(64)), ''),
           coalesce(json_query(:requestJson, '$.id'
             returning varchar(512) with unconditional array wrapper), '[]')
      into :rpcVersion, :methodName, :toolName, :idWrapped
      from sysibm.sysdummy1;
  if sqlcode <> 0;
    sendHttp('200 OK': rpcError('null': -32600: 'Invalid Request'): '');
    return *off;
  endif;

  // JSON_QUERY with an array wrapper gives [1] or ["abc"]. Removing the
  // outer brackets preserves the ID's JSON type in our response. JSON_VALUE
  // alone would convert both IDs to an SQL string and break client matching.
  idRaw = 'null';
  if %len(idWrapped) > 2;
    idRaw = %subst(idWrapped: 2: %len(idWrapped) - 2);
  endif;
  if idRaw = 'null' or
     %check('"-0123456789': %subst(idRaw: 1: 1)) <> 0;
    if methodName = 'notifications/initialized';
      sendHttp('202 Accepted': '': '');
    else;
      sendHttp('200 OK': rpcError('null': -32600: 'Invalid Request'): '');
    endif;
    return *off;
  endif;
  if rpcVersion <> '2.0';
    sendHttp('200 OK': rpcError(idRaw: -32600: 'Invalid Request'): '');
    return *off;
  endif;

  return *on;
end-proc;

dcl-proc dispatchRpcRequest;
  dcl-s resultJson varchar(16384);

  // MCP lifecycle first: initialize announces protocol and tools capability.
  // The client then sends notifications/initialized (handled above with 202).
  select;
  when methodName = 'initialize';
    resultJson = '{"protocolVersion":"2025-11-25",' +
      '"capabilities":{"tools":{}},' +
      '"serverInfo":{"name":"rpgle-mcp-server","version":"0.1.0"}}';
  when methodName = 'ping';
    resultJson = '{}';
  when methodName = 'tools/list';
    // This registry builds the list from each tool's definition procedure.
    resultJson = listTools();
  when methodName = 'tools/call';
    // The generic MCP dispatcher does not change when a tool is added.
    resultJson = callRegisteredTool(toolName);
    if resultJson = '';
      sendHttp('200 OK': rpcError(idRaw: -32602: 'Unknown tool'): '');
      return;
    endif;
  other;
    sendHttp('200 OK': rpcError(idRaw: -32601: 'Method not found'): '');
    return;
  endsl;

  // Every successful request echoes its ID. The result is a JSON object,
  // assembled only from known literals or JSON produced by Db2 for i.
  sendHttp('200 OK': '{"jsonrpc":"2.0","id":' + idRaw +
           ',"result":' + resultJson + '}': '');
end-proc;

// TOOL REGISTRY: put each tool definition into the RPG array below.
// RPG array positions use parentheses: toolList(1), not toolList[1].
// The loop adds JSON commas, so adding a tool needs no JSON punctuation here.
dcl-proc listTools;
  dcl-pi *n varchar(8192);
  end-pi;
  dcl-s toolList varchar(512) dim(10);
  dcl-s toolCount int(10) inz(1);
  dcl-s toolIndex int(10);
  dcl-s listJson varchar(8192) inz('{"tools":[');
  dcl-s sysInfoTool varchar(512);
  // When getUserInfoTool() exists, declare this above the executable lines:
  // dcl-s userInfoTool varchar(512);

  // Tool 1: the only real tool in this lesson.
  sysInfoTool = getSysInfoTool();
  toolList(1) = sysInfoTool;

  // Example for a FUTURE tool; these lines stay commented until it exists.
  // Write getUserInfoTool() for metadata, runUserInfoTool() for execution,
  // and add its WHEN in callRegisteredTool() below before enabling these:
  // userInfoTool = getUserInfoTool();
  // toolList(2) = userInfoTool;
  // toolCount = 2;

  // Build a JSON array from registered entries; do not add commas above.
  for toolIndex = 1 to toolCount;
    if toolIndex > 1;
      listJson += ',';
    endif;
    listJson += %trim(toolList(toolIndex));
  endfor;
  return listJson + ']}';
end-proc;

// TOOL CALL ROUTER: only tool-specific names and handlers live here.
// Add one WHEN for each active entry in listTools; leave the HTTP/JSON-RPC
// procedures above unchanged. Empty means the requested tool is unknown.
dcl-proc callRegisteredTool;
  dcl-pi *n varchar(8192);
    requestedTool varchar(64) const;
  end-pi;
  dcl-s toolResult varchar(8192) inz('');

  select;
  when requestedTool = SYS_INFO_TOOL;
    toolResult = runSysInfoTool();
  // Future example: match the "name" returned by getUserInfoTool().
  // when requestedTool = 'get_user_info';
  //   toolResult = runUserInfoTool();
  endsl;
  return toolResult;
end-proc;

// TOOL DEFINITION: only the public MCP name, description and input schema.
// No Db2 query, CGI operation, or tool execution belongs in this procedure.
dcl-proc getSysInfoTool;
  dcl-pi *n varchar(512);
  end-pi;

  return '{"name":"' + SYS_INFO_TOOL + '",' +
    '"description":"Read IBM i OS and host identity from ' +
    'SYSIBMADM.ENV_SYS_INFO.",' +
    '"inputSchema":{"type":"object","properties":{},' +
    '"additionalProperties":false}}';
end-proc;

// TOOL HANDLER: translate the fixed read into a successful or failed MCP
// result. The caller cannot pass SQL, an object name, or another partition.
dcl-proc runSysInfoTool;
  dcl-pi *n varchar(8192);
  end-pi;
  dcl-s systemJson varchar(4096);

  systemJson = readSysInfo();
  if systemJson = '';
    // A tool failure is an MCP result with isError=true. Never return the
    // database error text or internal host details to the client.
    return '{"content":[{"type":"text",' +
      '"text":"System information is unavailable."}],' +
      '"isError":true}';
  endif;
  return asTextToolResult(systemJson);
end-proc;

// IBM i READ: this is the only procedure that queries system information.
// The SELECT is fixed in source and describes the local CGI partition.
dcl-proc readSysInfo;
  dcl-pi *n varchar(4096);
  end-pi;
  dcl-s systemJson varchar(4096) inz('');

  exec sql
    select json_object(
             'os_name' value os_name,
             'os_version' value os_version,
             'os_release' value os_release,
             'host_name' value host_name,
             'observed_at_local' value char(current_timestamp)
             returning varchar(4096))
      into :systemJson
      from sysibmadm.env_sys_info;
  if sqlcode <> 0;
    return '';
  endif;
  return %trim(systemJson);
end-proc;

// MCP RESULT FORMATTER: JSON_OBJECT escapes the JSON document as one text
// value, so quotation marks in IBM i data cannot corrupt the MCP envelope.
dcl-proc asTextToolResult;
  dcl-pi *n varchar(8192);
    systemJson varchar(4096) const;
  end-pi;
  dcl-s messageText varchar(4096);
  dcl-s contentJson varchar(8192);

  messageText = systemJson;
  exec sql
    values json_object('type' value 'text',
                       'text' value :messageText
                       returning varchar(8192))
      into :contentJson;
  if sqlcode <> 0;
    return '{"content":[{"type":"text",' +
      '"text":"Could not format system information."}],' +
      '"isError":true}';
  endif;
  return '{"content":[' + %trim(contentJson) +
    '],"isError":false}';
end-proc;

dcl-proc getEnv;
  dcl-pi *n varchar(1024);
    name varchar(64) const;
  end-pi;
  dcl-s receiver char(1024);
  dcl-s key char(64);
  dcl-s valueLength int(10);

  // QtmhGetEnv reports the returned byte length separately. Check it before
  // taking a substring; a missing or overlong variable is treated as absent.
  clear receiver;
  key = name;
  QtmhGetEnv(receiver: %len(receiver): valueLength:
             key: %len(name): apiError);
  if apiError.bytesAvailable > 0 or valueLength < 1 or
     valueLength > %len(receiver);
    return '';
  endif;
  return %trim(%subst(receiver: 1: valueLength));
end-proc;

dcl-proc rpcError;
  dcl-pi *n varchar(1024);
    requestId varchar(510) const;
    code int(10) const;
    message varchar(64) const;
  end-pi;
  // Only fixed messages from this program call rpcError. Never insert raw
  // request text into a JSON string without a JSON encoder.
  return '{"jsonrpc":"2.0","id":' + requestId +
         ',"error":{"code":' + %char(code) +
         ',"message":"' + message + '"}}';
end-proc;

dcl-proc sendHttp;
  dcl-pi *n;
    status varchar(64) const;
    body varchar(16384) const;
    extraHeader varchar(128) const;
  end-pi;
  dcl-s output char(32767);
  dcl-s outputLength int(10);
  dcl-s header varchar(512);

  // CGI needs a blank line between headers and body. The HTTP server then
  // converts the job's text to the network CCSID selected in its config.
  header = 'Status: ' + status + LF +
           'Content-Type: application/json; charset=utf-8' + LF +
           'Cache-Control: no-store' + LF;
  if extraHeader <> '';
    header += extraHeader + LF;
  endif;
  output = header + LF + body;
  outputLength = %len(header) + %len(LF) + %len(body);
  QtmhWrStout(output: outputLength: apiError);
end-proc;

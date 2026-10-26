**free
// Common CGI entry module. Each Apache instance invokes MCPHTTP and sets
// MCP_SERVER_ID to select exactly one server's registry.
// This file handles HTTP and JSON-RPC, never a tool-specific SQL query.
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);

// The CGI identity has read access to MCPSERVERS and per-server tool tables.
exec sql set option commit = *none, naming = *sql;

// IBM's RPG CGI example uses x'15' as the output line-feed character.
// MAX_BODY is also the advertised HTTP LimitRequestBody in the config file.
dcl-c LF x'15';
dcl-c MAX_BODY 16384;

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

// These procedures handle the transport and MCP request flow.
dcl-pr handleRequest;
end-pr;

dcl-pr readHttpRequest ind;
end-pr;

dcl-pr parseRpcRequest ind;
end-pr;

dcl-pr dispatchRpcRequest;
end-pr;

// MCPREG owns lookup and dynamic calls. Its routines are bound into this
// program; registering another handler never edits this CGI module.
dcl-pr resolveServer ind;
  serverId char(10) const;
  displayName varchar(64);
  toolTable char(10);
  maxLevel char(1);
end-pr;

dcl-pr listRegisteredTools varchar(8192);
  toolTable char(10) const;
  requestedCursor varchar(64) const;
end-pr;

dcl-pr callRegisteredTool varchar(8192);
  toolTable char(10) const;
  requestedTool varchar(64) const;
  argsJson varchar(8192) const;
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
// Tool modules receive no arbitrary SQL or caller-selected IBM i system.
// Embedded SQL needs a literal host-variable length at precompile time.
dcl-s requestJson varchar(16384);
dcl-s methodName varchar(64);
dcl-s rpcVersion varchar(16);
dcl-s clientVersion varchar(16);
dcl-s toolName varchar(64);
dcl-s listCursor varchar(64);
dcl-s idRaw varchar(510);
dcl-s argsJson varchar(8192);
dcl-s serverId char(10);
dcl-s displayName varchar(64);
dcl-s toolTable char(10);
dcl-s maxLevel char(1);
dcl-s isNotification ind inz(*off);

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
  dcl-s mcpVersion varchar(1024);
  dcl-s contentLength int(10);
  dcl-s bytesRead int(10);
  dcl-s rawInput char(MAX_BODY);

  // Streamable HTTP sends MCP messages by POST. GET would require a server
  // event stream, which this request-response sample does not implement.
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

  // This CGI implements the request/response subset shared by these two
  // protocol versions. Initialization may arrive without this header.
  mcpVersion = getEnv('HTTP_MCP_PROTOCOL_VERSION');
  if mcpVersion <> '' and mcpVersion <> '2025-11-25' and
     mcpVersion <> '2025-03-26';
    sendHttp('400 Bad Request': '': '');
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
  dcl-s hasId int(10);

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
           coalesce(json_value(:requestJson, '$.params.protocolVersion'
             returning varchar(16)), ''),
           coalesce(json_value(:requestJson, '$.method'
             returning varchar(64)), ''),
           coalesce(json_value(:requestJson, '$.params.name'
             returning varchar(64)), ''),
           coalesce(json_value(:requestJson, '$.params.cursor'
             returning varchar(64) null on empty error on error), ''),
           coalesce(json_query(:requestJson, '$.params.arguments'
             returning varchar(8192) null on empty error on error), '{}'),
           coalesce(json_query(:requestJson, '$.id'
             returning varchar(512) with unconditional array wrapper), '[]'),
           case when json_exists(:requestJson, '$.id') then 1 else 0 end
      into :rpcVersion, :clientVersion, :methodName, :toolName, :listCursor,
           :argsJson, :idWrapped, :hasId
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
  if rpcVersion <> '2.0';
    sendHttp('200 OK': rpcError('null': -32600: 'Invalid Request'): '');
    return *off;
  endif;
  if hasId = 0;
    if methodName = 'notifications/initialized';
      isNotification = *on;
      return *on;
    endif;
    // We do not implement other client notifications. Streamable HTTP
    // requires an HTTP error when a notification cannot be accepted.
    sendHttp('400 Bad Request': '': '');
    return *off;
  endif;
  if idRaw = 'null' or
     %check('"-0123456789': %subst(idRaw: 1: 1)) <> 0;
    sendHttp('200 OK': rpcError('null': -32600: 'Invalid Request'): '');
    return *off;
  endif;

  return *on;
end-proc;

dcl-proc dispatchRpcRequest;
  dcl-s resultJson varchar(16384);
  dcl-s envServer varchar(1024);
  dcl-s negotiatedVersion varchar(16);

  // SetEnv belongs in the server's Apache configuration. Do not use a
  // request header, query parameter, or tool argument to select a server.
  envServer = getEnv('MCP_SERVER_ID');
  if %len(envServer) < 1 or %len(envServer) > 10;
    sendHttp('503 Service Unavailable': '': '');
    return;
  endif;
  if %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_': envServer) <> 0 or
     %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ': %subst(envServer: 1: 1)) <> 0;
    sendHttp('503 Service Unavailable': '': '');
    return;
  endif;
  serverId = envServer;
  if not resolveServer(serverId: displayName: toolTable: maxLevel);
    sendHttp('503 Service Unavailable': '': '');
    return;
  endif;

  if isNotification;
    sendHttp('202 Accepted': '': '');
    return;
  endif;

  // MCP lifecycle first: initialize announces protocol and tools capability.
  // The client then sends notifications/initialized (handled above with 202).
  select;
  when methodName = 'initialize';
    if clientVersion = '';
      sendHttp('200 OK': rpcError(idRaw: -32602:
               'Missing protocol version'): '');
      return;
    endif;
    // Reply with the requested version when supported. Otherwise offer the
    // latest version we implement and let the client decide whether to stay.
    negotiatedVersion = '2025-11-25';
    if clientVersion = '2025-03-26';
      negotiatedVersion = clientVersion;
    endif;
    resultJson = '{"protocolVersion":"' + negotiatedVersion + '",' +
      '"capabilities":{"tools":{}},' +
      '"serverInfo":{"name":"' + %trim(serverId) +
      '","version":"0.3.0"}}';
  when methodName = 'ping';
    resultJson = '{}';
  when methodName = 'tools/list';
    resultJson = listRegisteredTools(toolTable: listCursor);
    if resultJson = '';
      sendHttp('200 OK': rpcError(idRaw: -32000:
               'Tool registry unavailable'): '');
      return;
    endif;
  when methodName = 'tools/call';
    // The generic MCP dispatcher does not change when a tool is added.
    resultJson = callRegisteredTool(toolTable: toolName: argsJson);
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
           'Content-Type: application/json' + LF +
           'Cache-Control: no-store' + LF;
  if extraHeader <> '';
    header += extraHeader + LF;
  endif;
  output = header + LF + body;
  outputLength = %len(header) + %len(LF) + %len(body);
  QtmhWrStout(output: outputLength: apiError);
end-proc;

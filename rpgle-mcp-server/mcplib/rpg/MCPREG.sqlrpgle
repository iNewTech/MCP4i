**free
// MCP registry for a single trusted server identity. No tool-specific SQL
// lives here. Each CGI request reads current metadata, so a newly published
// tool appears without rebuilding or restarting the CGI program.
ctl-opt nomain option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

/copy 'MCPABI.rpgleinc'

dcl-c TOOL_ERROR '{"content":[{"type":"text",' +
  '"text":"The tool could not complete the request."}],' +
  '"isError":true}';

// RPG resolves this name at call time. It is assembled from a reviewed
// registry row, never from params.arguments or a client-supplied program.
dcl-s targetProgram char(21);
dcl-pr invokeHandler extpgm(targetProgram);
  argsJson char(8192);
  resultJson char(8192);
  resultLen int(10);
  statusCode int(10);
end-pr;

dcl-pr asTextToolResult varchar(8192);
  payloadJson varchar(4096) const;
end-pr;

dcl-pr validObjectName ind;
  objectName char(10) const;
end-pr;

dcl-pr validToolTable ind;
  toolTable char(10) const;
end-pr;

// Only an active catalog row may choose a per-server tool table. The table
// token is checked again because SQL parameter markers cannot name tables.
dcl-proc resolveServer export;
  dcl-pi *n ind;
    serverId char(10) const;
    displayName varchar(64);
    toolTable char(10);
    maxLevel char(1);
  end-pi;

  clear displayName;
  clear toolTable;
  clear maxLevel;
  if not validObjectName(serverId);
    return *off;
  endif;

  exec sql
    select DISPNAME, TOOLFILE, MAXLVL
      into :displayName, :toolTable, :maxLevel
      from MCPLIB.MCPCAT
     where SRVID = :serverId and STATE = 'A';
  if sqlcode <> 0 or not validToolTable(toolTable);
    return *off;
  endif;
  return *on;
end-proc;

// Build one bounded MCP list from rows belonging to the selected server.
// Db2 quotes public text; the stored schema is appended as JSON only after
// syntax checking. We never silently omit tools if limits are exceeded.
dcl-proc listRegisteredTools export;
  dcl-pi *n varchar(8192);
    toolTable char(10) const;
  end-pi;
  dcl-s sqlText varchar(1024);
  dcl-s toolName varchar(64);
  dcl-s description varchar(256);
  dcl-s schemaJson varchar(2048);
  dcl-s baseJson varchar(1024);
  dcl-s resultJson varchar(8192) inz('{"tools":[');
  dcl-s toolCount int(10) inz(0);
  dcl-s validJson int(10);

  if not validToolTable(toolTable);
    return '';
  endif;
  sqlText = 'SELECT TOOLNAME, DESCR, SCHEMAJSON FROM MCPLIB.' +
            %trim(toolTable) +
            ' WHERE STATE = ''A'' AND TOOL_LVL = ''R''' +
            ' ORDER BY TOOLNAME';
  exec sql prepare listStmt from :sqlText;
  if sqlcode <> 0;
    return '';
  endif;
  exec sql declare listCur cursor for listStmt;
  exec sql open listCur;
  if sqlcode <> 0;
    return '';
  endif;

  dow *on;
    exec sql fetch listCur into :toolName, :description, :schemaJson;
    if sqlcode = 100;
      leave;
    endif;
    if sqlcode <> 0;
      exec sql close listCur;
      return '';
    endif;
    toolCount += 1;
    if toolCount > 20;
      exec sql close listCur;
      return '';
    endif;
    exec sql
      values case when :schemaJson is json object with unique keys
                  then 1 else 0 end into :validJson;
    if sqlcode <> 0 or validJson <> 1;
      exec sql close listCur;
      return '';
    endif;
    exec sql values json_object(
      'name' value :toolName,
      'description' value :description
      returning varchar(1024)) into :baseJson;
    if sqlcode <> 0;
      exec sql close listCur;
      return '';
    endif;
    // JSON_OBJECT supplied the closing }. Replace it with a nested object.
    baseJson = %trim(baseJson);
    if %len(resultJson) + %len(baseJson) +
       %len(%trim(schemaJson)) + 32 > 8192;
      exec sql close listCur;
      return '';
    endif;
    if toolCount > 1;
      resultJson += ',';
    endif;
    resultJson += %subst(baseJson: 1: %len(baseJson) - 1) +
                  ',"inputSchema":' + %trim(schemaJson) + '}';
  enddo;
  exec sql close listCur;
  if sqlcode <> 0;
    return '';
  endif;
  return resultJson + ']}';
end-proc;

// Lookup is scoped to one server's table and to published READ tools.
// A custom handler validates its advertised flat fields and business-level
// authorization. The generic server validates only the JSON envelope.
dcl-proc callRegisteredTool export;
  dcl-pi *n varchar(8192);
    toolTable char(10) const;
    requestedTool varchar(64) const;
    argsJson varchar(8192) const;
  end-pi;
  dcl-s sqlText varchar(1024);
  dcl-s handlerLib char(10);
  dcl-s handlerPgm char(10);
  dcl-s inputBuffer char(8192);
  dcl-s outputBuffer char(8192);
  dcl-s resultLen int(10);
  dcl-s statusCode int(10);
  dcl-s validJson int(10);
  dcl-s payloadJson varchar(4096);

  if not validToolTable(toolTable) or requestedTool = '';
    return '';
  endif;
  exec sql
    values case when :argsJson is json object with unique keys
                then 1 else 0 end into :validJson;
  if sqlcode <> 0 or validJson <> 1;
    return TOOL_ERROR;
  endif;

  sqlText = 'SELECT HDLLIB, HDLPGM FROM MCPLIB.' +
            %trim(toolTable) +
            ' WHERE TOOLNAME = ? AND STATE = ''A''' +
            ' AND TOOL_LVL = ''R''';
  exec sql prepare callStmt from :sqlText;
  if sqlcode <> 0;
    return TOOL_ERROR;
  endif;
  exec sql declare callCur cursor for callStmt;
  exec sql open callCur using :requestedTool;
  if sqlcode <> 0;
    return TOOL_ERROR;
  endif;
  exec sql fetch callCur into :handlerLib, :handlerPgm;
  if sqlcode = 100;
    exec sql close callCur;
    return '';
  endif;
  if sqlcode <> 0;
    exec sql close callCur;
    return TOOL_ERROR;
  endif;
  exec sql close callCur;
  if sqlcode <> 0 or not validObjectName(handlerLib) or
     not validObjectName(handlerPgm);
    return TOOL_ERROR;
  endif;

  // Four by-reference arguments are the only supported handler ABI.
  targetProgram = %trim(handlerLib) + '/' + %trim(handlerPgm);
  clear inputBuffer;
  clear outputBuffer;
  inputBuffer = argsJson;
  resultLen = 0;
  statusCode = 9;
  monitor;
    invokeHandler(inputBuffer: outputBuffer: resultLen: statusCode);
  on-error;
    return TOOL_ERROR;
  endmon;
  if statusCode <> 0 or resultLen < 1 or resultLen > 4096;
    return TOOL_ERROR;
  endif;
  payloadJson = %subst(outputBuffer: 1: resultLen);
  exec sql
    values case when :payloadJson is json object with unique keys
                then 1 else 0 end into :validJson;
  if sqlcode <> 0 or validJson <> 1;
    return TOOL_ERROR;
  endif;
  return asTextToolResult(payloadJson);
end-proc;

// Strictly validate identifiers before placing them in dynamic SQL or an
// EXTPGM target. The CGI never uses client text for either identifier.
dcl-proc validObjectName;
  dcl-pi *n ind;
    objectName char(10) const;
  end-pi;
  dcl-s name varchar(10);
  name = %trim(objectName);
  if name = '' or
     %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ': %subst(name: 1: 1)) <> 0 or
     %check('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_': name) <> 0;
    return *off;
  endif;
  return *on;
end-proc;

dcl-proc validToolTable;
  dcl-pi *n ind;
    toolTable char(10) const;
  end-pi;
  if %len(%trim(toolTable)) <> 8 or
     %subst(toolTable: 1: 1) <> 'T' or
     %check('0123456789': %subst(toolTable: 2: 7)) <> 0;
    return *off;
  endif;
  return *on;
end-proc;

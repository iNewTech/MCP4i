**free
// get_library_list returns the CGI request job's ordered library list.
// It does not inspect the MCP user's separate interactive job. The result
// is bounded, and truncated=true tells the client when entries were omitted.
ctl-opt nomain option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

dcl-c LIB_LIST_TOOL 'get_library_list';
dcl-c MAX_LIBRARIES 40;

dcl-pr asTextToolResult varchar(8192);
  payloadJson varchar(4096) const;
end-pr;

dcl-pr readLibList varchar(4096);
end-pr;

// Tool metadata is beside its handler, not in the transport module.
dcl-proc getLibListTool export;
  dcl-pi *n varchar(512);
  end-pi;

  return '{"name":"' + LIB_LIST_TOOL + '",' +
    '"description":"Read the current CGI job library list in order ' +
    'from QSYS2.LIBRARY_LIST_INFO; this is not the user job list.",' +
    '"inputSchema":{"type":"object","properties":{},' +
    '"additionalProperties":false}}';
end-proc;

dcl-proc runLibListTool export;
  dcl-pi *n varchar(8192);
  end-pi;
  dcl-s libraryJson varchar(4096);

  libraryJson = readLibList();
  if libraryJson = '';
    return '{"content":[{"type":"text",' +
      '"text":"Library list is unavailable."}],' +
      '"isError":true}';
  endif;
  return asTextToolResult(libraryJson);
end-proc;

// This fixed cursor reads at most 41 rows. Row 41 is only a signal that
// the first 40 are incomplete; it is never included in the response.
// JSON_OBJECT safely quotes each observed library name and list type.
dcl-proc readLibList;
  dcl-pi *n varchar(4096);
  end-pi;
  dcl-s ordinalPosition int(10);
  dcl-s libraryName varchar(10);
  dcl-s entryType varchar(15);
  dcl-s entryJson varchar(256);
  dcl-s libraryJson varchar(4096);
  dcl-s observedAt varchar(26);
  dcl-s returnedCount int(10) inz(0);
  dcl-s truncated ind inz(*off);
  dcl-s truncatedJson varchar(5) inz('false');

  exec sql declare libCursor cursor for
    select ordinal_position, system_schema_name, "TYPE"
      from qsys2.library_list_info
     order by ordinal_position;

  exec sql values char(current_timestamp) into :observedAt;
  if sqlcode <> 0;
    return '';
  endif;
  libraryJson = '{"scope":"current_cgi_job",' +
    '"observed_at_local":"' + %trim(observedAt) + '",' +
    '"libraries":[';

  exec sql open libCursor;
  if sqlcode <> 0;
    return '';
  endif;

  dow *on;
    exec sql fetch libCursor into :ordinalPosition, :libraryName,
      :entryType;
    if sqlcode = 100;
      leave;
    endif;
    if sqlcode <> 0;
      exec sql close libCursor;
      return '';
    endif;
    if returnedCount >= MAX_LIBRARIES;
      truncated = *on;
      leave;
    endif;

    exec sql values json_object(
      'position' value :ordinalPosition,
      'library' value :libraryName,
      'type' value :entryType
      returning varchar(256)) into :entryJson;
    if sqlcode <> 0;
      exec sql close libCursor;
      return '';
    endif;

    // Leave space for returned_count, truncated, and the closing braces.
    if %len(libraryJson) + %len(%trim(entryJson)) + 101 > 4096;
      truncated = *on;
      leave;
    endif;
    if returnedCount > 0;
      libraryJson += ',';
    endif;
    libraryJson += %trim(entryJson);
    returnedCount += 1;
  enddo;

  exec sql close libCursor;
  if sqlcode <> 0;
    return '';
  endif;
  if truncated;
    truncatedJson = 'true';
  endif;
  return libraryJson + '],"returned_count":' +
    %char(returnedCount) + ',"truncated":' + truncatedJson + '}';
end-proc;

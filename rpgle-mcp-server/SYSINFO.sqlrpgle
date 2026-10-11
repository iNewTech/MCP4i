**free
// The get_system_info tool lives in this separately compiled ILE module.
// It exposes two procedures to MCPHTTP: metadata and execution. Its SQL read
// stays private, so no other tool can supply a query or change the target.
ctl-opt nomain option(*srcstmt:*nodebugio);

exec sql set option commit = *none, naming = *sql;

dcl-c SYS_INFO_TOOL 'get_system_info';

// MCPJSON is a separately bound module. Keep this prototype identical to
// the exported procedure there; the binder resolves the call at CRTPGM.
dcl-pr asTextToolResult varchar(8192);
  payloadJson varchar(4096) const;
end-pr;

dcl-pr readSysInfo varchar(4096);
end-pr;

// The public MCP contract. Calling tools/list never runs the Db2 query.
dcl-proc getSysInfoTool export;
  dcl-pi *n varchar(512);
  end-pi;

  return '{"name":"' + SYS_INFO_TOOL + '",' +
    '"description":"Read IBM i OS and host identity from ' +
    'SYSIBMADM.ENV_SYS_INFO.",' +
    '"inputSchema":{"type":"object","properties":{},' +
    '"additionalProperties":false}}';
end-proc;

// The tool handler turns one fixed read into an MCP success or tool error.
dcl-proc runSysInfoTool export;
  dcl-pi *n varchar(8192);
  end-pi;
  dcl-s systemJson varchar(4096);

  systemJson = readSysInfo();
  if systemJson = '';
    // Keep database diagnostics and internal host details off the wire.
    return '{"content":[{"type":"text",' +
      '"text":"System information is unavailable."}],' +
      '"isError":true}';
  endif;
  return asTextToolResult(systemJson);
end-proc;

// IBM i read: this query describes the local partition, never a host named
// by the model. The timestamp records when this CGI request observed it.
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

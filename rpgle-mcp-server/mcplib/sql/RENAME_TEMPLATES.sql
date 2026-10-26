-- Rename the two shared templates in place on an existing installation.
-- Run after RENAME_SERVERS.sql, while MCP HTTP and 5250 administration
-- traffic is stopped. These tables are the source for new per-server files;
-- existing Snnnnnnn and Tnnnnnnn files are not renamed by this script.
-- Accept an old-only or new-only name for each table. Check both pairs
-- before changing either name so an ambiguous installation is left alone.
BEGIN
  DECLARE OLD_CONFIG_COUNT INTEGER DEFAULT 0;
  DECLARE NEW_CONFIG_COUNT INTEGER DEFAULT 0;
  DECLARE OLD_TOOL_COUNT INTEGER DEFAULT 0;
  DECLARE NEW_TOOL_COUNT INTEGER DEFAULT 0;

  SELECT COUNT(*) INTO OLD_CONFIG_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPCFGT'
     AND TABLE_TYPE = 'T';
  SELECT COUNT(*) INTO NEW_CONFIG_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPCFGTMPL'
     AND TABLE_TYPE = 'T';
  SELECT COUNT(*) INTO OLD_TOOL_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPTOOLT'
     AND TABLE_TYPE = 'T';
  SELECT COUNT(*) INTO NEW_TOOL_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPTOOLTPL'
     AND TABLE_TYPE = 'T';

  IF OLD_CONFIG_COUNT + NEW_CONFIG_COUNT <> 1 OR
     OLD_TOOL_COUNT + NEW_TOOL_COUNT <> 1 THEN
    SIGNAL SQLSTATE '75002'
      SET MESSAGE_TEXT = 'Expected one old/new name for each MCP template';
  END IF;

  IF OLD_CONFIG_COUNT = 1 THEN
    EXECUTE IMMEDIATE 'RENAME TABLE MCPLIB.MCPCFGT TO MCPCFGTMPL';
  END IF;
  IF OLD_TOOL_COUNT = 1 THEN
    EXECUTE IMMEDIATE 'RENAME TABLE MCPLIB.MCPTOOLT TO MCPTOOLTPL';
  END IF;
END;

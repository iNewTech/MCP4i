-- Add handler-generation metadata to an existing MCPLIB installation.
-- Run once before rebuilding MCPTOOLADD. This changes the empty MCPTOOLT
-- template and every registered server's Tnnnnnnn file in place; it does
-- not delete rows or change existing handlers. Re-running is safe.
-- IBM i 7.4/7.5 dynamic compound SQL is required by RUNSQLSTM.
BEGIN
  DECLARE REG_TABLE VARCHAR(10);
  DECLARE TARGET_CHECK VARCHAR(10);
  DECLARE DDL_TEXT VARCHAR(1024);

  FOR TOOL_TABLE AS TOOL_CURSOR CURSOR FOR
    SELECT 'MCPTOOLT' AS REG_NAME FROM SYSIBM.SYSDUMMY1
    UNION ALL
    SELECT TRIM(TOOLFILE) AS REG_NAME FROM MCPLIB.MCPSERVERS
  DO
    SET REG_TABLE = REG_NAME;
    IF REG_TABLE = 'MCPTOOLT' THEN
      SET TARGET_CHECK = 'GENTARGET';
    ELSE
      SET TARGET_CHECK = 'G' || SUBSTR(REG_TABLE, 2, 7);
    END IF;
    -- Quote the catalog value as one SQL identifier. Never let a damaged
    -- catalog row append SQL to an ALTER TABLE statement.
    IF NOT EXISTS (
      SELECT 1 FROM QSYS2.SYSCOLUMNS
       WHERE TABLE_SCHEMA = 'MCPLIB' AND TABLE_NAME = REG_TABLE
         AND COLUMN_NAME = 'GENMODE'
    ) THEN
      SET DDL_TEXT = 'ALTER TABLE MCPLIB."' ||
        REPLACE(REG_TABLE, '"', '""') ||
        '" ADD COLUMN GENMODE CHAR(1) NOT NULL DEFAULT ''M''' ||
        ' CHECK (GENMODE IN (''M'', ''G'', ''T''))';
      EXECUTE IMMEDIATE DDL_TEXT;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM QSYS2.SYSCOLUMNS
       WHERE TABLE_SCHEMA = 'MCPLIB' AND TABLE_NAME = REG_TABLE
         AND COLUMN_NAME = 'TGTLIB'
    ) THEN
      SET DDL_TEXT = 'ALTER TABLE MCPLIB."' ||
        REPLACE(REG_TABLE, '"', '""') ||
        '" ADD COLUMN TGTLIB CHAR(10) NOT NULL DEFAULT ''''';
      EXECUTE IMMEDIATE DDL_TEXT;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM QSYS2.SYSCOLUMNS
       WHERE TABLE_SCHEMA = 'MCPLIB' AND TABLE_NAME = REG_TABLE
         AND COLUMN_NAME = 'TGTPGM'
    ) THEN
      SET DDL_TEXT = 'ALTER TABLE MCPLIB."' ||
        REPLACE(REG_TABLE, '"', '""') ||
        '" ADD COLUMN TGTPGM CHAR(10) NOT NULL DEFAULT ''''';
      EXECUTE IMMEDIATE DDL_TEXT;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM QSYS2.SYSCST
       WHERE TABLE_SCHEMA = 'MCPLIB' AND TABLE_NAME = REG_TABLE
         AND CONSTRAINT_NAME = TARGET_CHECK
    ) THEN
      SET DDL_TEXT = 'ALTER TABLE MCPLIB."' ||
        REPLACE(REG_TABLE, '"', '""') ||
        '" ADD CONSTRAINT "' ||
        REPLACE(TARGET_CHECK, '"', '""') || '"' ||
        ' CHECK (GENMODE = ''M'' OR' ||
        ' (TGTLIB <> '''' AND TGTPGM <> ''''))';
      EXECUTE IMMEDIATE DDL_TEXT;
    END IF;
  END FOR;
END;

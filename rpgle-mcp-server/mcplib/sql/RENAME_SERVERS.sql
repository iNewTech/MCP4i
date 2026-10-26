-- Rename the shared server registry in place on an existing installation.
-- Run while HTTP and 5250 administration traffic is stopped, then rebuild
-- the RPG programs whose static SQL names this table. Rows and keys on
-- the table are preserved by RENAME TABLE.
-- Fresh installations already create MCPSERVERS and take the no-op path.
BEGIN
  DECLARE OLD_COUNT INTEGER DEFAULT 0;
  DECLARE NEW_COUNT INTEGER DEFAULT 0;

  SELECT COUNT(*) INTO OLD_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPCAT'
     AND TABLE_TYPE = 'T';
  SELECT COUNT(*) INTO NEW_COUNT
    FROM QSYS2.SYSTABLES
   WHERE TABLE_SCHEMA = 'MCPLIB'
     AND TABLE_NAME = 'MCPSERVERS'
     AND TABLE_TYPE = 'T';

  IF OLD_COUNT = 1 AND NEW_COUNT = 0 THEN
    EXECUTE IMMEDIATE 'RENAME TABLE MCPLIB.MCPCAT TO MCPSERVERS';
  ELSEIF OLD_COUNT = 0 AND NEW_COUNT = 1 THEN
    -- Re-running after a successful rename is safe.
    SET NEW_COUNT = 1;
  ELSE
    -- Both tables or neither table indicates an installation problem.
    -- Stop instead of selecting one or overwriting customer records.
    SIGNAL SQLSTATE '75001'
      SET MESSAGE_TEXT = 'Expected exactly one of MCPCAT or MCPSERVERS';
  END IF;
END;

"""Portable checks for the additive IBM i registry upgrade.

These checks cannot execute Db2 for i SQL; run the upgrade on a test
partition before applying it to an installed MCPLIB library.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class GenerationUpgradeContract(unittest.TestCase):
    def test_upgrade_covers_template_and_all_registered_server_tables(self):
        sql = (ROOT / "sql/UPGRADE_GENERATION.sql").read_text()
        self.assertIn("SELECT 'MCPTOOLT' AS REG_NAME", sql)
        self.assertIn("SELECT TRIM(TOOLFILE) AS REG_NAME FROM MCPLIB.MCPSERVERS", sql)
        for column in ("GENMODE", "TGTLIB", "TGTPGM"):
            self.assertIn(f"COLUMN_NAME = '{column}'", sql)
            self.assertIn(f"ADD COLUMN {column}", sql)
        self.assertIn("QSYS2.SYSCOLUMNS", sql)
        self.assertIn("QSYS2.SYSCST", sql)
        self.assertNotIn("DROP TABLE", sql.upper())
        self.assertNotIn("DELETE FROM", sql.upper())

    def test_catalog_rename_is_guarded_and_keeps_existing_rows(self):
        sql = (ROOT / "sql/RENAME_SERVERS.sql").read_text().upper()
        self.assertIn("FROM QSYS2.SYSTABLES", sql)
        self.assertIn("TABLE_NAME = 'MCPCAT'", sql)
        self.assertIn("TABLE_NAME = 'MCPSERVERS'", sql)
        self.assertIn("IF OLD_COUNT = 1 AND NEW_COUNT = 0", sql)
        self.assertIn("ELSEIF OLD_COUNT = 0 AND NEW_COUNT = 1", sql)
        self.assertIn("SIGNAL SQLSTATE", sql)
        self.assertIn("RENAME TABLE MCPLIB.MCPCAT TO MCPSERVERS", sql)
        for destructive_sql in ("DROP TABLE", "CREATE TABLE", "INSERT INTO", "DELETE FROM"):
            with self.subTest(statement=destructive_sql):
                self.assertNotIn(destructive_sql, sql)

    def test_generated_constraint_name_is_unique_per_server_table(self):
        create = (ROOT / "rpg/MCPSRVAD.sqlrpgle").read_text()
        upgrade = (ROOT / "sql/UPGRADE_GENERATION.sql").read_text()
        schema = (ROOT / "sql/SCHEMA.sql").read_text()
        self.assertIn("' ADD CONSTRAINT G' + %subst(toolFile:2:7)", create)
        self.assertIn("SET TARGET_CHECK = 'G' || SUBSTR(REG_TABLE, 2, 7)", upgrade)
        self.assertIn("CONSTRAINT GENTARGET CHECK", schema)
        self.assertIn("SET TARGET_CHECK = 'GENTARGET'", upgrade)


if __name__ == "__main__":
    unittest.main()

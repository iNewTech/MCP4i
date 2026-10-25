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
        self.assertIn("SELECT TRIM(TOOLFILE) AS REG_NAME FROM MCPLIB.MCPCAT", sql)
        for column in ("GENMODE", "TGTLIB", "TGTPGM"):
            self.assertIn(f"COLUMN_NAME = '{column}'", sql)
            self.assertIn(f"ADD COLUMN {column}", sql)
        self.assertIn("QSYS2.SYSCOLUMNS", sql)
        self.assertIn("QSYS2.SYSCST", sql)
        self.assertNotIn("DROP TABLE", sql.upper())
        self.assertNotIn("DELETE FROM", sql.upper())

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

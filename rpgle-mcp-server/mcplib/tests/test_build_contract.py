"""Check that the two IBM i build entry points preserve the same objects.

`make -n` checks the generated CL command order without running IBM i tools.
The actual compiler remains the acceptance gate on an IBM i partition.
"""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class BuildContract(unittest.TestCase):
    def test_rpg_copy_directory_reaches_compiler(self):
        makefile = (ROOT / "Makefile").read_text()
        driver = (ROOT / "cl" / "BLDMCPLIB.clle").read_text()
        self.assertIn("COMPILEOPT(", makefile)
        self.assertIn("COMPILEOPT(&RPGOPTS)", driver)

    def test_make_app_keeps_registry_rows_and_compiles_dependencies_first(self):
        output = subprocess.check_output(
            ["make", "-n", "-C", str(ROOT), "app"], text=True
        )
        self.assertNotIn("RUNSQLSTM", output)
        order = [
            "CRTDSPF FILE(MCPLIB/MCPSRVD)",
            "CRTDSPF FILE(MCPLIB/MCPTOOLD)",
            "CRTSQLRPGI OBJ(MCPLIB/MCPREG)",
            "CRTPGM PGM(MCPLIB/MCPHTTP)",
            "CRTCMD CMD(MCPLIB/CRTMCPSRV)",
        ]
        positions = [output.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))

    def test_schema_is_explicit_one_time_target(self):
        output = subprocess.check_output(
            ["make", "-n", "-C", str(ROOT), "schema"], text=True
        )
        self.assertIn("RUNSQLSTM SRCSTMF(", output)
        self.assertIn("SCHEMA.sql", output)

    def test_handler_target_builds_one_reviewed_wrapper_without_schema(self):
        output = subprocess.check_output(
            [
                "make", "-n", "-C", str(ROOT), "handler",
                "HANDLER_SRC=/home/user/mcplib/generated/MCPWRAP.sqlrpgle",
                "HANDLER_PGM=MCPWRAP",
                "HANDLER_LIB=TOOLS",
            ],
            text=True,
        )
        self.assertIn("CRTSQLRPGI OBJ(TOOLS/MCPWRAP)", output)
        self.assertIn("CRTPGM PGM(TOOLS/MCPWRAP)", output)
        self.assertNotIn("RUNSQLSTM", output)

    def test_existing_install_has_explicit_additive_upgrade(self):
        output = subprocess.check_output(
            ["make", "-n", "-C", str(ROOT), "upgrade-generation"],
            text=True,
        )
        self.assertIn("UPGRADE_GENERATION.sql", output)
        self.assertNotIn("SCHEMA.sql", output)
        driver = (ROOT / "cl" / "BLDMCPLIB.clle").read_text()
        self.assertIn("IF COND(&MODE *EQ 'UPGRADE')", driver)
        self.assertIn("'/sql/UPGRADE_GENERATION.sql'", driver)

    def test_cl_driver_compiles_same_commands_and_preserves_schema(self):
        source = (ROOT / "cl" / "BLDMCPLIB.clle").read_text()
        for command in (
            "CRTMCPSRV", "CHGMCPSRV", "STRMCPSRV", "ENDMCPSRV",
            "ADDMCPTOOL", "EDTMCPTOOL", "RMVMCPTOOL",
        ):
            with self.subTest(command=command):
                self.assertIn("CRTCMD CMD(MCPLIB/" + command + ")", source)
        self.assertIn("RUNSQLSTM", source)
        self.assertIn("IF COND(&MODE *EQ 'SCHEMA')", source)


if __name__ == "__main__":
    unittest.main()

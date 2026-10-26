"""Static contract checks until an IBM i partition can compile the RPG source.

These checks catch accidental loss of the server boundary or handler ABI.
They are not a substitute for compiler output or the live HTTP smoke test.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
RPG = ROOT / "rpg"


class RuntimeContract(unittest.TestCase):
    def test_copybook_starts_in_free_form(self):
        source = (ROOT / "copy" / "MCPABI.rpgleinc").read_text()
        self.assertTrue(source.startswith("**free\n"))

    def test_sql_host_buffer_has_literal_length_for_precompiler(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertIn("dcl-s requestJson varchar(16384)", source)

    def test_cgi_resolves_trusted_server_before_tool_dispatch(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertIn("getEnv('MCP_SERVER_ID')", source)
        self.assertIn("resolveServer", source)
        self.assertIn("listRegisteredTools", source)
        self.assertIn("callRegisteredTool", source)
        self.assertNotIn("toolList(1) =", source)
        self.assertNotIn("when requestedTool =", source)

    def test_registry_never_uses_client_text_as_program_or_table_name(self):
        source = (RPG / "MCPREG.sqlrpgle").read_text()
        self.assertIn("MCPLIB.MCPCAT", source)
        self.assertIn("TOOLFILE", source)
        self.assertIn("STATE = 'A'", source)
        self.assertIn("TOOL_LVL = ''R''", source)
        self.assertIn("extpgm(targetprogram)", source.lower())
        self.assertRegex(source, r"(?i)requestedTool\s+varchar\(64\)\s+const")

    def test_handler_programs_use_fixed_four_argument_abi(self):
        for name in ("SYSINFHND.sqlrpgle", "MCPLIBLIST.sqlrpgle"):
            with self.subTest(name=name):
                source = (RPG / name).read_text()
                self.assertRegex(source, r"(?i)argsJson\s+char\(8192\)")
                self.assertRegex(source, r"(?i)resultJson\s+char\(8192\)")
                self.assertRegex(source, r"(?i)resultLen\s+int\(10\)")
                self.assertRegex(source, r"(?i)statusCode\s+int\(10\)")

    def test_registry_checks_handler_length_and_json(self):
        source = (RPG / "MCPREG.sqlrpgle").read_text()
        self.assertRegex(source, r"(?i)resultLen\s*<\s*1")
        self.assertRegex(source, r"(?i)resultLen\s*>\s*4096")
        self.assertRegex(source, r"(?i)is json object with unique keys")

    def test_tool_listing_has_a_cursor_instead_of_a_global_tool_cap(self):
        cgi = (RPG / "MCPHTTP.sqlrpgle").read_text()
        registry = (RPG / "MCPREG.sqlrpgle").read_text()
        self.assertIn("$.params.cursor", cgi)
        self.assertIn("requestedCursor", registry)
        self.assertIn("nextCursor", registry)
        self.assertNotIn("toolCount > 20", registry)

    def test_tool_listing_separates_second_and_later_entries(self):
        registry = (RPG / "MCPREG.sqlrpgle").read_text()
        self.assertRegex(registry, r"if toolCount > 0;\s*resultJson \+= ',';")

    def test_argument_extraction_does_not_turn_errors_into_empty_object(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertRegex(
            source,
            r"(?is)json_query\(:requestJson, '\$\.params\.arguments'.*?error on error\)",
        )

    def test_text_result_reserves_room_for_mcp_envelope(self):
        source = (RPG / "MCPJSON.sqlrpgle").read_text()
        self.assertIn("returning varchar(8100)", source.lower())

    def test_http_protocol_version_and_notification_status(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertIn("getEnv('HTTP_MCP_PROTOCOL_VERSION')", source)
        self.assertIn("hasId", source)
        self.assertLess(source.index("if rpcVersion <> '2.0'"),
                        source.index("if hasId = 0"))
        self.assertIn("sendHttp('400 Bad Request': '': '')", source)

    def test_initialize_negotiates_supported_client_version(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertIn("$.params.protocolVersion", source)
        self.assertIn("clientVersion", source)
        self.assertIn("negotiatedVersion", source)
        self.assertIn("resultJson = '{\"protocolVersion\":\"' + negotiatedVersion", source)

    def test_cgi_json_content_type_allows_http_server_conversion(self):
        source = (RPG / "MCPHTTP.sqlrpgle").read_text()
        self.assertIn("'Content-Type: application/json'", source)
        self.assertNotIn("application/json; charset=utf-8", source)


if __name__ == "__main__":
    unittest.main()

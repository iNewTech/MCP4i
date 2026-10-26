"""Portable checks of the DDL contract; IBM i compilation remains required.

SQLite exercises the common CREATE TABLE/constraint subset, not Db2 semantics.
"""
from pathlib import Path
import re
import sqlite3
import unittest

SCHEMA = Path(__file__).resolve().parents[1] / 'sql' / 'SCHEMA.sql'


class SchemaContract(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCHEMA.is_file(), 'MCPLIB schema has not been implemented')
        self.source = re.sub(r'--[^\n]*', '', SCHEMA.read_text())
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.executescript(self.source.replace('MCPLIB.', ''))

    def server(self, **values):
        row = dict(SRVID='SERVER1', DISPNAME='First server', PORT=8080,
                   CFGFILE='S0000001', TOOLFILE='T0000001')
        row.update(values)
        self.db.execute(f"INSERT INTO MCPSERVERS ({','.join(row)}) VALUES ({','.join('?' for _ in row)})", tuple(row.values()))

    def tool(self, **values):
        row = dict(TOOLNAME='get_info', DESCR='Reviewed handler', HDLLIB='MCPLIB', HDLPGM='MCPINFO')
        row.update(values)
        self.db.execute(f"INSERT INTO MCPTOOLTPL ({','.join(row)}) VALUES ({','.join('?' for _ in row)})", tuple(row.values()))

    def test_system_identifiers_fit_ibm_i_and_templates_start_empty(self):
        tables = [row[0] for row in self.db.execute("SELECT name FROM sqlite_master WHERE type='table'")]
        self.assertEqual(set(tables), {'MCPSERVERS', 'MCPCFGTMPL', 'MCPTOOLTPL'})
        for table in tables:
            self.assertLessEqual(len(table), 10)
            for column in self.db.execute(f'PRAGMA table_info({table})'):
                self.assertLessEqual(len(column[1]), 10)
            self.assertEqual(self.db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0], 0)
        for column in ('SRVID', 'CFGFILE', 'TOOLFILE'):
            self.assertRegex(self.source, rf'\b{column}\s+CHAR\(10\)')

    def test_server_id_port_and_file_mappings_are_unique(self):
        self.server()
        for duplicate in ({'SRVID': 'SERVER1'}, {'PORT': 8080}, {'CFGFILE': 'S0000001'}, {'TOOLFILE': 'T0000001'}):
            with self.subTest(duplicate=duplicate), self.assertRaises(sqlite3.IntegrityError):
                self.server(**(dict(SRVID='SERVER2', PORT=8081, CFGFILE='S0000002', TOOLFILE='T0000002') | duplicate))
        self.server(SRVID='SERVER2', PORT=8081, CFGFILE='S0000002', TOOLFILE='T0000002')
        self.assertEqual(self.db.execute('SELECT CFGFILE, TOOLFILE FROM MCPSERVERS WHERE SRVID=?', ('SERVER2',)).fetchone(), ('S0000002', 'T0000002'))

    def test_server_defaults_to_draft_and_rejects_bad_states_and_ports(self):
        self.server()
        self.assertEqual(self.db.execute('SELECT STATE, MAXLVL FROM MCPSERVERS').fetchone(), ('D', 'R'))
        for column, value in [('STATE', 'Q'), ('MAXLVL', 'Q'), ('PORT', 0), ('PORT', 65536)]:
            with self.subTest(column=column, value=value), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f'UPDATE MCPSERVERS SET {column}=?', (value,))

    def test_only_read_tools_can_be_active(self):
        self.tool()
        self.assertEqual(self.db.execute('SELECT STATE, TOOL_LVL FROM MCPTOOLTPL').fetchone(), ('D', 'R'))
        for level in ('W', 'D'):
            self.db.execute('UPDATE MCPTOOLTPL SET TOOL_LVL=?', (level,))
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("UPDATE MCPTOOLTPL SET STATE='A'")
        self.db.execute("UPDATE MCPTOOLTPL SET TOOL_LVL='R', STATE='A'")
        self.db.execute("UPDATE MCPTOOLTPL SET STATE='X'")
        for column in ('STATE', 'TOOL_LVL'):
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f"UPDATE MCPTOOLTPL SET {column}='Q'")

    def test_flat_argument_metadata_round_trips_in_one_row(self):
        args = {}
        for number, kind in enumerate(('string', 'integer', 'boolean'), 1):
            args.update({f'ARG{number}NAME': f'field{number}', f'ARG{number}TYPE': kind, f'ARG{number}REQ': 'Y'})
        self.tool(**args, SCHEMAJSON='{"type":"object"}')
        self.assertEqual(self.db.execute('SELECT ARG1NAME, ARG2TYPE, ARG3REQ, SCHEMAJSON FROM MCPTOOLTPL').fetchone(), ('field1', 'integer', 'Y', '{"type":"object"}'))
        self.db.execute("UPDATE MCPTOOLTPL SET ARG1TYPE='number'")
        for column, value in [('ARG1TYPE', 'object'), ('ARG2REQ', 'Q')]:
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(f'UPDATE MCPTOOLTPL SET {column}=?', (value,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.tool()

    def test_config_is_single_row_per_generated_file(self):
        self.db.execute('INSERT INTO MCPCFGTMPL (CFGID) VALUES (1)')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO MCPCFGTMPL (CFGID) VALUES (2)')

    def test_setup_contains_no_registry_reset(self):
        self.assertNotRegex(self.source.upper(), r'\b(DROP|DELETE|TRUNCATE|REPLACE)\b')
        self.assertNotRegex(self.source.upper(), r'\bINSERT\b')


if __name__ == '__main__':
    unittest.main()

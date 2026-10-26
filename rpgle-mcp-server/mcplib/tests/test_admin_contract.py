"""Source contract checks only; IBM i compilation remains required."""
from pathlib import Path
import re
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AdminContract(unittest.TestCase):
    def source(self, path):
        p = ROOT / path
        self.assertTrue(p.exists(), f'Missing administration source: {path}')
        return p.read_text()

    def test_seven_commands_have_fixed_modes(self):
        for cmd, mode in [('CRTMCPSRV','C'),('CHGMCPSRV','E'),('STRMCPSRV','S'),
                          ('ENDMCPSRV','E'),('ADDMCPTOOL','A'),('EDTMCPTOOL','E'),('RMVMCPTOOL','X')]:
            with self.subTest(cmd=cmd):
                s = self.source(f'cmd/{cmd}.cmd')
                self.assertIn(f"CONSTANT('{mode}')", s)
                self.assertIn('KWD(SERVER)', s)
                self.assertIn('LEN(10)', s)

    def test_screens_and_programs_agree(self):
        for screen, program, record in [('MCPSRVD','MCPSRVAD','SRVREC'),('MCPTOOLD','MCPTOOLADD','TOOLREC')]:
            dds = self.source(f'dds/{screen}.dspf')
            rpg = self.source(f'rpg/{program}.sqlrpgle')
            self.assertIn(f'R {record}', dds)
            self.assertIn(f'dcl-f {screen}', rpg)
            self.assertIn(f'exfmt {record}', rpg)
            self.assertIn('CA03(03)', dds)
            self.assertIn('DSPSIZ(*DS4)', dds)
            self.assertIn(f"extfile('MCPLIB/{screen}')", rpg)

    def test_created_tables_restore_template_constraints(self):
        s = self.source('rpg/MCPSRVAD.sqlrpgle')
        for token in ['INCLUDING COLUMN DEFAULTS','PRIMARY KEY (CFGID)', 'CHECK (CFGID = 1 AND TIMEOUT BETWEEN',
                      'PRIMARY KEY (TOOLNAME)', "STATE <> ''A'' OR TOOL_LVL = ''R''", 'ARG3REQ',
                      'INSERT INTO MCPLIB.MCPSERVERS', 'DROP TABLE MCPLIB.', 'CRTBY', 'CHGBY']:
            self.assertIn(token, s)

    def test_tool_write_is_parameterized_and_soft_retire(self):
        s = self.source('rpg/MCPTOOLADD.sqlrpgle')
        self.assertIn("SET STATE = ''X''", s)
        self.assertNotIn('DELETE FROM', s)
        self.assertIn("TSTATE = 'A' and TLVL <> 'R'", s)
        self.assertIn('CHKOBJ OBJ(', s)
        self.assertIn('OBJTYPE(*PGM)', s)
        self.assertIn('json_object', s)
        self.assertIn('ARG3NAME', s)
        self.assertIn('execute saveStmt using', s)
        self.assertIn("%check('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'", s)
        self.assertIn("originalState = 'A' and TSTATE = 'A'", s)
        self.assertIn('schemaJson <> previousSchema', s)

    def test_http_wrapper_uses_instance_commands(self):
        s = self.source('rpg/MCPSRVOP.sqlrpgle')
        self.assertIn('STRTCPSVR SERVER(*HTTP)', s)
        self.assertIn('ENDTCPSVR SERVER(*HTTP)', s)
        self.assertIn('/www/', s)
        self.assertIn('Provision the IBM HTTP instance', s)
        self.assertNotIn('SBMJOB', s)


class AdminBounds(unittest.TestCase):
    def test_catalog_lock_is_not_held_during_screen_input(self):
        source = (ROOT / 'rpg/MCPSRVAD.sqlrpgle').read_text()
        self.assertLess(source.index('exfmt SRVREC'),
                        source.index("sqlText = 'ALCOBJ OBJ((MCPLIB/MCPSERVERS"))
        self.assertIn('dcl-s serial int(10)', source)
        self.assertIn('cfgMade = *off; toolMade = *off;', source)
        self.assertIn('CHAR(CHGTS)=:loadedTs', source)

    def test_tool_edit_uses_optimistic_version(self):
        source = (ROOT / 'rpg/MCPTOOLADD.sqlrpgle').read_text()
        self.assertIn('CHAR(CHGTS)=?', source)
        self.assertIn(':toolName, :loadedTs', source)

    def test_dds_lines_and_fields_fit_source_and_display(self):
        import re
        for name in ('MCPSRVD', 'MCPTOOLD'):
            source = (ROOT / f'dds/{name}.dspf').read_text()
            for number, line in enumerate(source.splitlines(), 1):
                with self.subTest(name=name, line=number):
                    self.assertLessEqual(len(line), 80)
                    field = re.search(r'\s(\d+)A\s+[BIO]\s+(\d+)\s+(\d+)', line)
                    if field:
                        width, column = int(field[1]), int(field[3])
                        self.assertLessEqual(column + width - 1, 132)

    def test_schema_total_is_checked_before_assignment(self):
        source = (ROOT / 'rpg/MCPTOOLADD.sqlrpgle').read_text()
        guard = '%len(properties) + %len(requiredList) + 80 > 2048'
        self.assertIn(guard, source)
        self.assertLess(source.index(guard), source.index("schemaJson = '{"))

    def test_dds_constants_do_not_overlap(self):
        import re
        for name in ('MCPSRVD', 'MCPTOOLD'):
            source = (ROOT / f'dds/{name}.dspf').read_text()
            occupied = set()
            for line in source.splitlines():
                match = re.search(r"\s(\d+)\s+(\d+)'([^']*)'", line)
                if match:
                    row, col, label = int(match[1]), int(match[2]), match[3]
                    for offset in range(len(label)):
                        cell = (row, col + offset)
                        self.assertNotIn(cell, occupied, f'{name}: overlapping label at {cell}')
                        occupied.add(cell)

class AdminDdsTypes(unittest.TestCase):
    def test_add_tool_screen_collects_public_name(self):
        import re
        command = (ROOT / 'cmd/ADDMCPTOOL.cmd').read_text()
        dds = (ROOT / 'dds/MCPTOOLD.dspf').read_text()
        program = (ROOT / 'rpg/MCPTOOLADD.sqlrpgle').read_text()
        self.assertRegex(command, r'(?s)KWD\(TOOL\).*?MIN\(0\)')
        self.assertRegex(dds, r'(?m)^.*\bTNAME\s+64A\s+B\s+2\s+20CHECK\(LC\)')
        self.assertIn('TNAME = toolName;', program)
        self.assertLess(program.index('exfmt TOOLREC'),
                        program.index('toolName = %trim(TNAME);'))
        self.assertIn("mode = 'E' and %trim(TNAME) <> toolName", program)

    def test_port_and_timeout_are_numeric_program_fields(self):
        lines = (ROOT / 'dds/MCPSRVD.dspf').read_text().splitlines()
        for field in ('SPORT', 'STIME'):
            line = next(line for line in lines if field in line and 'Y' in line)
            self.assertEqual(line[35:37], ' 0')

    def test_argument_types_accept_lowercase(self):
        lines = (ROOT / 'dds/MCPTOOLD.dspf').read_text().splitlines()
        for field in ('AT1', 'AT2', 'AT3'):
            line = next(line for line in lines if field in line and 'A  B' in line)
            self.assertIn('CHECK(LC)', line)


class GeneratedToolSchema(unittest.TestCase):
    def test_generated_modes_require_a_native_target(self):
        source = (ROOT / 'sql/SCHEMA.sql').read_text()
        ddl = re.sub(r'--[^\n]*', '', source).replace('MCPLIB.', '')
        db = sqlite3.connect(':memory:')
        self.addCleanup(db.close)
        db.executescript(ddl)
        insert = ('INSERT INTO MCPTOOLT '
                  '(TOOLNAME, DESCR, HDLLIB, HDLPGM, GENMODE, TGTLIB, TGTPGM) '
                  'VALUES (?, ?, ?, ?, ?, ?, ?)')
        base = ('lookup', 'Lookup', 'MCPLIB', 'WRAPPER')
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute(insert, (*base, 'G', '', ''))
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute(insert, (*base, 'T', 'APPLIB', ''))
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute(insert, (*base, 'Q', 'APPLIB', 'LOOKUP'))
        db.execute(insert, (*base, 'G', 'APPLIB', 'LOOKUP'))
        self.assertEqual(db.execute('SELECT STATE FROM MCPTOOLT').fetchone(),
                         ('D',))

if __name__ == '__main__':
    unittest.main()

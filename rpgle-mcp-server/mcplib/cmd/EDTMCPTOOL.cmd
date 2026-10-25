/* CPP: MCPLIB/MCPTOOAD; parameter order MODE, SERVER, TOOL */
             CMD        PROMPT('EDTMCPTOOL')
             PARM       KWD(MODE) TYPE(*CHAR) LEN(1) CONSTANT('E')
             PARM       KWD(SERVER) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Server system ID')
             PARM       KWD(TOOL) TYPE(*CHAR) LEN(64) MIN(1) +
                          CASE(*MIXED) PROMPT('Public tool name')

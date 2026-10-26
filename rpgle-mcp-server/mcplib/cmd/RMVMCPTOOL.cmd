/* CPP: MCPLIB/MCPTOOLADD; parameter order MODE, SERVER, TOOL */
             CMD        PROMPT('RMVMCPTOOL')
             PARM       KWD(MODE) TYPE(*CHAR) LEN(1) CONSTANT('X')
             PARM       KWD(SERVER) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Server system ID')
             PARM       KWD(TOOL) TYPE(*CHAR) LEN(64) MIN(1) +
                          CASE(*MIXED) PROMPT('Public tool name')

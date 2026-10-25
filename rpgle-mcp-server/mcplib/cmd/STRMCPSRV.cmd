/* CPP: MCPLIB/MCPSRVOP; parameter order MODE, SERVER */
             CMD        PROMPT('STRMCPSRV')
             PARM       KWD(MODE) TYPE(*CHAR) LEN(1) CONSTANT('S')
             PARM       KWD(SERVER) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Server system ID')

/* CPP: MCPLIB/MCPSRVAD; parameter order MODE, SERVER */
             CMD        PROMPT('CRTMCPSRV')
             PARM       KWD(MODE) TYPE(*CHAR) LEN(1) CONSTANT('C')
             PARM       KWD(SERVER) TYPE(*CHAR) LEN(10) MIN(1) +
                          PROMPT('Server system ID')

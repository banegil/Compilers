%{
    #include <stdio.h>
    #include <string.h>
    #include <stdlib.h>
    
    #include "sintactico.tab.h"
    
    #define YY_USER_ACTION \
        yylloc.first_line = prev_yylineno; \
        yylloc.first_column = yycolumn; \
        \
        if (yylineno != prev_yylineno) { \
            for (yycolumn = 1; yytext[yyleng - yycolumn] != '\n'; yycolumn++); \
            prev_yylineno = yylineno; \
        } else yycolumn += yyleng; \
        \
        yylloc.last_line = yylineno; \
        yylloc.last_column = yycolumn;
    
    int yycolumn = 1;
    int prev_yylineno = 1;
%}

%option yylineno

LETRA  [a-zA-Z]
DIGITO [0-9]

ID     {LETRA}({LETRA}|{DIGITO}|_)*
REAL   {DIGITO}+("."{DIGITO}+)?

COMMENT    "//".*

IF   "if"
THEN "then"
ELSE "else"

%%

"if"    return TOKEN_IF;
"then"  return TOKEN_THEN;
"else"  return TOKEN_ELSE;

"true"  return TOKEN_TRUE;
"false" return TOKEN_FALSE;

{ID}    {
            char *ptr = malloc(strlen(yytext) * sizeof(char));
            strcpy(ptr, yytext);
            
            yylval.id = ptr;
            return TOKEN_ID;
        }

{REAL}  {
            yylval.num = atof(yytext);
            return TOKEN_NUM;
        }

"=" return TOKEN_ASIG;
";" return TOKEN_PTOCOMA;
"," return TOKEN_COMA;
"+" return TOKEN_MAS;
"-" return TOKEN_MENOS;
"*" return TOKEN_MULT;
"/" return TOKEN_DIV;
"^" return TOKEN_POT;
"(" return TOKEN_PAA;
")" return TOKEN_PAC;

"{"     return TOKEN_BRO;
"}"     return TOKEN_BRC;

">="    return TOKEN_GE;


{COMMENT} ;
[[:space:]]+ ;

%%

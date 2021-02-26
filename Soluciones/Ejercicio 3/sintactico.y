%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <math.h>
    
    #include "table.h"
    
    #define NO_SPAN     (YYLTYPE){0}
    #define Id(n, span) (Ident){ (n), (span) }
    #define Num(n)      (Value){ NUM, .num=(n) }
    #define Func(fp, n) (Value){ FUNC, .func={ (n), (Fn)(fp) } }
    
    #define report_error(err...) \
        do { \
            sprintf(error, err); \
            yyerror(error); \
            YYABORT; \
        } while (0)
    
    #define report_id_error(string, id, self_span) \
        do { \
            char self_buf[128]; \
            span_content(self_span, self_buf, 128); \
            report_error(string "\n%s", id, self_span.first_line, self_buf); \
        } while (0)
    
    #define report_invalid_args_error(nargs, n, id, self_span) \
        do { \
            char self_buf[128]; \
            span_content(self_span, self_buf, 128); \
            report_error("'%s' in line %d takes %d arguments (%d given)\n%s", id, self_span.first_line, nargs, n, self_buf); \
        } while (0)
    
    #define report_undef_error(what, id, self_span) \
        report_id_error(what " '%s' in line %d is undefined", id, self_span)
    
    #define report_invalid_type_error(what, id, self_span) \
        report_id_error("'%s' in line %d is not a " what, id, self_span)
    
    #define function_call(n, ty, self, self_span, id, arg_list...) \
        Value v; \
        if (table_get(&t, id, &v, 0) == -1) \
            report_undef_error("function", id, self_span); \
        else if (v.type == FUNC) \
            if (v.func.nargs == (n)) \
                self = ((ty)v.func.fp)(arg_list); \
            else report_invalid_args_error(v.func.nargs, (n), id, self_span); \
        else report_invalid_type_error("function", id, self_span);
    
    extern int yylex(void);
    
    extern FILE *yyin;
    extern char *yytext;
    extern int yylineno;
    
    int yyerror(char *s);
    int span_content(YYLTYPE span, char *buf, int size);
    
    char error[512];
    Table t;
%}

%union {
    float num;
    int boolean;
    char *id;
}

%start entrada

%token <num> TOKEN_NUM
%token <id>  TOKEN_ID
%token       TOKEN_ASIG
%token       TOKEN_PTOCOMA
%token       TOKEN_COMA
%token       TOKEN_MAS
%token       TOKEN_MENOS
%token       TOKEN_MULT
%token       TOKEN_DIV
%token       TOKEN_POT
%token       TOKEN_PAA
%token       TOKEN_PAC

%token       TOKEN_IF
%token       TOKEN_THEN
%token       TOKEN_ELSE
%token       TOKEN_BRO
%token       TOKEN_BRC

%token       TOKEN_TRUE
%token       TOKEN_FALSE
%token       TOKEN_GE

%type <num> expresion

%type <num> id
%type <boolean> condicion

%left TOKEN_MAS   TOKEN_MENOS 
%left TOKEN_MULT  TOKEN_DIV
%left TOKEN_POT

%%

entrada : /* empty */
        | entrada calculadora
        ;

calculadora : if_expr
            | TOKEN_ID TOKEN_ASIG expresion TOKEN_PTOCOMA   {
                                                                if (table_insert(&t, Id($1, @1), Num($3), @$)) {
                                                                    char def_buf[128];
                                                                    char ident_buf[128];
                                                                    YYLTYPE span;
                                                                    table_get(&t, $1, 0, &span);
                                                                    
                                                                    span_content(@$, ident_buf, 128);
                                                                    span_content(span, def_buf, 128);
                                                                    report_error("redefinition of '%s' in line %d:\n%s\n\nnote: previous definition of '%s' was in line %d:\n%s\n",
                                                                        $1, @1.first_line, ident_buf,
                                                                        $1, span.first_line, def_buf
                                                                    );
                                                                }
                                                            }
            ;

if_expr :   TOKEN_IF TOKEN_PAA condicion TOKEN_PAC TOKEN_THEN TOKEN_BRO TOKEN_ID TOKEN_ASIG expresion TOKEN_PTOCOMA TOKEN_BRC
            TOKEN_ELSE TOKEN_BRO TOKEN_ID TOKEN_ASIG expresion TOKEN_PTOCOMA TOKEN_BRC  {
                                                                                            if ($3) {
                                                                                                table_insert(&t, Id($7, @7), Num($9), @$);
                                                                                            } else {
                                                                                                table_insert(&t, Id($14, @14), Num($16), @$);
                                                                                            }
                                                                                        }
        ;


condicion : TOKEN_TRUE  { $$ = 1; }
          | TOKEN_FALSE { $$ = 0; }
          | id TOKEN_GE expresion { $$ = $1 >= $3; }
          ;

id : TOKEN_ID   {
                    Value v;
                    if (table_get(&t, $1, &v, 0))
                        report_undef_error("number", $1, @$);
                    else if (v.type == NUM)
                        $$ = v.num;
                    else report_invalid_type_error("number", $1, @$);
                }
   ;

expresion : TOKEN_NUM                       { $$ = $1;      }
          | TOKEN_PAA expresion   TOKEN_PAC { $$ = $2;      }
          | expresion TOKEN_MAS   expresion { $$ = $1 + $3; }
          | expresion TOKEN_MENOS expresion { $$ = $1 - $3; }
          | expresion TOKEN_MULT  expresion { $$ = $1 * $3; }
          | expresion TOKEN_DIV   expresion { $$ = $1 / $3; }
          | expresion TOKEN_POT   expresion { $$ = powf($1, $3); }
          | id
          | TOKEN_ID TOKEN_PAA TOKEN_PAC                                { function_call(0, Fn,      $$, @$, $1);         }
          | TOKEN_ID TOKEN_PAA expresion TOKEN_PAC                      { function_call(1, Fn1Arg,  $$, @$, $1, $3);     }
          | TOKEN_ID TOKEN_PAA expresion TOKEN_COMA expresion TOKEN_PAC { function_call(2, Fn2Args, $$, @$, $1, $3, $5); }
          ;

%%

int span_content(YYLTYPE span, char *buf, int size) {
    int line = 1, c = 0, read = 0;
    char highlight[512], *h = highlight;
    
    fseek(yyin, 0, SEEK_SET);
    for (; line < span.first_line;)
        if (getc(yyin) == '\n')
            line++;
    
    for (int col = 1; line <= span.last_line && c != EOF; col++) {
        if ((c = getc(yyin)) == '\n')
            line++;
        
        *buf++ = (char)c;
        read++;
        
        if (col < span.first_column) {
            if (c == '\t')
                *h++ = '\t';
            else *h++ = ' ';
        } else if (col < span.last_column)
            *h++ = '^';
        read++;
    }
    
    *buf = 0;
    *h = 0;
    
    strcat(buf, highlight);
    
    return ++read;
}

int yyerror(char *s) {
    fprintf(stderr, "error (%d): %s\n", yylineno, s);
    printf("%s\n", yytext);
    
    return -1;
}

int yywrap() {
    return 1;
}

void print_values(Entry entry) {
    if (entry.value.type == NUM)
        printf("El valor del identificador '%s' es %g\n", entry.ident.sym, entry.value.num);
}

float log_base(float x, float base) {
    return logf(x) / logf(base);
}

int main(int argc, const char * argv[]) {
    yyin = argc > 1 ? fopen(argv[1], "r") : stdin;
    
    table_insert(&t, Id("cos",  NO_SPAN),  Func(&cosf,     1), NO_SPAN);
    table_insert(&t, Id("sen",  NO_SPAN),  Func(&sinf,     1), NO_SPAN);
    table_insert(&t, Id("sqrt", NO_SPAN),  Func(&sqrtf,    1), NO_SPAN);
    table_insert(&t, Id("log",  NO_SPAN),  Func(&log_base, 2), NO_SPAN);
    
    if (!yyparse())
        table_for_each(&t, &print_values);
    
    return 0;
}

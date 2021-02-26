#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "sintactico.tab.h"

#ifndef TABLE_H
#define TABLE_H

#ifndef TABLE_SIZE
#define TABLE_SIZE 64
#endif

typedef float (*Fn)();
typedef float (*Fn1Arg)(float);
typedef float (*Fn2Args)(float, float);

typedef enum {
    NUM, FUNC
} Type;

typedef struct {
    Type type;
    union {
        float num;
        struct {
            int nargs;
            Fn fp;
        } func;
    };
} Value;

typedef struct {
    char *sym;
    YYLTYPE span;
} Ident;

typedef struct {
    Ident ident;
    Value value;
    YYLTYPE span;
} Entry;

typedef struct {
    int length;
    Entry entries[TABLE_SIZE];
} Table;

int table_insert(Table *t, Ident ident, Value value, YYLTYPE span);

int table_get(Table *t, char *sym, Value *ret, YYLTYPE *span);

typedef void (*ForEachFn)(Entry);
int table_for_each(Table *t, ForEachFn f);

int table_debug_print(Table *t);

#endif

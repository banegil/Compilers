#include "table.h"

int table_get_index(Table *t, char *sym) {
    int i;
    
    for (i = 0; i < t->length; i++)
        if (!strcmp(t->entries[i].ident.sym, sym))
            return i;
    
    return -1;
}

int table_insert(Table *t, Ident ident, Value value, YYLTYPE span) {
    int idx = table_get_index(t, ident.sym);
    idx = idx == -1 ? t->length++ : idx;
    
    t->entries[idx].ident = ident;
    t->entries[idx].value = value;
    t->entries[idx].span = span;
    
    return 0;
}

int table_get(Table *t, char *sym, Value *ret, YYLTYPE *span) {
    int i;
    
    for (i = 0; i < t->length; i++)
        if (!strcmp(t->entries[i].ident.sym, sym)) {
            if (ret)
                *ret = t->entries[i].value;
            if (span)
                *span = t->entries[i].span;
            
            return 0;
        }
    
    return -1;
}

int table_for_each(Table *t, ForEachFn f) {
    int i;
    
    for (i = 0; i < t->length; i++)
        f(t->entries[i]);
}

int table_debug_print(Table *t) {
    int i;
    
    printf("Table data: [\n");
    for (i = 0; i < t->length; i++) {
        Value v = t->entries[i].value;
        
        printf("\t%s: ", t->entries[i].ident.sym);
        
        if (v.type == NUM)
            printf("%g", v.num);
        else printf("Function(%d) @ 0x%X", v.func.nargs, (unsigned)(long)v.func.fp);
        
        printf("\n");
    }
    printf("]\n");
}

grammar Compilador;

options {
    language     = Java;
    output       = AST;
    ASTLabelType = CommonTree;
}

@header {
    import java.util.ArrayList;
}

@members {
    int cnt = 0;
    int linea = 1;
    InstructionBuilder b = new InstructionBuilder();
    
    class MismatchedAssignmentException extends RecognitionException {
        int left, right;
        
        public MismatchedAssignmentException(IntStream in, int l, int r) {
            super(in);
            
            left = l;
            right = r;
        }
        
        public String getMessage() {
            return "Mismatched assignment ("
                    + left + " indentifier" + (left > 1 ? "s" : "") + ", "
                    + right + " value" + (right > 1 ? "s" : "") + ")";
        }
    }
    
    class Instruction {
        private String inst, p0, p1, p2;
        
        public Instruction(String instruction, String param0, String param1, String param2) {
            inst = instruction;
            p0 = param0 == null ? "NULL" : param0;
            p1 = param1 == null ? "NULL" : param1;
            p2 = param2 == null ? "NULL" : param2;
        }
        
        public String toString() {
            StringBuilder sb = new StringBuilder();
            
            sb.append("(");
            sb.append(inst).append(", ");
            sb.append(p0).append(", ");
            sb.append(p1).append(", ");
            sb.append(p2).append(")");
            
            return sb.toString();
        }
    }
    
    class InstructionBuilder {
        public Instruction ifInst(boolean type, String cond, int line) {
            return new Instruction(type ? "IF_TRUE" : "IF_FALSE", cond, "GOTO", "L" + line);
        }
    }
    
    class Code extends ArrayList<Instruction> {
        public String toString() {
            StringBuilder sb = new StringBuilder();
            
            int l = 0;
            for (Instruction i : this)
                sb.append("L").append(++l).append(" : ").append(i).append("\n");
            
            return sb.toString();
        }
    }
}

@rulecatch {
    catch (RecognitionException e) {
        reportError(e);
        System.exit(0);
    }
}

entrada returns [String codigo]
    :   programa EOF
            {
                $programa.instrucciones.add(new Instruction("HALT", null, null, null));
                
                $codigo = $programa.instrucciones.toString();
                
                System.out.print($codigo);
            }
    ;

programa returns [Code instrucciones]
    @init { $instrucciones = new Code(); }
    :   (ecuacion { $instrucciones.addAll($ecuacion.instrucciones); })*
    ;

ecuacion returns [Code instrucciones]
    @init { $instrucciones = new Code(); }
    : asignacion    { $instrucciones.addAll($asignacion.instrucciones); } ';'
    | ifexpr        { $instrucciones.addAll($ifexpr.instrucciones); }
    | whileloop     { $instrucciones.addAll($whileloop.instrucciones); }
    | forloop       { $instrucciones.addAll($forloop.instrucciones); }
    | switchexpr    { $instrucciones.addAll($switchexpr.instrucciones); }
    ;

asignacion returns [Code instrucciones]
    @init {
        $instrucciones = new Code();
        ArrayList<String> ids = new ArrayList<>();
        ArrayList<String> values = new ArrayList<>();
        Code inst = new Code();
    }
    : id1 = Id { ids.add($id1.text); } (',' idN = Id { ids.add($idN.text); })*
        '=' ex1 = expresion
            {
                inst.addAll($ex1.instrucciones);
                values.add($ex1.valor);
            }
        (',' exN = expresion
            {
                inst.addAll($exN.instrucciones);
                values.add($exN.valor);
            }
        )*
        {
            int left = ids.size();
            int right = values.size();
            if (left != right)
                throw new MismatchedAssignmentException(input, left, right);
            
            $instrucciones.addAll(inst);
            for (int i = 0; i < ids.size(); i++) {
                $instrucciones.add(new Instruction("ASSIGN", ids.get(i), values.get(i), null));
                linea++;
            }
        }
    ;

ifexpr returns [Code instrucciones]
    @init { $instrucciones = new Code(); }
    : 'if' '(' comparacion')' { int aux = linea; }
        'then' '{' { linea++; } p1 = programa '}'
            {
                $instrucciones.addAll($comparacion.instrucciones);
                $instrucciones.add(b.ifInst(false, $comparacion.valor, aux + $p1.instrucciones.size() + 2));
                
                $instrucciones.addAll($p1.instrucciones);
                
                aux += $p1.instrucciones.size() + 1;
            }
        'else' '{' { linea++; } p2 = programa '}'
            {
                $instrucciones.add(b.ifInst(true, null, aux + $p2.instrucciones.size() + 1));
                
                $instrucciones.addAll($p2.instrucciones);
            }
    ;

switchexpr returns [Code instrucciones]
    @init {
        $instrucciones = new Code();
        ArrayList<Code> cases = new ArrayList<>();
        String condition = null;
        Code block = new Code();
    }
    : 'switch' '(' ex1 = expresion { int aux = linea; } ')' '{'
        (
            { block.clear(); }
            (
                  'case' ex2 = expresion ':' { condition = $ex1.valor + "==" + $ex2.valor; }
                | 'default' ':' { condition = null; }
            ) { linea++; }
            (ecuacion { block.addAll($ecuacion.instrucciones); })*
            {
                aux += block.size() + 1;
                Code c = new Code();
                if (condition != null)
                    c.add(b.ifInst(false, condition, aux));
                c.addAll(block);
                cases.add(c);
            }
        )*
      '}'
        {
            for (int i = 0; i < cases.size(); i++) {
                $instrucciones.addAll(cases.get(i));
            }
        }
    ;

whileloop returns [Code instrucciones]
    @init { $instrucciones = new Code(); }
    : 'while' '(' comparacion ')' { int aux = linea; }
        'do' '{' { linea++; } programa '}'
            {
                $instrucciones.addAll($comparacion.instrucciones);
                $instrucciones.add(b.ifInst(false, $comparacion.valor, aux + $programa.instrucciones.size() + 2));
                
                $instrucciones.addAll($programa.instrucciones);
                
                $instrucciones.add(b.ifInst(true, null, aux));
                linea++;
            }
    ;

forloop returns [Code instrucciones]
    @init { $instrucciones = new Code(); }
    : 'for' '(' a1 = asignacion ';' comparacion ';' { int aux = linea; } a2 = asignacion { linea -= $a2.instrucciones.size(); } ')'
        'do' '{' { linea++; } programa '}'
            {
                $instrucciones.addAll($a1.instrucciones);
                
                $instrucciones.addAll($comparacion.instrucciones);
                $instrucciones.add(b.ifInst(false, $comparacion.valor, aux + $programa.instrucciones.size() + $a2.instrucciones.size() + 2));
                
                $instrucciones.addAll($programa.instrucciones);
                
                $instrucciones.addAll($a2.instrucciones);
                $instrucciones.add(b.ifInst(true, null, aux));
                linea += $a2.instrucciones.size() + 1;
            }
    ;

comparacion returns [Code instrucciones, String valor]
    @init { $instrucciones = new Code(); }
    : ex1 = expresion Comp ex2 = expresion { $valor = $ex1.text + $Comp.text + $ex2.text; }
    ;

expresion returns [Code instrucciones, String valor]
    @init {
        $instrucciones = new Code();
        String op = "";
    }
    : m1 = termino 
        {
            String aux = $m1.valor;
            
            $instrucciones.addAll($m1.instrucciones);
            $valor = $m1.valor;
        }
        (
            (
                  '+' m2 = termino  { op = "ADD"; }
                | '-' m2 = termino  { op = "SUB"; }
            ) {
                $valor = "t" + cnt++;
                
                $instrucciones.addAll($m2.instrucciones);
                $instrucciones.add(new Instruction(op, $valor, aux, $m2.valor));
                linea++;
                
                aux = $valor;
            }
        )*
    ;

termino returns [Code instrucciones, String valor]
    @init {
        $instrucciones = new Code();
        String op = "";
    }
    : m1 = factor 
        {
            String aux = $m1.valor;
            
            $instrucciones.addAll($m1.instrucciones);
            $valor = $m1.valor;
        }
        (
            (
                  '*' m2 = factor   { op = "MULT"; }
                | '/' m2 = factor   { op = "DIV"; }
            ) {
                $valor = "t" + cnt++;
                
                $instrucciones.addAll($m2.instrucciones);
                $instrucciones.add(new Instruction(op, $valor, aux, $m2.valor));
                linea++;
                
                aux = $valor;
            }
        )*
    ;

factor returns [Code instrucciones, String valor]
    : '(' expresion ')'
        {
            $instrucciones = $expresion.instrucciones;
            $valor = $expresion.valor;
        }
    | dato 
        {
            $instrucciones = $dato.instrucciones;
            $valor = $dato.valor;
        }
    ;

dato returns [Code instrucciones, String valor]
    @init { $instrucciones = new Code(); }
    : Number        { $valor = $Number.text; }
    | Id            { $valor = $Id.text; }
    | '-' Number    { $valor = "-" + $Number.text; }
    | '-' Id
        {
            $valor = "t" + cnt++;
            
            $instrucciones.add(new Instruction("NEG", $valor, $Id.text, null));
            linea++;
        }
    ;


Id     : ('a'..'z'|'A'..'Z')+;
Number : ('0'..'9')+ ('.' ('0'..'9')+)?;
Comp   : ('>' | '<' | '>=' | '<=' | '==' | '!=');

/* Ignoramos todos los caracteres de espacios en blanco. */

WS     : (' ' | '\t' | '\r'| '\n') { $channel = HIDDEN; };

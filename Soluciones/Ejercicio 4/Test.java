import org.antlr.runtime.*;
import java.io.*;

public class Test {
    public static void main(String[] args) throws Exception {
        File f = new File("pruebas.txt");
        
        ANTLRInputStream input = new ANTLRInputStream(new FileInputStream(f));
        CompiladorLexer lexer = new CompiladorLexer(input);
        CommonTokenStream tokens = new CommonTokenStream(lexer);
        CompiladorParser parser = new CompiladorParser(tokens);
        parser.entrada();
    }
}

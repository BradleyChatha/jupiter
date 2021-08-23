module jupiter.assembler.astprinter;

import jupiter.assembler, std.sumtype, std;

void printAst(AstNode*[] root)
{
    foreach(node; root)
        printNode(*node);
}

private void printNode(AstNode node)
{
    node.match!(
        (ParentLabelNode n)
        {
            writeln("ParentLabel: ", n.name);
            foreach(child; n.childLabels)
            {
                (*child).match!(
                    (ChildLabelNode c)
                    {
                        writeln("\tChild: ", c.name);
                    },
                    (_){ assert(false); }
                );
            }
        },
        (ChildLabelNode n)
        {
            writeln("ChildLabel: ", n.name);
        },
        (DirectiveNode n)
        {
            writeln("Directive: ", n.name);
            write("\tParams: ");
            foreach(exp; n.params)
                printExpression(exp);
            writeln();
        },
        (OpcodeNode n)
        {
            writeln("Opcode:");
            writeln("\tMneumonic: ", n.mneumonic);
            writeln("\tPrefix: ", n.prefix);
            writeln("\tSize: ", n.type);
            write("\tParams: ");
            foreach(exp; n.params)
                printExpression(exp);
            writeln();
        }
    );
}

private void printExpression(Expression exp)
{
    exp.match!(
        (StringExpression e) { writef("[string \"%s\"]", e.text); },
        (RegisterExpression e) { writef("[register %s]", e.reg); },
        (IdentifierExpression e) { writef("[identifier %s]", e.ident); },
        (NumberExpression e) { writef("[number as %s %s]", e.type, e.asInt); },
        (IndirectExpression e) { writef("[indirect %s %s %s]", e.targets, e.disps, e.scales); }
    );
    write(' ');
}
module jupiter.assembler.syntax2;

import std, jupiter.assembler;

// Forward referencing is a shitty nightmare so we're going the class route.

abstract class Syntax2Node
{
    Token token;
    LabelNode2[] labels;
}

abstract class LabelNode2 : Syntax2Node
{
    OpcodeNode2 opcode;
    string name;

    this(OpcodeNode2 opcode, string name) { this.opcode = opcode; this.name = name; }
}

final class ParentLabelNode2 : LabelNode2 
{
    this(OpcodeNode2 opcode, string name) { super(opcode, name); }
}
final class ChildLabelNode2 : LabelNode2 
{
    ParentLabelNode2 parent;
    this(OpcodeNode2 opcode, string name, ParentLabelNode2 parent) { this.parent = parent; super(opcode, name); }
}

abstract class DirectiveNode2 : Syntax2Node
{
}

final class SectionDirective2 : DirectiveNode2
{
    string name;
    this(string name){ this.name = name; }
}

final class ExternDirective2 : DirectiveNode2
{
    string name;
    this(string name){ this.name = name; }
}

final class GlobalDirective2 : DirectiveNode2
{
    string name;
    this(string name){ this.name = name; }
}

final class OpcodeNode2 : Syntax2Node
{
    OpcodeNode node;

    this(OpcodeNode node) { this.node = node; }
}

struct Syntax2Result
{
    Syntax2Node[] nodes;
}

Syntax2Result syntax2(AstNode*[] root)
{
    Syntax2Result ret;
    ParentLabelNode2 lastParentLabel;
    LabelNode2[] labelStack;

    foreach(n; root)
    {
        (*n).match!(
            (ParentLabelNode n)
            {
                lastParentLabel = new ParentLabelNode2(null, n.name);
                labelStack ~= lastParentLabel;
            },
            (ChildLabelNode n)
            {
                enforce(lastParentLabel, formatTokenLocation(n.tok)~"Cannot have a child label without a parent.");
                auto label = new ChildLabelNode2(null, n.name, lastParentLabel);
                labelStack ~= label;
            },
            (OpcodeNode n)
            {
                auto opcode = new OpcodeNode2(n);
                ret.nodes ~= opcode;
                if(labelStack.length)
                {
                    opcode.labels = labelStack;
                    labelStack.length = 0;
                }
            },
            (DirectiveNode n)
            {
                switch(n.name)
                {
                    case "global": ret.nodes ~= new GlobalDirective2(expectSingleIdentifier(n.tok, n.params)); break;
                    case "extern": ret.nodes ~= new ExternDirective2(expectSingleIdentifier(n.tok, n.params)); break;
                    case "section": ret.nodes ~= new SectionDirective2(expectSingleIdentifier(n.tok, n.params)); break;

                    default: throw new Exception(formatTokenLocation(n.tok)~"Unknown directive: "~n.name);
                }
            },
        );
    }

    return ret;
}

private string expectSingleIdentifier(Token tok, Expression[] exp)
{
    enforce(exp.length == 1, formatTokenLocation(tok)~"Expected only a single value, not "~exp.length.to!string);

    string ret;
    exp[0].match!(
        (IdentifierExpression exp) { ret = exp.ident; },
        (_) { throw new Exception(formatTokenLocation(tok)~"Expected value to be an identifier, not: "~_.to!string); }
    );
    return ret;
}
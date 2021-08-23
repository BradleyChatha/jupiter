module jupiter.assembler.syntax2;

import std, jupiter.assembler;

// Forward referencing is a shitty nightmare so we're going the class route.

abstract class Syntax2Node
{
    Token token;
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
    LabelNode2[string] labels;
}

Syntax2Result syntax2(AstNode*[] root)
{
    Syntax2Result ret;
    ParentLabelNode2 lastParentLabel;
    LabelNode2 lastLabel;

    foreach(n; root)
    {
        (*n).match!(
            (ParentLabelNode n)
            {
                enforce(!lastLabel, formatTokenLocation(n.tok)~"Cannot have two labels reference the same instruction.");
                lastParentLabel = new ParentLabelNode2(null, n.name);
                lastLabel = lastParentLabel;
                ret.labels[n.name] = lastParentLabel;
            },
            (ChildLabelNode n)
            {
                enforce(lastParentLabel, formatTokenLocation(n.tok)~"Cannot have a child label without a parent.");
                enforce(!lastLabel, formatTokenLocation(n.tok)~"Cannot have two labels reference the same instruction.");
                lastLabel = new ChildLabelNode2(null, n.name, lastParentLabel);
                ret.labels[lastParentLabel.name~"."~n.name] = lastLabel;
            },
            (OpcodeNode n)
            {
                ret.nodes ~= new OpcodeNode2(n);
                if(lastLabel)
                {
                    lastLabel.opcode = cast(OpcodeNode2)ret.nodes[$-1];
                    lastLabel = null;
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
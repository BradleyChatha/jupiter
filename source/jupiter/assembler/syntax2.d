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
    MneumonicHigh mneumonic;
    Prefix prefix;
    SizeType type;
    ExpressionNode2[] params;

    this(OpcodeNode node) 
    { 
        this.mneumonic = node.mneumonic;
        this.prefix = node.prefix;
        this.type = node.type;

        enforce(node.params.length <= 3, "Opcodes(at least, the ones supported by Jupiter) only support up to 3 operands.");
        this.params = syntax2Expressions(node.params);
    }
}

abstract class ExpressionNode2
{
    Token token;
}

final class StringExpression2 : ExpressionNode2
{
    string value;
    this(string value) { this.value = value; }
}

final class IntegerExpression2: ExpressionNode2
{
    long value;
    this(long value) { this.value = value; }
}

final class UnsignedIntegerExpression2 : ExpressionNode2
{
    ulong value;
    this(ulong value) { this.value = value; }
}

final class FloatingExpression2 : ExpressionNode2
{
    double value;
    this(double value) { this.value = value; }
}

final class RegisterExpression2 : ExpressionNode2
{
    Register value;
    this(Register value) { this.value = value; }
}

final class IdentifierExpression2 : ExpressionNode2
{
    string value;
    this(string value) { this.value = value; }
}

final class IndirectExpression2 : ExpressionNode2
{
    ExpressionNode2 target;
    ExpressionNode2 scale;
    ExpressionNode2 disp;
    RegisterExpression2 index;

    this(ExpressionNode2 target, ExpressionNode2 scale, ExpressionNode2 disp, RegisterExpression2 index)
    {
        this.target = target;
        this.scale = scale;
        this.disp = disp;
        this.index = index;
    }
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

ExpressionNode2[] syntax2Expressions(Expression[] expressions)
{
    ExpressionNode2[] ret;

    ExpressionNode2 asNode2_compound(CompoundExpression exp)
    {
        return null;
    }

    ExpressionNode2 asNode2(Expression exp)
    {
        typeof(return) ret;
        exp.match!(
            (StringExpression str){ ret = new StringExpression2(str.str); },
            (NumberExpression num)
            {
                ret = new IntegerExpression2(num.asInt);
            },
            (RegisterExpression reg) { ret = new RegisterExpression2(reg.reg); },
            (IdentifierExpression ident) { ret = new IdentifierExpression2(ident.ident); },
            (IndirectExpression indirect)
            {
                ret = new IndirectExpression2(
                    asNode2(indirect.target),
                    indirect.disps.length ? asNode2_compound(indirect.disp) : null,
                    indirect.scales.length ? asNode2_compound(indirect.scale) : null,
                    indirect.indexs.length ? cast(RegisterExpression2)asNode2(indirect.index) : null,
                );
            }
        );

        return ret;
    }

    foreach(exp; expressions)
        ret ~= asNode2(exp);

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
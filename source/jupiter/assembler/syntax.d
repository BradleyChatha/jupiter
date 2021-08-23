module jupiter.assembler.syntax;

import std, jupiter.assembler;
import std.sumtype : This, match;

alias AstNode = SumType!(
    ParentLabelNode,
    ChildLabelNode,
    DirectiveNode,
    OpcodeNode
);

struct ParentLabelNode
{
    Token tok;
    string name;
    AstNode*[] childLabels;
}

struct ChildLabelNode
{
    Token tok;
    string name;
}

struct DirectiveNode
{
    Token tok;
    string name;
    Expression[] params;
}

struct OpcodeNode
{
    Token tok;
    MneumonicHigh mneumonic;
    Prefix prefix;
    SizeType type;
    Expression[] params;
}

alias Expression = SumType!(
    StringExpression,
    NumberExpression,
    RegisterExpression,
    IdentifierExpression,
    IndirectExpression
);

enum ExpressionSize = 80;
// static assert(ExpressionSize == Expression.sizeof);

struct CompoundExpression
{
    enum Type
    {
        constant
    }

    // Have to avoid forward references.
    // Imagine if D would grow some balls and put this shit into the language itself
    // instead of bending over to template satan itself.
    ubyte[ExpressionSize] _1;
    ubyte[ExpressionSize] _2;

    @property @trusted nothrow pure:

    ref Expression left() return
    {
        return *(cast(Expression*)(cast(void*)_1.ptr));
    }

    ref Expression right() return
    {
        return *(cast(Expression*)(cast(void*)_2.ptr));
    }
}

struct StringExpression
{
    Token tok;
    string str;
}

struct NumberExpression
{
    Token tok;
    SizeType type;
    union
    {
        long asInt;
    }
}

struct RegisterExpression
{
    Token tok;
    Register reg;
}

struct IdentifierExpression
{
    Token tok;
    string ident;
}

struct IndirectExpression
{
    Expression[] targets; // Stored as arrays otherwise forward-reference-chan will come eat me.
    CompoundExpression[] disps;
    CompoundExpression[] scales;

    @property @safe nothrow pure:

    ref Expression target()
    {
        if(!this.targets.length)
            this.targets.length = 1;
        return this.targets[0];
    }

    ref CompoundExpression disp()
    {
        if(!this.disps.length)
            this.disps.length = 1;
        return this.disps[0];
    }

    ref CompoundExpression scale()
    {
        if(!this.scales.length)
            this.scales.length = 1;
        return this.scales[0];
    }
}

/*
TopLevelNode:
    Label
    Directive
    Opcode

Label:
    Token.Label Token.Space?-> (NewLine|Opcode|Directive) // Case Opcode & Directive: don't consume token

Directive:
    Token.Directive Token.Space?-> (Expression Comma?)*

Opcode:
    Token.Mneumonic Token.Space Token.Prefix? Token.Space (Expression Comma?)* NewLine

Expression:
    StringExpression 
    NumberExpression
    RegisterExpression
    IdentifierExpression
    IndirectExpression

StringExpression:
    Token.String

NumberExpression:
    Token.Number

RegisterExpression:
    Token.Register

IdentifierExpression:
    Token.Identifier

IndirectExpression:
    [Expression]
    [Expression + Expression]
    [Expression + Expression * Expression]
    // Constant folding is not accounted for in the grammar. Non-identifier and non-register expressions can be of the form (1 + 38 * 3124 / 1239) etc, but then constant folded.
*/
struct Parser
{
    private
    {
        AstNode*[] _root;
        AstNode* _parentLabel;
    }

    this(Lexer lexer)
    {
        this.parse(lexer);
    }

    @property @safe @nogc
    inout(AstNode*[]) root() nothrow pure inout
    {
        return this._root;
    }

    private void parse(Lexer lexer)
    {

        While: while(!lexer.empty)
        {
            AstNode* toAdd;
            switch(lexer.front.type) with(Token.Type)
            {
                case directive:
                    auto node = DirectiveNode(lexer.front, lexer.front.slice[1..$]);
                    this.ensureWhitespace(lexer, "following directive.");
                    node.params = this.parseExpressionList(lexer, "for directive.");
                    toAdd = new AstNode(node);
                    break;

                case label:
                    if(lexer.front.slice[0] == '.')
                    {
                        enforce(this._parentLabel, 
                            formatTokenLocation(lexer.front)
                            ~"Unexpected child label that is not under a parent label. Labels starting with a '.' can only be children."
                        );
                        toAdd = new AstNode(ChildLabelNode(lexer.front, lexer.front.slice));
                        match!(
                            (ref ParentLabelNode l)
                            {
                                l.childLabels ~= toAdd;
                            },
                            (_) { assert(false); }
                        )(*this._parentLabel);
                    }
                    else
                    {
                        toAdd = new AstNode(ParentLabelNode(lexer.front, lexer.front.slice));
                        this._parentLabel = toAdd;
                    }
                    lexer.popFront();
                    break;

                case mneumonic:
                    auto node = OpcodeNode(lexer.front, g_highMneumonics[lexer.front.slice]);
                    const wasNewLine = this.ensureWhitespace(lexer, "following mneumonic while looking for prefix, new line, EOF, or first operand.");
                    if(wasNewLine)
                    {
                        toAdd = new AstNode(node);
                        break;
                    }
                    if(lexer.front.type == prefix)
                    {
                        node.prefix = lexer.front.slice.to!Prefix;
                        this.ensureWhitespace(lexer, "for mneumonic prefix "~node.prefix.to!string);
                    }
                    if(lexer.front.type == sizeType)
                    {
                        node.type = g_sizeTypes[lexer.front.slice];
                        this.ensureWhitespace(lexer, "for mneumonic size type "~node.type.to!string);
                    }
                    node.params = this.parseExpressionList(lexer, "for mneumonic "~node.mneumonic.to!string, node.type);
                    toAdd = new AstNode(node);
                    break;

                case newline:
                case whitespace:
                    lexer.popFront(); // Not all things care about whitespace suffixes, so this simply catches that.
                    continue While;
                    
                case eof:
                    lexer.popFront(); // Make the range empty.
                    continue While;

                default: throw new Exception("TODO: "~lexer.front.to!string);
            }

            assert(toAdd);
            this._root ~= toAdd;
        }
    }

    private Expression[] parseExpressionList(ref Lexer lexer, string ctxMsg, SizeType size = SizeType.infer)
    {
        Expression[] ret;
        while(lexer.front.type != Token.Type.newline && lexer.front.type != Token.Type.eof)
        {
            while(lexer.front.type == Token.Type.whitespace)
                lexer.popFront();
            ret ~= this.parseExpression(lexer, ctxMsg, size);
            lexer.popFront();
            while(lexer.front.type == Token.Type.whitespace)
                lexer.popFront();
            if(lexer.front.type == Token.Type.newline || lexer.front.type == Token.Type.eof)
            {
                lexer.popFront();
                break;
            }
            else if(lexer.front.type == Token.Type.comma)
                lexer.popFront();
            else
            {
                throw new Exception("%sUnexpected token %s when parsing expression list %s - expected comma, new line, or EOF.".format(
                    formatTokenLocation(lexer.front),
                    lexer.front,
                    ctxMsg
                ));
            }
        }

        return ret;
    }

    private Expression parseExpression(ref Lexer lexer, string ctxMsg, SizeType size)
    {
        Expression ret;
        switch(lexer.front.type) with(Token.Type)
        {
            case identifier: ret = Expression(IdentifierExpression(lexer.front, lexer.front.slice)); break;
            case str: ret = Expression(StringExpression(lexer.front, lexer.front.slice)); break;
            case register: ret = Expression(RegisterExpression(lexer.front, g_registers[lexer.front.slice])); break;

            case number:
                bool isInt = true; // TODO
                if(isInt)
                {
                    const value = this.parseInt(lexer.front.slice);
                    ret = Expression(NumberExpression(lexer.front, size, value));
                }
                else assert(false, "TODO");
                break;

            case lsquare:
                auto exp = IndirectExpression();
                lexer.popFront();
                if(lexer.front.type == Token.Type.whitespace) 
                    lexer.popFront();

                switch(lexer.front.type)
                {
                    case identifier:
                    case register:
                        exp.targets ~= this.parseExpression(lexer, ctxMsg, size);
                        break;
                        
                    default: throw new Exception("%sToken %s is an invalid target for dereference.".format(
                        formatTokenLocation(lexer.front),
                        lexer.front
                    ));
                }

                auto copy = lexer;
                copy.popFront();
                if(copy.front.type == rsquare)
                {
                    lexer = copy;
                    ret = exp;
                    break;
                }

                // TODO, DISP AND SCALE

                ret = exp;
                break;

            default: throw new Exception(
                "%sUnexpected token %s when parsing expression list %s".format(
                    formatTokenLocation(lexer.front),
                    lexer.front,
                    ctxMsg
                )
            );
        }
        return ret;
    }

    private bool ensureWhitespace(ref Lexer lexer, string addMsg)
    {
        lexer.popFront();
        if(lexer.front.type == Token.Type.newline || lexer.front.type == Token.Type.eof)
            return true;
        enforce(
            lexer.front.type == Token.Type.whitespace
         || lexer.front.type == Token.Type.newline, 
            formatTokenLocation(lexer.front)~"Expected either a space or a new line "~addMsg~" - but got "~lexer.front.to!string
        );
        lexer.popFront();
        return false;
    }

    private long parseInt(string text)
    {
        if(text.startsWith("0x"))
            return text[2..$].to!long(16);
        else if(text.startsWith("0b"))
            return text[2..$].to!long(2);
        else
            return text.to!long();
    }
}

string formatTokenLocation(Token tok)
{
    return "[line %s col %s] ".format(tok.range.start, tok.range.end); // TODO: Turn this into line + col.
}
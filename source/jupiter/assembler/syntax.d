module jupiter.assembler.syntax;

import std, jupiter.assembler;

private mixin template Common()
{
    Token token;
}

struct LabelNode
{
    mixin Common;
}
struct OpNode
{
    mixin Common;
    Mneumonic mneumonic;
    SizeType opSize = SizeType.infer;
    SizeType addrSize = SizeType.infer;
    Expression*[] args;
}
struct DirectiveNode
{
    mixin Common;
    Expression*[] args;
}
alias Node = SumType!(LabelNode, OpNode, DirectiveNode);

struct StringValue
{
    mixin Common;
}
struct LabelValue
{
    mixin Common;
}
struct NumberValue
{
    mixin Common;
}
struct RegisterValue
{
    mixin Common;
    Register reg;
}
struct IndirectExpression
{
    mixin Common;
    Expression* exp;
}
alias Value = SumType!(StringValue, LabelValue, NumberValue, RegisterValue, IndirectExpression);

struct Expression
{
    enum Kind
    {
        FAILSAFE,
        add,
        sub,
        mul,
        div,
        mod,
        value
    }

    Kind kind;
    Token token;
    union
    {
        struct {
            Expression* left;
            Expression* right;
        }

        Value value;
    }

    this(Kind kind, Expression* left, Expression* right)
    {
        this.kind = kind;
        this.left = left;
        this.right = right;
    }

    this(Value value)
    {
        this.kind = Kind.value;
        this.value = value;
    }

    void eachValue(scope void delegate(const Value) handler) const
    {
        if(this.kind == Kind.value)
            handler(this.value);
        else
        {
            if(this.left) this.left.eachValue(handler);
            if(this.right) this.right.eachValue(handler);
        }
    }

    void eachExpression(scope void delegate(const(Expression)*) handler) const
    {
        if(this.kind == Kind.value)
            return;
        handler(&this);
        if(this.left)
            this.left.eachExpression(handler);
        if(this.right)
            this.right.eachExpression(handler);
    }
}

Node[] syntax1(string input, string fileName)
{
    Node[] nodes;
    auto lexer = Lexer(input, fileName);

    while(lexer.front.type != Token.Type.eof)
    {
        final switch(lexer.front.type) with(Token.Type)
        {
            case FAILSAFE:  assert(false, "Hit a failsafe");    
            
            case whitespace:
            case eof:       
            case newline: 
                lexer.popFront(); 
                break;

            case label: nodes ~= Node(LabelNode(lexer.front)); lexer.popFront(); break;
            case directive:
                const nameToken = lexer.front;
                lexer.popFront();
                nodes ~= Node(DirectiveNode(nameToken, nextExpressionList(lexer)));
                break;
            case mneumonic: 
                auto nameToken = lexer.front;
                lexer.popFront();
                if(lexer.front.type == Token.Type.whitespace)
                    lexer.popFront();

                auto node = OpNode();

                While: while(!lexer.empty)
                {
                    switch(lexer.front.type)
                    {
                        case sizeType:
                            if(lexer.front.slice.endsWith("ptr"))
                                node.addrSize = g_sizeTypes[lexer.front.slice];
                            else
                                node.opSize = g_sizeTypes[lexer.front.slice];
                            lexer.popFront();
                            break;
                        case whitespace:
                            lexer.popFront();
                            break;
                        default: break While;
                    }
                }

                auto args = nextExpressionList(lexer);
                node.token = nameToken;
                node.mneumonic = g_highMneumonics[nameToken.slice];
                node.args = args;
                nodes ~= Node(node);
                break;
            
            case lcurly:
            case rcurly:
            case plus:
            case minus:
            case star:
            case fslash:
            case number:    
            case identifier:
            case str:       
            case register:  
            case prefix:    
            case sizeType:  
            case comma:     
            case lsquare:   
            case rsquare:   
            case junk:      
                throw new Exception(format!"Unexpected token. Expecting directive, mneumonic, or label definition.\n%s"(
                    lexer.front
                ));
        }
    }

    return nodes;
}

string expectLabel(const Expression* exp)
{
    string ret;
    enforce(exp.kind == Expression.Kind.value, "Expected a label value, not a complex expression.");
    exp.value.match!(
        (const LabelValue v) { ret = v.token.slice; },
        (_) { throw new Exception("Expected a label value, not %s.\n%s".format(typeof(_).stringof, _.token)); }
    );

    return ret;
}

private:

Expression* nextExpression(ref Lexer lexer)
{
    if(lexer.front.type == Token.Type.lsquare)
    {
        lexer.popFront();
        auto exp = nextExpression(lexer);
        enforce(lexer.front.type == Token.Type.rsquare, "Expected ']' to close indirect expression.\n%s".format(lexer.front));
        lexer.popFront();
        return new Expression(Value(IndirectExpression(lexer.front, exp)));
    }

    struct Op
    {
        size_t precedence;
        Token token;
    }

    Token[] values;
    Op[] operators;

    while(true) with(Token.Type)
    {
        if(lexer.empty)
            break;

        const t = lexer.front.type;
        size_t precedence;
        if(t == plus)
            precedence = 12;
        else if(t == star)
            precedence = 13;
        else if(t == minus)
            precedence = 11;
        else if(t == fslash)
            precedence = 14;
        else if(t == lcurly || t == rcurly)
            precedence = 10;
        else if(t == str || t == identifier || t == number || t == register)
        {
            values ~= lexer.front;
        }
        else if(t != whitespace)
            break;
        
        if(precedence != 0)
        {
            if(t == rcurly)
            {
                while(true)
                {
                    if(!operators.length)
                        throw new Exception("Unmatched ')' when parsing complex expression.%s".format(lexer.front));

                    const op = operators[$-1];
                    operators.length--;
                    if(op.token.type == lcurly)
                        break;
                }
            }
            else
            {
                while(operators.length && operators[$-1].precedence > precedence)
                {
                    values ~= operators[$-1].token;
                    operators.length--;
                }
                operators ~= Op(precedence, lexer.front);
            }
        }
        lexer.popFront();
    }
    foreach(op; operators.retro)
        values ~= op.token;

    if(values.length == 1 && operators.length == 0)
    {
        switch(values[0].type) with(Token.Type)
        {
            case str:
                return new Expression(Value(StringValue(values[0])));
            case identifier:
                return new Expression(Value(LabelValue(values[0])));
            case number:
                return new Expression(Value(NumberValue(values[0])));
            case register:
                return new Expression(Value(RegisterValue(values[0], g_registers[values[0].slice])));

            default: throw new Exception(format!"Cannot form token into an expression.\n%s"(values[0]));
        }
    }

    Expression*[] valueStack;
    foreach(v; values)
    {
        switch(v.type) with(Token.Type)
        {
            case str:
                valueStack ~= new Expression(Value(StringValue(v)));
                break;
            case identifier:
                valueStack ~= new Expression(Value(LabelValue(v)));
                break;
            case number:
                valueStack ~= new Expression(Value(NumberValue(v)));
                break;
            case register:
                valueStack ~= new Expression(Value(RegisterValue(v, g_registers[v.slice])));
                break;

            case plus:
            case minus:
            case star:
            case fslash:
                enforce(valueStack.length >= 2, "Unbalanced expression, more operators than there are values. %s".format(v));
                auto left = valueStack[$-2];
                auto right = valueStack[$-1];
                valueStack.length -= 2;
                valueStack ~= new Expression(
                    v.type == plus
                    ? Expression.Kind.add
                        : v.type == minus
                        ? Expression.Kind.sub
                            : v.type == star
                            ? Expression.Kind.mul
                                : Expression.Kind.div, 
                    left, 
                    right
                );
                break;

            default: assert(false);
        }
    }
    enforce(valueStack.length == 1, "Expected one value left on evaluation stack.%s".format(lexer.front));
    return valueStack[0];
}

Expression*[] nextExpressionList(ref Lexer lexer)
{
    Expression*[] ret;

    while(!lexer.empty)
    {
        switch(lexer.front.type) with(Token.Type)
        {
            case whitespace:
                lexer.popFront();
                break;

            case lsquare:
            case register:
            case number:
            case identifier:
            case str:
                ret ~= nextExpression(lexer);

                while(lexer.front.type == whitespace)
                    lexer.popFront();
                if(lexer.front.type != comma && lexer.front.type != newline && lexer.front.type != eof)
                {
                    throw new Exception("Expected comma or end of line/file following expression in expression list. %s".format(
                        lexer.front
                    ));
                }
                if(lexer.front.type != newline)
                    lexer.popFront();
                break;

            case eof:
            case newline:
                lexer.popFront();
                return ret;

            default: throw new Exception("Unexpected token while parsing expression list.\n%s".format(
                lexer.front
            ));
        }
    }

    return ret;
}
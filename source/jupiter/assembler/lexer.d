module jupiter.assembler.lexer;

import std;
import jupiter.assembler;

struct TextRange
{
    size_t start;
    size_t end;
}

/++
Tokens:
    Token[]

Token:
    Directive
    Mneumonic
    Prefix
    Register
    Identifier
    Space
    Label
    Number
    String
    NewLine
    Comma
    SizeType
    LSquare
    RSquare

Space:
    ' '

Directive:
    @Identifier

Mneumonic:
    defined in info.d

Register:
    defined in info.d

Prefix:
    defined in info.d

SizeType:
    defined in info.d

Identifier:
    [._a-zA-Z][_a-zA-Z]+

Label:
    Identifier:

Number:
    -? NumPrefix? 0-F+.?0-F? NumSuffix?

NumPrefix:
    0x
    0b

NumSuffix:
    i[0-9]+
    u[0-9]+

String:
    ".+"
    '.+'
    `.+`

NewLine:
    \n

Comma:
    ,

LSquare:
    [

RSquare:
    ]
++/

struct Token
{
    static enum Type
    {
        FAILSAFE,
        identifier,
        directive,
        mneumonic,
        label,
        number,
        str,
        register,
        prefix,
        newline,
        sizeType,
        whitespace,
        comma,
        lsquare,
        rsquare,
        junk,
        eof,
    }

    Type type;
    string slice;
    TextRange range;
}

struct Lexer
{
    private
    {
        string _input;
        size_t _cursor;
        Token _front;
        bool _empty;
    }

    this(string input)
    {
        this._input = input;
        this.popFront();
    }

    Token front()
    {
        return this._front;
    }

    bool empty()
    {
        return this._empty;
    }

    void popFront()
    {
        if(this.front.type == Token.Type.eof)
        {
            this._empty = true;
            return;
        }
        if(this.eof)
        {
            this._front.type = Token.Type.eof;
            return;
        }

        const ch = this.peek();
        
        if(ch == '\n')
        {
            this._front = Token(Token.Type.newline, "\n", TextRange(this._cursor, ++this._cursor));
            return;
        }
        else if(ch.isStringChar)
        {
            const start = ++this._cursor;
            while(!this.eof && this.peek() != ch)
                this._cursor++;
            if(this.eof)
            {
                this.popFront();
                return;
            }

            const end = this._cursor++;
            this._front = Token(Token.Type.str, this._input[start..end], TextRange(start, end));
            return;
        }
        else if(ch.isNumberChar)
        {
            const start = this._cursor++;
            while(!this.eof && this.peek().isMidNumberChar)
                this._cursor++;
            
            if(!this.eof && !this.peek().isNumSuffixChar)
                goto EndNumber;

            while(!this.eof && this.peek().isDigit)
                this._cursor++;

            EndNumber:
            const end = this._cursor;
            this._front = Token(Token.Type.number, this._input[start..end], TextRange(start, end));
            return;
        }
        else if(ch.isIdentStart)
        {
            const start = this._cursor++;
            while(!this.eof && this.peek().isIdentChar)
                this._cursor++;
            auto end = this._cursor;
            auto type = Token.Type.identifier;
            if(this._input[start] == '@')
                type = Token.Type.directive;
            else if(!this.eof && this._input[end] == ':')
            {
                end++;
                this._cursor++;
                type = Token.Type.label;
            }

            this._front = Token(type, this._input[start..end], TextRange(start, end));
            if(type == Token.Type.identifier)
            {
                if(this._front.slice in g_highMneumonics)
                    this._front.type = Token.Type.mneumonic;
                else if(this._front.slice in g_registers)
                    this._front.type = Token.Type.register;
                else if(this._front.slice in g_sizeTypes)
                    this._front.type = Token.Type.sizeType;
                else
                {
                    static foreach(prefix; __traits(allMembers, Prefix))
                    {
                        if(this.front.slice == prefix)
                            this._front.type = Token.Type.prefix;
                    }
                }
            }
            else if(type == Token.Type.label)
                this._front.slice = this._front.slice[0..$-1]; // Remove ':'
            return;
        }
        else if(ch == ' ')
        {
            const start = this._cursor;
            while(!this.eof && this.peek() == ' ')
                this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.whitespace, this._input[start..end], TextRange(start, end));
            return;
        }
        else if(ch == ',') // DRY, what's that??
        {
            const start = this._cursor;
            while(!this.eof && this.peek() == ',')
                this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.comma, this._input[start..end], TextRange(start, end));
            return;
        }
        else if(ch == '[')
        {
            const start = this._cursor;
            while(!this.eof && this.peek() == '[')
                this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.lsquare, this._input[start..end], TextRange(start, end));
            return;
        }
        else if(ch == ']')
        {
            const start = this._cursor;
            while(!this.eof && this.peek() == ']')
                this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.rsquare, this._input[start..end], TextRange(start, end));
            return;
        }
        else
            this._front = Token(Token.Type.junk, this._input[this._cursor..this._cursor+1], TextRange(this._cursor, ++this._cursor));
    }

    private char peek()
    {
        return this._input[this._cursor];
    }

    private bool eof()
    {
        return this._cursor >= this._input.length;
    }
}

private bool isIdentStart(char ch)
{
    switch(ch)
    {
        case 'a':..case 'z':
        case 'A':..case 'Z':
        case '_':
        case '.':
        case '@':
            return true;

        default: return false;
    }
}

private bool isIdentChar(char ch)
{
    switch(ch)
    {
        case 'a':..case 'z':
        case 'A':..case 'Z':
        case '0':..case '9':
        case '_':
        case '.':
            return true;

        default: return false;
    }
}

private bool isStringChar(char ch)
{
    switch(ch)
    {
        case '"':
        case '\'':
        case '`':
            return true;
        default: return false;
    }
}

private bool isNumberChar(char ch)
{
    switch(ch)
    {
        case '0':..case '9':
        case '-':
            return true;
        default: return false;
    }
}

private bool isMidNumberChar(char ch)
{
    switch(ch)
    {
        case '0':..case '9':
        case 'A':..case 'F':
        case '.':
        case 'x':
        case 'b':
            return true;
        default: return false;
    }
}

private bool isNumSuffixChar(char ch)
{
    switch(ch)
    {
        case 'i':
        case 'u':
            return true;
        default: return false;
    }
}

private bool isDigit(char ch)
{
    switch(ch)
    {
        case '0':..case '9':
            return true;
        default: return false;
    }
}
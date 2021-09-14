module jupiter.assembler.lexer;

import std;
import jupiter.assembler;

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
    [0-9]+i
    [0-9]+u

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

struct TextRange
{
    string file;
    size_t fileStart;

    string input;
    size_t start;
    size_t end;
}

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
        lcurly,
        rcurly,
        plus,
        minus,
        star,
        fslash,
        junk,
        eof,
    }

    Type type;
    TextRange range;

    string slice() const
    {
        return this.range.input[this.range.start..this.range.end];
    }

    string toString() const
    {
        Appender!(char[]) output;
        size_t lines  = 1;
        size_t column = 1;
        size_t lastLineStart = this.range.fileStart;
        size_t lineEnd;
        foreach(i, ch; this.range.input[this.range.fileStart..this.range.end])
        {
            column++;
            if(ch == '\n')
            {
                lastLineStart = this.range.fileStart + i + 1;
                lines++;
                column = 1;
            }
        }
        foreach(i, ch; this.range.input[this.range.end..$])
        {
            if(ch == '\n')
            {
                lineEnd = this.range.end + i;
                break;
            }
        }
        if(lineEnd == 0)
            lineEnd = this.range.end;

        output.put("[%s token in %s at line %s column %s]\n".format(this.type, this.range.file, lines, column));
        output.put("\t> ");
        output.put(this.range.input[lastLineStart..this.range.end]);
        output.put(this.range.input[this.range.end..lineEnd]);
        output.put("\n\t> ");

        if(lastLineStart < this.range.start && this.range.end >= this.range.start)
        {
            foreach(i; lastLineStart..this.range.start)
                output.put(' ');
            output.put('^'.repeat.take(this.range.end-this.range.start).array);
        }

        return output.data.assumeUnique;
    }
}

struct Lexer
{
    private
    {
        string  _input;
        size_t  _cursor;
        Token   _front;
        bool    _empty;
        string  _file;
        size_t  _fileStart;
    }

    this(string input, string fileName)
    {
        this._input = input;
        this._file = fileName;
        this._fileStart = 0;
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

        if(ch == '#' && (this._front.type == Token.Type.newline || this._front == Token.init))
        {
            const start = ++this._cursor;
            while(this._cursor < this._input.length && this.peek() != '\n')
                this._cursor++;
                
            auto end = this._cursor;
            if(this._input[end-1] == '\r')
                end--;

            this._file = this._input[start..end];
            this._fileStart = this._cursor;

            this.popFront();
            return;
        }
        
        if(ch == '\n')
        {
            this._front = Token(Token.Type.newline, TextRange(this._file, this._fileStart, this._input, this._cursor, ++this._cursor));
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
            this._front = Token(Token.Type.str, TextRange(this._file, this._fileStart, this._input, start, end));
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
            this._front = Token(Token.Type.number, TextRange(this._file, this._fileStart, this._input, start, end));
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

            this._front = Token(type, TextRange(this._file, this._fileStart, this._input, start, end));
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
                this._front.range.end--; // Remove ':'
            return;
        }
        else if(ch == ' ')
        {
            const start = this._cursor;
            while(!this.eof && this.peek() == ' ')
                this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.whitespace, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == ',') // DRY, what's that??
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.comma, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '[')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.lsquare, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == ']')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.rsquare, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '(')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.lcurly, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == ')')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.rcurly, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '+')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.plus, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '-')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.minus, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '*')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.star, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else if(ch == '/')
        {
            const start = this._cursor++;
            const end = this._cursor;
            this._front = Token(Token.Type.fslash, TextRange(this._file, this._fileStart, this._input, start, end));
            return;
        }
        else
            this._front = Token(Token.Type.junk, TextRange(this._file, this._fileStart, this._input, this._cursor, ++this._cursor));
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
module jupiter.assembler.preprocessor;

import std, jupiter.assembler, lumars;

string preprocess(string file)
{
    if(!isAbsolute(file))
        file = absolutePath(file).buildNormalizedPath;

    Appender!(char[]) code;
    Appender!(char[]) pass1Output;
    Appender!(char[]) pass2Output;

    code.put("defines = {}\n");

    bool[string] alreadyIncluded;
    handleIncludes(null, file, alreadyIncluded, pass1Output);
    handleCommands(pass1Output.data.assumeUnique, code);

    auto lua = LuaState(null);
    lua.globalTable["put"] = (string s) { pass2Output.put(s); };
    lua.globalTable["define"] = (){};
    lua.doString(code.data);

    return pass2Output.data.assumeUnique;
}

private void handleIncludes(string parentFile, string file, ref bool[string] alreadyIncluded, ref Appender!(char[]) output)
{
    const dir = dirName(parentFile);
    if(!isAbsolute(file))
        file = absolutePath(file, dir).buildNormalizedPath;
    const input = readText(file);

    output.put("\n#");
    output.put(file);
    output.put('\n');
    size_t plainTextStart = 0;
    for(size_t cursor = 0; cursor < input.length; cursor++)
    {
        void restOfLine()
        {
            while(cursor < input.length && input[cursor] != '\n')   
                cursor++;
        }

        void readToSpace()
        {
            while(cursor < input.length && input[cursor] != ' ')
                cursor++;
        }

        void skipSpaces()
        {
            while(cursor < input.length && input[cursor] == ' ')
                cursor++;
        }

        if(input[cursor] != '%')
        {
            restOfLine();
            continue;
        }
        output.put(input[plainTextStart..cursor]);

        const commandStart = ++cursor;
        readToSpace();
        const command = input[commandStart..cursor++];

        switch(command)
        {
            case "include":
                skipSpaces();
                enforce(cursor < input.length, "Unexpected EoF");
                enforce(input[cursor] == '"', "Expected '\"' following %inlcude preprocessor command.");

                const start = ++cursor;
                while(input[cursor] != '"')
                {
                    cursor++;
                    if(cursor == input.length)
                        throw new Exception("Unexpected EoF");
                }
                const end = cursor++;
                const child = input[start..end];

                if((child in alreadyIncluded) is null)
                {
                    handleIncludes(file, child, alreadyIncluded, output);
                    output.put("\n#");
                    output.put(file);
                    output.put('\n');
                }
                alreadyIncluded[child] = true;
                break;

            default: 
                restOfLine(); 
                output.put(input[commandStart-1..cursor]);
                break;
        }

        plainTextStart = cursor;
    }
    output.put(input[plainTextStart..$]);
}

private struct CommandParser
{
    string input;
    size_t cursor;
    bool empty;
    string front;

    this(string input)
    {
        this.input = input;
        this.popFront();
    }

    void popFront()
    {
        while(this.cursor < this.input.length && this.input[this.cursor] == ' ')
            this.cursor++;

        if(this.cursor >= this.input.length)
        {
            this.empty = true;
            return;
        }

        const firstCh = this.input[this.cursor];
        const start = this.cursor;
        if(firstCh != '"')
        {
            while(this.cursor < this.input.length && this.input[this.cursor] != ' ')
                this.cursor++;
            this.front = this.input[start..this.cursor];
        }
        else
        {
            this.cursor++;
            while(this.cursor < this.input.length && this.input[this.cursor] != '"')
                this.cursor++;
            this.cursor++;
            this.front = this.input[start..this.cursor];
        }
    }
}

private void handleCommands(string input, ref Appender!(char[]) code)
{
    size_t plainTextStart;
    for(size_t cursor = 0; cursor < input.length; cursor++)
    {
        void restOfLine()
        {
            while(cursor < input.length && input[cursor] != '\n')   
                cursor++;
        }

        if(input[cursor] != '%')
        {
            restOfLine();
            continue;
        }

        code.put("put([[");
        code.put(input[plainTextStart..cursor++]);
        code.put("]])\n");

        const start = cursor;
        restOfLine();
        auto parser = CommandParser(input[start..cursor]);
        enforce(!parser.empty, "Expected value after '%' indicating a preprocessor command.");

        const command = parser.front;
        parser.popFront();

        switch(command)
        {
            case "define":
                code.put("define(\"");
                code.put(parser.front);
                parser.popFront();
                code.put("\", ");
                code.put(parser.front);
                code.put(")\n");
                break;
            default: throw new Exception("Unknown preprocessor command: "~command);
        }

        plainTextStart = cursor;
    }
    code.put("put([[");
    code.put(input[plainTextStart..$]);
    code.put("]])\n");
}
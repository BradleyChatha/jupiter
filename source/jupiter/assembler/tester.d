module jupiter.assembler.tester;

import jupiter.assembler, std;

private struct Failed
{
    Case c;
    string[] errors;
    string ndisasmOutput;
}

private struct Case
{
    enum Kind
    {
        single
    }

    Kind kind;
    string eMneumonic;
    ubyte[] eBytes;
    string code;
}

void runTestCases()
{
    Failed[] failed;

    const cases = getCases!"test_suite/single.test"();
    foreach(c; cases)
    {
        writeln("Running test: ", c.code);
        runTest(c, failed);
    }

    foreach(failure; failed)
    {
        writefln("[Test '%s']", failure.c.code);
        foreach(error; failure.errors)
            writeln(error);
    }

    assert(!failed.length);
}

unittest
{
    runTestCases();
}

private Case[] getCases(string file)()
{
    Case[] ret;

    immutable code = import(file);
    auto r = regex(`(.+)\s+"(.+)"\s+(.+)`); // 1 = eMneumonic | 2 = code | 3 = eBytes

    foreach(line; code.lineSplitter)
    {
        const match = matchFirst(line, r);
        assert(!match.empty, "Line failed to parse: "~line);
        Case c;
        c.eMneumonic = match[1];
        c.code       = match[2];
        c.eBytes     = match[3].splitter(' ').map!(str => str.to!ubyte(16)).array;

        ret ~= c;
    }

    return ret;
}

private void runTest(const Case c, ref Failed[] failed)
{
    auto ast     = syntax1(c.code, "test");
    auto irInf   = ir(ast);
    auto emitInf = emit(irInf);

    Failed failure;
    failure.c = cast()c;
    final switch(c.kind) with(Case.Kind)
    {
        case single:
            string mneumonic;
            irInf.getSectionIr()[0].match!(
                (OpIr op) { mneumonic = op.inst.name; },
                (_) { assert(false); }
            );
            if(mneumonic != c.eMneumonic)
            {
                failure.errors ~= format!"Expected the %s mneumonic, but got %s instead."(
                    c.eMneumonic, mneumonic
                );
            }

            const bytes = emitInf.bytesBySection[".text"].data;
            if(!bytes.equal(c.eBytes))
            {
                failure.errors ~= format!"Expected bytes to be:\n\t%s\nNot:\n\t%s"(
                    c.eBytes, bytes
                );
            }

            if(failure.errors.length)
            {
                std.file.write("temp.bin", bytes);
                const result = executeShell("ndisasm temp.bin -b 64");
                failure.errors ~= format!"Ndisasm reports:\n%s"(result.output);
                failed ~= failure;
            }
            break;
    }
}
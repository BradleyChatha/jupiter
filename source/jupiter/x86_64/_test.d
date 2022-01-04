module jupiter.x86_64._test;

import std, jupiter.x86_64;

ubyte[] generateExample(Ir)()
{
    alias ctor = __traits(getMember, Ir, "__ctor");
    alias Params = Parameters!ctor;

    Mem m;
    m.mode = Mem.Mode.ripRelative;
    m.disp = 200;

    Params p;
    static foreach (i, param; Params)
    {
        {
            static if (is(param == Reg8))
                p[i] = Reg8(regi!"r8b");
            else static if (is(param == Reg16))
                p[i] = Reg16(regi!"r8w");
            else static if (is(param == Reg32))
                p[i] = Reg32(regi!"r8d");
            else static if (is(param == Reg64))
                p[i] = Reg64(regi!"r8");
            else static if (is(param == Rm64))
                p[i] = Rm64(Reg64(regi!"r9"));
            else static if (is(param == Imm8))
                p[i] = Imm8(byte.max);
            else static if (is(param == Imm16))
                p[i] = Imm16(short.max);
            else static if (is(param == Imm32))
                p[i] = Imm32(int.max);
            else static if (is(param == Imm64))
                p[i] = Imm64(long.max);
        }
    }

    ubyte[32] buffer;
    Ir ir = Ir(p);

    return ir.getBytes(buffer).dup;
}

unittest
{
    static foreach (inst; INSTRUCTIONS)
    {
        {
            alias i = __traits(getMember, jupiter.x86_64.ir, inst.name);
            std.file.write("test.bin", generateExample!i);
            const res = executeShell("ndisasm -b 64 test.bin");
            std.stdio.write(inst.name, "\t", res.output);
        }
    }
}

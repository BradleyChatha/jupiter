module jupiter.x86_64._test;

import std, jupiter.x86_64;

unittest
{
    ubyte[32] buffer;
    auto c = new IrExpression(IrExpression.Op.constant);
    c.solvedValue = 200;
    auto ir = new addr64rm64(
        Reg64(regi!"r9"),
        Rm64(Reg64(regi!"r10")),
    );
    writeln(
        ir.getBytes(buffer).map!(b => b.to!string(16))
    );
    std.file.write("test.bin", ir.getBytes(buffer));
}
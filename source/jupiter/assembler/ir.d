module jupiter.assembler.ir;

import jupiter.assembler, jupiter.assembler._ir, std;

alias ByteStream = Appender!(ubyte[]);

struct Imm(alias T) { T value; }
struct R(size_t Bits) { Register value; }

alias Imm8 = Imm!byte;
alias Imm16 = Imm!short;
alias Imm32 = Imm!int;
alias Imm64 = Imm!long;

alias R8 = R!8;
alias R16 = R!16;
alias R32 = R!32;
alias R64 = R!64;

struct RM(size_t Bits) 
{
    bool isMem;
    Mem mem;
    R!Bits reg;

    this(Mem m)
    {
        this.mem = m;
        this.isMem = true;
    }

    this(R!Bits reg)
    {
        this.reg = reg;
    }
}
alias RM8 = RM!8;
alias RM16 = RM!16;
alias RM32 = RM!32;
alias RM64 = RM!64;

struct Mem
{
    enum Mod
    {
        mod00,
        mod01,
        mod10,
        mod11
    }

    static struct Sib
    {
        ubyte ss;
        ubyte index;
        ubyte base;
    }

    Mod mod;
    ubyte rm;
    Nullable!Sib sib;
    Nullable!int disp;
    string label;

    void addToModrm(ref ubyte modrm)
    {
        modrm |= cast(ubyte)(this.mod << 6);
        modrm |= cast(ubyte)this.rm;
    }
}

struct IRState
{
    struct LabelRef
    {
        string label;
        size_t locationInByteStream;
    }

    LabelRef[] labelRefs;
}

Instruction findInstruction(OpcodeNode2 node, out size_t index)
{
    Instruction.OperandType[3] opTypes;
    enforce(node.params.length <= 3, formatTokenLocation(node.token)~"Opcodes can only have a maximum of 3 operands.");
    foreach(i, param; node.params)
        opTypes[i] = findOperandType(node, opTypes[0], param);

    index = INSTRUCTIONS.countUntil!(i => compareOperandTypes(i.o1_t, opTypes[0]) 
                                        && compareOperandTypes(i.o2_t, opTypes[1]) 
                                        && compareOperandTypes(i.o3_t, opTypes[2]));
    

    writeln(node.mneumonic, " ", opTypes, " ", index < 0 ? "<none>" : INSTRUCTIONS[index].to!string);
    if(index < 0)
    {
        auto instWithMneumonic = INSTRUCTIONS.filter!(i => i.mneumonic == node.mneumonic);
        Appender!(char[]) error;
        error.put(formatTokenLocation(node.token));
        error.put("Unknown form for instruction ");
        error.put(node.mneumonic.to!string);
        error.put(" - ");
        error.put(node.mneumonic.to!string);
        error.put(" ");
        error.put(opTypes[0].to!string);
        error.put(", ");
        error.put(opTypes[1].to!string);
        error.put(", ");
        error.put(opTypes[2].to!string);
        error.put("\n");

        error.put("    Here are the known forms for this instruction:\n");
        foreach(inst; instWithMneumonic)
        {
            error.put("        ");
            error.put(node.mneumonic.to!string);
            error.put(" ");
            error.put(inst.o1_t.to!string);
            error.put(", ");
            error.put(inst.o2_t.to!string);
            error.put(", ");
            error.put(inst.o3_t.to!string);
            error.put("\n");
        }
        throw new Exception(error.data.assumeUnique);
    }
    return INSTRUCTIONS[index];
}

Instruction.OperandType findOperandType(OpcodeNode2 node, Instruction.OperandType firstType, ExpressionNode2 param)
{
    if(auto p = cast(StringExpression2)param)
    {
        enforce(p.value.length == 1, formatTokenLocation(p.token)~"For normal instructions, strings can only be one character long.");
        return firstType;
    }
    else if(auto p = cast(IntegerExpression2)param)
        return inferImmType(firstType, node.type);
    else if(auto p = cast(UnsignedIntegerExpression2)param)
        return inferImmType(firstType, node.type);
    else if(auto p = cast(FloatingExpression2)param)
        enforce(false, "Not handled yet");
    else if(auto p = cast(IdentifierExpression2)param)
        return Instruction.OperandType._label;
    else if(auto p = cast(IndirectExpression2)param)
        return Instruction.OperandType._m;
    else if(auto p = cast(RegisterExpression2)param)
        return p.value.type;
    else
        throw new Exception("[Internal error] Unhandled parameter type: "~param.classinfo.to!string);
    assert(0);
}

Instruction.OperandType inferImmType(Instruction.OperandType firstType, SizeType nodeType)
{
    switch(nodeType) with (SizeType)
    {
        case imm8: return Instruction.OperandType.imm8;
        case imm16: return Instruction.OperandType.imm16;
        case imm32: return Instruction.OperandType.imm32;
        case imm64: return Instruction.OperandType.imm64;

        default: break;
    }

    switch(firstType) with(Instruction.OperandType)
    {
        case r8: return imm8;
        case r16: return imm16;
        case r32: return imm32;
        case r64: return imm64;
        default: assert(false);
    }
}

bool compareOperandTypes(Instruction.OperandType instOpType, Instruction.OperandType userOpType)
{
    if(instOpType == userOpType)
        return true;
    else if((userOpType == Instruction.OperandType._m || userOpType == Instruction.OperandType._label) 
        && (
            (instOpType >= Instruction.OperandType.rm8 && instOpType <= Instruction.OperandType.rm64)
            || (instOpType >= Instruction.OperandType.m8 && instOpType <= Instruction.OperandType.m64)
        )
    )
        return true;
    else if(userOpType == Instruction.OperandType.r8 && (instOpType == Instruction.OperandType.r8 || instOpType == Instruction.OperandType.rm8))   
        return true;
    else if(userOpType == Instruction.OperandType.r16 && (instOpType == Instruction.OperandType.r16 || instOpType == Instruction.OperandType.rm16))   
        return true;
    else if(userOpType == Instruction.OperandType.r32 && (instOpType == Instruction.OperandType.r32 || instOpType == Instruction.OperandType.rm32))   
        return true;
    else if(userOpType == Instruction.OperandType.r64 && (instOpType == Instruction.OperandType.r64 || instOpType == Instruction.OperandType.rm64))   
        return true;
    return false;
}

bool tryGetMem(ExpressionNode2 exp, out Mem mem, ref Instruction.Rex rex)
{
    if(auto e = cast(RegisterExpression2)exp)
    {
        mem.mod = Mem.Mod.mod11;
        mem.rm  = e.value.regNum;
        if(e.value.cat >= Register.Category.r8)
            rex |= Instruction.Rex.b;
        return true;
    }
    else if(auto e = cast(IndirectExpression2)exp)
    {
        if(auto t = cast(RegisterExpression2)e.target)
        {
            mem.mod = Mem.Mod.mod00;
            mem.rm  = t.value.regNum;
            if(t.value.cat >= Register.Category.r8)
                rex |= Instruction.Rex.b;
            return true;
        }
        else if(auto t = cast(IdentifierExpression2)e.target)
        {
            mem.mod  = Mem.Mod.mod00;
            mem.rm   = 0b100;
            mem.sib  = Mem.Sib(
                0,     // No scale
                0b100, // Index of None
                0b101, // Base of disposition
            );
            mem.disp = 0;
            mem.label = t.value;
            return true;
        }
        else
            throw new Exception("[Internal Error] Unhandled indirect expression target: "~e.target.classinfo.to!string);
    }

    return false;
}

bool tryGetImm(alias T)(ExpressionNode2 exp, out Imm!T imm)
{
    const BIT_MASK = (2 ^^ (T.sizeof * 8)) - 1;

    if(auto e = cast(IntegerExpression2)exp)
    {
        enforce((e.value & ~BIT_MASK) == 0, formatTokenLocation(exp.token)~"Value is too high/low for numeric type "~T.stringof);
        imm.value = cast(T)e.value;
        return true;
    }
    else if(auto e = cast(UnsignedIntegerExpression2)exp)
    {
        enforce((e.value & ~BIT_MASK) == 0, formatTokenLocation(exp.token)~"Value is too high/low for numeric type "~T.stringof);
        imm.value = cast(T)e.value;
        return true;
    }

    return false;
}

bool tryGetReg(size_t Bits)(ExpressionNode2 node, out R!Bits reg)
{
    if(auto e = cast(RegisterExpression2)node)
    {
        reg = R!Bits(e.value);
        return true;
    }

    return false;
}

bool tryGetRegMem(size_t Bits)(ExpressionNode2 node, out RM!Bits rm, ref Instruction.Rex rex)
{
    Mem mem;
    R!Bits reg;
    if(tryGetMem(node, mem, rex))
    {
        rm = RM!Bits(mem);
        return true;
    }
    else if(tryGetReg(node, reg))
    {
        rm = RM!Bits(reg);
        return true;
    }

    return false;
}

void putInstructionByIndex(ref ByteStream stream, ref IRState state, size_t index, ExpressionNode2[] exp)
{
    switch(index)
    {
        static foreach(i, ir; ALL_IR)
        {
            case i:
                auto inst = ir(exp);
                inst.putIntoBytes(stream, state);
                return;
        }

        default: throw new Exception("No instruction with index: "~index.to!string);
    }
}

void putInstruction(Instruction.OperandEncoding[] Encodings, Operands...)(
    ref ByteStream stream,
    ref IRState state,
    Prefix p1,
    G2Prefix p2,
    G3Prefix p3,
    G4Prefix p4,
    Instruction.Rex rex,
    Instruction.RegType reg,
    ubyte[] opcodes,
    Operands operands
)
if(Operands.length % 2 == 0)
{
    ubyte modrm;
    if(reg > Instruction.RegType.reg0)
        modrm |= cast(ubyte)(reg << 3);

    // Pass #1: Figure out all the special bytes.
    static foreach(i; 0..Operands.length)
    {{
        enum  Encoding = Encodings[i];
        auto  operand  = operands[i];
        alias OperandT = typeof(operand);

        static if(is(OperandT == Mem))
            auto op = RM64(operand);
        else static if(is(OperandT == R!Bits, size_t Bits))
            auto op = RM!Bits(operand);
        else static if(is(OperandT == RM!Bits, size_t Bits))
            auto op = operand;

        static if(is(OperandT == Mem) || isInstanceOf!(RM, OperandT))
        {
            if(op.isMem)
                op.mem.addToModrm(modrm);
        }
        static if(isInstanceOf!(R, OperandT) || isInstanceOf!(RM, OperandT))
        {
            if(!op.isMem)
            {
                static if(Encoding == Instruction.OperandEncoding.rm_reg)
                {
                    modrm |= cast(ubyte)(op.reg.value.regNum << 3);
                    if(op.reg.value.cat >= Register.Category.r8)
                        rex |= Instruction.Rex.r;
                }
                else static if(Encoding == Instruction.OperandEncoding.rm_rm)
                {
                    modrm |= cast(ubyte)(0b11 << 6);
                    modrm |= cast(ubyte)op.reg.value.regNum;
                    if(op.reg.value.cat >= Register.Category.r8)
                        rex |= Instruction.Rex.b;
                }
            }
        }
    }}

    // Pass #2: Write out the bytes.
    if(p1 != p1.none)
        stream.put(cast(ubyte)p1);
    if(p2 != p2.none)
        stream.put(cast(ubyte)p2);
    if(p3 != p3.none)
        stream.put(cast(ubyte)p3);
    if(p4 != p4.none)
        stream.put(cast(ubyte)p4);
    if(rex != Instruction.Rex.none)
    {
        rex |= 0b0100_0000;
        stream.put(cast(ubyte)rex);
    }
    stream.put(opcodes);
    if(modrm > 0)
        stream.put(modrm);
    static foreach(i; 0..Operands.length)
    {{
        enum  Encoding = Encodings[i];
        auto  operand  = operands[i];
        alias OperandT = typeof(operand);

        static if(is(OperandT == Mem))
            auto op = RM64(operand);
        else static if(is(OperandT == R!Bits, size_t Bits))
            auto op = RM!Bits(operand);
        else static if(is(OperandT == RM!Bits, size_t Bits))
            auto op = operand;

        static if(is(OperandT == Mem) || isInstanceOf!(RM, OperandT))
        {
            if(op.isMem)
            {
                static assert(Encoding == Instruction.OperandEncoding.rm_rm);
                if(!op.mem.sib.isNull)
                {
                    ubyte sib;
                    sib |= cast(ubyte)(op.mem.sib.get.ss << 6);
                    sib |= cast(ubyte)(op.mem.sib.get.index << 3);
                    sib |= cast(ubyte)(op.mem.sib.get.base);
                    stream.put(sib);
                }
                if(!op.mem.disp.isNull)
                {
                    if(op.mem.label !is null)
                        state.labelRefs ~= IRState.LabelRef(op.mem.label, stream.data.length);

                    if(op.mem.mod == Mem.Mod.mod00)
                        stream.put(op.mem.disp.get.nativeToLittleEndian[]);
                    else if(op.mem.mod == Mem.Mod.mod01)
                        stream.put(op.mem.disp.get.to!ubyte);
                    else if(op.mem.mod == Mem.Mod.mod10)
                        stream.put(op.mem.disp.get.nativeToLittleEndian[]);
                }
            }
        }
        else static if(is(OperandT == Imm!ImmT, ImmT))
        {
            static if(Encoding == Instruction.OperandEncoding.imm)
                stream.put(operand.value.to!ImmT.nativeToLittleEndian[]);
            else static assert(false, "Don't know how to handle this encoding for immediates.");
        }
    }}
}

unittest
{
    static struct Test
    {
        string code;
        string expectedForm;
        ubyte[] expectedBytes;
        bool hasLabelRef = false;
    }
    alias T = Test;

    immutable tests = [
        T("add cl, 1",          "add_rm8_i8",       [0x80, 0b11_000_001, 0x01]),
        T("add cx, 1",          "add_rm16_i16",     [0x81, 0b11_000_001, 0x01, 0x00]),
        T("add ecx, 1",         "add_rm32_i32",     [0x81, 0b11_000_001, 0x01, 0x00, 0x00, 0x00]),
        T("add dword rcx, 1",   "add_rm64_i32",     [0x48, 0x81, 0b11_000_001, 0x01, 0x00, 0x00, 0x00]),
        T("add cl, dl",         "add_rm8_r8",       [0x00, 0b11_010_001]),
        T("add cx, dx",         "add_rm16_r16",     [0x66, 0x01, 0b11_010_001]),
        T("add ecx, edx",       "add_rm32_r32",     [0x01, 0b11_010_001]),
        T("add rcx, rdx",       "add_rm64_r64",     [0x48, 0x01, 0b11_010_001]),
        T("lea rcx, [rdx]",     "lea_r64_m64",      [0x48, 0x8D, 0b00_001_010]),
        T("lea rcx, [poo]",     "lea_r64_m64",      [0x48, 0x8D, 0b00_001_100, 0b00_100_101, 0x00, 0x00, 0x00, 0x00], true),
        T("ret",                "retn",             [0xC3]),
    ];

    foreach(test; tests)
    {
        auto l = Lexer(test.code);
        auto p = Parser(l);
        auto ast = syntax2(p.root);
        auto op = cast(OpcodeNode2)ast.nodes[0];
        assert(op !is null, "Parser didn't return an opcode");
        size_t index;
        auto inst = findInstruction(op, index);
        assert(inst.debugName == test.expectedForm, "Expected "~test.expectedForm~" but got "~inst.debugName);

        IRState state;
        ByteStream bytes;
        putInstructionByIndex(bytes, state, index, op.params);
        assert(bytes.data.equal(test.expectedBytes), "Got:%s (%s)\nExp: %s (%s)".format(
            bytes.data.map!(b => b.to!string(16)), bytes.data.map!(b => b.to!string(2)),
            test.expectedBytes.map!(b => b.to!string(16)), test.expectedBytes.map!(b => b.to!string(2))
        ));

        if(test.hasLabelRef)
            assert(state.labelRefs.length == 1);
    }
}
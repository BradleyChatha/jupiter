module jupiter.assembler.ir;

import jupiter.assembler, std;
import std.sumtype : match;

struct Imm8 { byte value; ubyte[1] bytes(){ return [value]; } }
struct Imm16 { short value; ubyte[2] bytes(){ return (cast(ubyte*)&this.value)[0..2]; } }
struct Imm32 { int value; ubyte[4] bytes(){ return (cast(ubyte*)&this.value)[0..4]; } }
struct Imm64 { long value; ubyte[8] bytes(){ return (cast(ubyte*)&this.value)[0..8]; } }
struct R8 { Register value; void validate() { enforce(this.value.type == Instruction.OperandType.r8, "Expected an r8, not "~this.value.type.to!string); } }
struct R16 { Register value; void validate() { enforce(this.value.type == Instruction.OperandType.r16, "Expected an r16, not "~this.value.type.to!string); } }
struct R32 { Register value; void validate() { enforce(this.value.type == Instruction.OperandType.r32, "Expected an r32, not "~this.value.type.to!string); } }
struct R64 { Register value; void validate() { enforce(this.value.type == Instruction.OperandType.r64, "Expected an r64, not "~this.value.type.to!string); } }
struct Mem { ulong value; }
struct Label { string name; }

alias RM8 = SumType!(R8, Mem, Label);
alias RM16 = SumType!(R16, Mem, Label);
alias RM32 = SumType!(R32, Mem, Label);
alias RM64 = SumType!(R64, Mem, Label);
alias IRSum = SumType!ALL_IR;

struct IR
{
    IRSum value;
}

struct IRState
{
    static struct LabelRef
    {
        string name;
        size_t wantedAt;
    }

    static struct Label
    {
        string name;
        string sourceSection;
        size_t sourceOpcode;
        bool isExtern;
    }

    static struct Section
    {
        string name;
        IR[] ir;
    }

    LabelRef[] labelRefs;
    Label[] labels;
    Section[string] sections;
    string[] globals;
    string[] externs;
}

IRState ir1(Syntax2Result ast)
{
    IRState state;
    string sectionName;
    IRState.Section* section;

    sectionName = ".text";
    state.sections[".text"] = IRState.Section(".text");
    section = ".text" in state.sections;

    Foreach: foreach(n; ast.nodes)
    {
        if(auto node = cast(ParentLabelNode2)n)
            state.labels ~= IRState.Label(node.name, sectionName, section.ir.length, false);
        else if(auto node = cast(ChildLabelNode2)n)
            state.labels ~= IRState.Label(node.parent.name~"."~node.name, sectionName, section.ir.length, false);
        else if(auto node = cast(SectionDirective2)n)
        {
            sectionName = node.name;
            section = sectionName in state.sections;
            if(!section)
            {
                state.sections[sectionName] = IRState.Section(sectionName);
                section = sectionName in state.sections;
            }
        }
        else if(auto node = cast(GlobalDirective2)n)
            state.globals ~= node.name;
        else if(auto node = cast(ExternDirective2)n)
            state.externs ~= node.name;
        else if(auto node = cast(OpcodeNode2)n)
        {
            Instruction.OperandType o1_t, o2_t, o3_t;
            if(node.node.params.length >= 1) o1_t = getOpcodeOperandType(node.node.params[0], node.node.type, node.node.mneumonic);
            if(node.node.params.length >= 2) o2_t = getOpcodeOperandType(node.node.params[1], node.node.type, node.node.mneumonic);
            if(node.node.params.length >= 3) o3_t = getOpcodeOperandType(node.node.params[2], node.node.type, node.node.mneumonic);

            auto inferredSize = o1_t; // Will always be a register size if not `none`.
            switch(inferredSize)
            {
                default:
                case Instruction.OperandType.none: break;
                
                case Instruction.OperandType.r8: inferredSize = Instruction.OperandType.imm8; break;
                case Instruction.OperandType.r16: inferredSize = Instruction.OperandType.imm16; break;
                case Instruction.OperandType.r32: inferredSize = Instruction.OperandType.imm32; break;
                case Instruction.OperandType.r64: inferredSize = Instruction.OperandType.imm64; break;
            }

            if(o2_t == Instruction.OperandType._infer) o2_t = inferredSize;
            if(o3_t == Instruction.OperandType._infer) o3_t = inferredSize;

            // TODO: Use proper algorithms instead of these "good enough" ones
            auto index = INSTRUCTIONS.countUntil!(
                a => a.mneumonic == node.node.mneumonic 
                && a.o1_t.operandsMatch(o1_t) 
                && a.o2_t.operandsMatch(o2_t)
                && a.o3_t.operandsMatch(o3_t)
            );
            writeln(index, "\t", node.node.mneumonic, "\t", o1_t, "\t", o2_t, "\t", o3_t);
            if(index == -1)
                continue;
            auto inst  = INSTRUCTIONS[index];
            static foreach(ir; ALL_IR)
            {
                if(ir.inst == inst)
                {
                    section.ir ~= IR(IRSum(ir(node.node.params)));
                    continue Foreach;
                }
            }
        }
        else
            assert(false);
    }

    Appender!(ubyte[]) b;
    foreach(ir; section.ir)
    {
        ir.value.match!((_) => _.pushBytes(b, state));
    }
    std.file.write("raw.bin", b.data);
    return state;
}

bool operandsMatch(Instruction.OperandType instT, Instruction.OperandType userT)
{
    if(instT == userT)
        return true;

    switch(instT) with(Instruction.OperandType)
    {
        case rm8: return userT == r8 || userT == m8;
        case rm16: return userT == r16 || userT == m16;
        case rm32: return userT == r32 || userT == m32;
        case rm64: return userT == r64 || userT == m64;
        default: break;
    }

    return false;
}

Instruction.OperandType getOpcodeOperandType(Expression ex, SizeType inferredSize, MneumonicHigh mh)
{
    return ex.match!(
        (StringExpression str) 
        {
            if(mh != mh.db && mh != mh.dw && mh != mh.dd && mh != mh.dq)
                enforce(str.str.length == 1, formatTokenLocation(str.tok)~"When used with ASM mneumonics, strings can only be 1 character long.");
            return stToOt(inferredSize);
        },
        (NumberExpression num)
        {
            return stToOt(num.type);
        },
        (RegisterExpression reg)
        {
            return reg.reg.type;
        },
        (_)
        {
            return Instruction.OperandType.none;
        }
    );
}

Instruction.OperandType stToOt(SizeType st)
{
    switch(st)
    {
        case SizeType.imm8: return Instruction.OperandType.imm8;
        case SizeType.imm16: return Instruction.OperandType.imm16;
        case SizeType.imm32: return Instruction.OperandType.imm32;
        case SizeType.imm64: return Instruction.OperandType.imm64;

        default: return Instruction.OperandType._infer;
    }
}

unittest
{
    auto c = import("test/hello_world.asm");
    auto l = Lexer(c);
    auto p = Parser(l);
    auto s = syntax2(p.root);
    auto ir = ir1(s);
    import std;
    writeln(ir);
}
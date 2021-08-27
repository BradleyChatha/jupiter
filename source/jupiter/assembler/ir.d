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
struct Label { string name; }
struct D(alias T) 
{ 
    Expression[] values;

    void pushBytes(R)(ref R bytes, ref IRState state)
    {
        foreach(exp; this.values)
        exp.match!(
            (StringExpression str)
            {
                // TODO: Unicode support.
                foreach(ch; str.str)
                    bytes.put(nativeToLittleEndian(cast(T)ch)[0..$]);
            },
            (NumberExpression num)
            {
                bytes.put(nativeToLittleEndian(cast(T)num.asInt)[0..$]);
            },
            (_) { throw new Exception("Cannot use expression %s with db,dw,dd,dq mneumonics.".format(_)); }
        );
    }
}

alias Mem = SumType!(Imm64, Label);
alias RM8 = SumType!(R8, Mem);
alias RM16 = SumType!(R16, Mem);
alias RM32 = SumType!(R32, Mem);
alias RM64 = SumType!(R64, Mem);

alias Db = D!byte;
alias Dw = D!short;
alias Dd = D!int;
alias Dq = D!long;
alias IRSum = SumType!(ALL_IR, Db, Dw, Dd, Dq);

struct IR
{
    IRState.Label[] labels;
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
    }

    static struct Section
    {
        string name;
        IR[] ir;
    }

    LabelRef[] labelRefs;
    Section[string] sections;
    string[] globals;
    string[] externs;
    string[] errors;
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
        if(auto node = cast(SectionDirective2)n)
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
            IRState.Label[] labels;
            foreach(label; node.labels)
            {
                if(auto plabel = cast(ParentLabelNode2)label)
                    labels ~= IRState.Label(plabel.name);
                else if (auto clabel = cast(ChildLabelNode2)label)
                    labels ~= IRState.Label(clabel.parent.name~"."~clabel.name);
                else
                    assert(false);
            }

            if(node.node.mneumonic == MneumonicHigh.db)
            { section.ir ~= IR(labels, IRSum(Db(node.node.params))); continue; }
            else if(node.node.mneumonic == MneumonicHigh.dw)
            { section.ir ~= IR(labels, IRSum(Dw(node.node.params))); continue; }
            else if(node.node.mneumonic == MneumonicHigh.dd)
            { section.ir ~= IR(labels, IRSum(Dd(node.node.params))); continue; }
            else if(node.node.mneumonic == MneumonicHigh.dq)
            { section.ir ~= IR(labels, IRSum(Dq(node.node.params))); continue; }

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
            {
                addNotFoundError(state, node, o1_t, o2_t, o3_t);
                continue;
            }
            auto inst = INSTRUCTIONS[index];
            static foreach(ir; ALL_IR)
            {
                if(ir.inst == inst)
                {
                    section.ir ~= IR(labels, IRSum(ir(node.node.params)));
                    continue Foreach;
                }
            }
        }
        else
            assert(false);
    }

    Appender!(ubyte[]) b;
    foreach(s; state.sections.byValue)
    {
        foreach(ir; s.ir)
            ir.value.match!((_) => _.pushBytes(b, state));
    }
    std.file.write("raw.bin", b.data);

    foreach(error; state.errors)
        writeln(error);
    return state;
}

void addNotFoundError(ref IRState state, OpcodeNode2 node, Instruction.OperandType o1_t, Instruction.OperandType o2_t, Instruction.OperandType o3_t)
{
    Appender!(char[]) output;

    output.put(formatTokenLocation(node.token));
        output.put("Unknown opcode: "); 
        output.put(node.node.mneumonic.to!string);
        output.put(" ");
        output.put(o1_t.to!string);
        output.put(", ");
        output.put(o2_t.to!string);
        output.put(", ");
        output.put(o3_t.to!string);
    output.put("\n");
    
    auto forms = INSTRUCTIONS.filter!(i => i.mneumonic == node.node.mneumonic);
    if(forms.empty)
    {
        output.put("    Mnuemonic is unknown. Either I haven't added it yet, or you've spelled it wrong.\n");
        output.put("    Please note that in Jupiter, all mneumonics must be lower case (for now!).");
    }
    else
    {
        output.put("    These are the valid forms for this opcode:\n");
        foreach(form; forms)
        {
            output.put("        ");
            output.put(form.mneumonic.to!string);
            output.put("\t");
            output.put(form.o1_t.to!string);
            output.put(",\t");
            output.put(form.o2_t.to!string);
            output.put(",\t");
            output.put(form.o3_t.to!string);
            output.put("\n");
        }
    }

    state.errors ~= output.data.assumeUnique;
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
}
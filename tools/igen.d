import jupiter.assembler.info, std;

void main()
{
    Appender!(char[]) aliases;
    Appender!(char[]) structs;
    Appender!(char[]) mapping;

    writeln("Run you fuck");

    const IMM_TEMPLATE = `Imm%s expImm%s(Expression ex)
{ 
    Imm%s ret; 
    ex.match!(
        (StringExpression str) 
        { 
            ret = Imm%s(cast(%s)str.str[0]); 
        }, 
        (NumberExpression num)
        { 
            ret = Imm%s(num.asInt.to!%s); 
        }, 
        (_){ assert(false); }
    ); 
    return ret;
}
`;

    const RM_TEMPLATE = `RM%s expRM%s(Expression ex)
{
    RM%s ret;
    ex.match!(
        (RegisterExpression reg)
        {
            auto r = R%s(reg.reg);
            r.validate();
            ret = RM%s(r);
        },
        (_){ assert(false); }
    );
    return ret;
}
`;

    const R_TEMPLATE = `R%s expR%s(Expression ex)
{
    R%s ret;
    ex.match!(
        (RegisterExpression reg)
        {
            ret = R%s(reg.reg);
            ret.validate();
        },
        (_){ assert(false); }
    );
    return ret;
}
`;

    const MEM_TEMPLATE = `Mem expMem(Expression ex)
{
    Mem ret;
    ex.match!(
        (IdentifierExpression label)
        {
            ret = Label(label.ident);
        },
        (_){ assert(false); }
    );
    return ret;
}
`;
    structs.put("module jupiter.assembler._ir;\n\nimport jupiter.assembler, std, std.sumtype : match;\n\n");
    structs.put(format!IMM_TEMPLATE("8", "8", "8", "8", "ubyte", "8", "ubyte"));
    structs.put(format!IMM_TEMPLATE("16", "16", "16", "16", "short", "16", "short"));
    structs.put(format!IMM_TEMPLATE("32", "32", "32", "32", "int", "32", "int"));
    structs.put(format!IMM_TEMPLATE("64", "64", "64", "64", "long", "64", "long"));
    structs.put(format!RM_TEMPLATE("8", "8", "8", "8", "8"));
    structs.put(format!RM_TEMPLATE("16", "16", "16", "16", "16"));
    structs.put(format!RM_TEMPLATE("32", "32", "32", "32", "32"));
    structs.put(format!RM_TEMPLATE("64", "64", "64", "64", "64"));
    structs.put(format!R_TEMPLATE("8", "8", "8", "8"));
    structs.put(format!R_TEMPLATE("16", "16", "16", "16"));
    structs.put(format!R_TEMPLATE("32", "32", "32", "32"));
    structs.put(format!R_TEMPLATE("64", "64", "64", "64"));
    structs.put(MEM_TEMPLATE);

    aliases.put("alias ALL_IR = AliasSeq!(\n");
    foreach(i, inst; INSTRUCTIONS)
        gen(aliases, structs, i, inst);
    aliases.put(");\n");
    genMapping(mapping);

    structs.put(aliases.data);
    structs.put(mapping.data);
    std.file.write("source/jupiter/assembler/_ir.d", structs.data);
}

void genMapping(ref Appender!(char[]) mapping)
{
}

void gen(ref Appender!(char[]) aliases, ref Appender!(char[]) structs, size_t i, Instruction inst)
{
    Appender!(char[]) ctor;

    ctor.put("\tthis(Expression[] args) {\n");

    aliases.put("\t"); aliases.put(inst.debugName); aliases.put(",\n");
    structs.put("struct "); structs.put(inst.debugName);
    structs.put("\n{\n");
    structs.put("\tstatic immutable Instruction inst = INSTRUCTIONS["~i.to!string~"];\n");
    foreach(i2, op; [inst.o1_t, inst.o2_t, inst.o3_t])
    {
        if(op == Instruction.OperandType.none)
            continue;

        structs.put('\t');
        ctor.put("\t\to"~i2.to!string~" = ");
        final switch(op) with(Instruction.OperandType)
        {
            case none: break;
            case r8: structs.put("R8");   ctor.put("expR8(args["~i2.to!string~"]);\n");  break;    
            case r16: structs.put("R16"); ctor.put("expR16(args["~i2.to!string~"]);\n"); break;   
            case r32: structs.put("R32"); ctor.put("expR32(args["~i2.to!string~"]);\n"); break;   
            case r64: structs.put("R64"); ctor.put("expR64(args["~i2.to!string~"]);\n"); break;   
            case imm8: structs.put("Imm8");   ctor.put("expImm8(args["~i2.to!string~"]);\n"); break;  
            case imm16: structs.put("Imm16"); ctor.put("expImm16(args["~i2.to!string~"]);\n"); break; 
            case imm32: structs.put("Imm32"); ctor.put("expImm32(args["~i2.to!string~"]);\n"); break; 
            case imm64: structs.put("Imm64"); ctor.put("expImm64(args["~i2.to!string~"]);\n"); break; 
            case m8: structs.put("Mem");     ctor.put("expMem(args["~i2.to!string~"]);"); break;    
            case m16: structs.put("Mem");   ctor.put("expMem(args["~i2.to!string~"]);"); break;   
            case m32: structs.put("Mem");   ctor.put("expMem(args["~i2.to!string~"]);"); break;   
            case m64: structs.put("Mem");   ctor.put("expMem(args["~i2.to!string~"]);"); break;

            case rm8: structs.put("RM8"); ctor.put("expRM8(args["~i2.to!string~"]);"); break;   
            case rm16: structs.put("RM16"); ctor.put("expRM16(args["~i2.to!string~"]);"); break;  
            case rm32: structs.put("RM32"); ctor.put("expRM32(args["~i2.to!string~"]);"); break;  
            case rm64: structs.put("RM64"); ctor.put("expRM64(args["~i2.to!string~"]);"); break; 
            case _infer: assert(false);
        }
        structs.put(' ');
        structs.put("o"~i2.to!string);
        structs.put(";\n");
    }
    ctor.put("\t}\n");
    structs.put(ctor.data);
    structs.put("\tvoid pushBytes(R)(ref R output, ref IRState state){\n");
        structs.put("\t\tubyte rex = 0b0100_0000;\n\t\tubyte modrm;\n\t\tbool outRex, outMod;\n");

        if(inst.rex != Instruction.Rex.none)
            structs.put("\t\toutRex = true; rex |= "~(cast(int)inst.rex).to!string~";\n");

        if(cast(int)inst.rm_t >= 0)
        {
            structs.put("\t\toutMod = true;\n");
            if(inst.rm_t != Instruction.RmType.r)
                structs.put("\t\tmodrm |= "~(cast(int)inst.rm_t).to!string~" << 3;\n");
        }

        static foreach(opI; 0..3)
        {{
            mixin("auto op_t = inst.o"~(opI+1).to!string~"_t;");
            mixin("auto op_e = inst.o"~(opI+1).to!string~"_e;");
            if(op_e == Instruction.OperandEncoding.rm_rm)
            {
                const isR  = op_t >= Instruction.OperandType.r8 && op_t <= Instruction.OperandType.r64;
                const isRm = op_t >= Instruction.OperandType.rm8 && op_t <= Instruction.OperandType.rm64;

                if(isR)
                {
                    structs.put("\t\tif(this.o"~opI.to!string~".value.cat >= Register.Category.r8) {\n");
                    structs.put("\t\t\toutRex = true;\n");
                    structs.put("\t\t\trex |= Instruction.Rex.b;\n");
                    structs.put("\t\t}\n");
                    structs.put("\t\toutMod = true;\n");
                    structs.put("\t\tmodrm |= this.o"~opI.to!string~".value.regNum;\n");
                }
                else if(isRm)
                {
                    structs.put("\t\toutMod = true;\n");
                    structs.put("\t\tthis.o"~opI.to!string~".match");
                    structs.put
(`!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
`);
                }
            }
            else if(op_e == Instruction.OperandEncoding.rm_reg)
            {
                const isR  = op_t >= Instruction.OperandType.r8 && op_t <= Instruction.OperandType.r64;
                const isRm = op_t >= Instruction.OperandType.rm8 && op_t <= Instruction.OperandType.rm64;

                if(isR)
                {
                    structs.put("\t\tif(this.o"~opI.to!string~".value.cat >= Register.Category.r8) {\n");
                    structs.put("\t\t\toutRex = true;\n");
                    structs.put("\t\t\trex |= Instruction.Rex.r;\n");
                    structs.put("\t\t}\n");
                    structs.put("\t\toutMod = true;\n");
                    structs.put("\t\tmodrm |= this.o"~opI.to!string~".value.regNum << 3;\n");
                }
                else if(isRm)
                {
                    structs.put("\t\toutMod = true;\n");
                    structs.put("\t\tthis.o"~opI.to!string~".match");
                    structs.put
(`!(
            (reg) { modrm |= reg.value.regNum << 3; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.r; } },
            (_) { assert(false); }
        );
`);
                }
            }
        }}

        structs.put("\t\tif(outRex) output.put(rex);\n");
        final switch(inst.op_c)
        {
            case 0: break;
            case 3:
                structs.put("\t\toutput.put(cast(ubyte)0x"~inst.op_1.to!string(16)~");\n");
                goto case;
            case 2:
                structs.put("\t\toutput.put(cast(ubyte)0x"~inst.op_2.to!string(16)~");\n");
                goto case;
            case 1:
                structs.put("\t\toutput.put(cast(ubyte)0x"~inst.op_3.to!string(16)~");\n");
                break;
        }
        structs.put("\t\tif(outMod){\n");
            if(inst.o1_t == Instruction.OperandType.rm8)
                structs.put("\t\t\tthis.o0.match!((R8 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });\n");
            else if(inst.o1_t == Instruction.OperandType.rm16)
                structs.put("\t\t\tthis.o0.match!((R16 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });\n");
            else if(inst.o1_t == Instruction.OperandType.rm32)
                structs.put("\t\t\tthis.o0.match!((R32 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });\n");
            else if(inst.o1_t == Instruction.OperandType.rm64)
                structs.put("\t\t\tthis.o0.match!((R64 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });\n");
            structs.put("\t\t\toutput.put(modrm);\n");
        structs.put("\t\t}\n");
        
        // Immediate
        if(inst.o1_e == Instruction.OperandEncoding.imm)
            structs.put("\t\toutput.put(this.o0.bytes[]);\n");
        if(inst.o2_e == Instruction.OperandEncoding.imm)
            structs.put("\t\toutput.put(this.o1.bytes[]);\n");
        if(inst.o3_e == Instruction.OperandEncoding.imm)
            structs.put("\t\toutput.put(this.o2.bytes[]);\n");
    structs.put("\t}\n");
    structs.put("\n}\n");
}
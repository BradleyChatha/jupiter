import jupiter.x86_64.info, std;

void main()
{
    Appender!(char[]) output;

    output.put(import("partials/x86_64_ir.d"));

    foreach(i, inst; INSTRUCTIONS)
    {
        Appender!(char[]) ctorBody;
        Appender!(char[]) ctorParams;
        Appender!(char[]) vars;
        Appender!(char[]) getBytes;
        Appender!(char[]) getBytesPost;

        output.put("final class %s : Ir {\n".format(inst.name));
        output.put("    static immutable INSTRUCTION = INSTRUCTIONS[%s];\n".format(i));
        output.put("    override Instruction getInstruction() { return cast()INSTRUCTIONS[%s]; }\n".format(i));

        ctorParams.put("    this(");
        ctorBody.put("    {\n");
        foreach(i2, ot; inst.op_t)
        {
            const isConstParam = inst.op_reg[i2] != Register.init;

            if(i2 != 0 
            && inst.op_t[i2-1] != Instruction.OperandType.none 
            && ot != Instruction.OperandType.none 
            && !isConstParam
            && (i2 == 1 && inst.op_reg[i2-1] == Register.init))
                ctorParams.put(", ");
            if(ot != Instruction.OperandType.none)
            {
                if(isConstParam)
                    ctorBody.put("        this.%s = regi!\"%s\";\n".format(argName(i2), inst.op_reg[i2].name));
                else
                    ctorBody.put("        this.%s = %s;\n".format(argName(i2), argName(i2)));
            }
            final switch(ot) with(Instruction.OperandType)
            {
                case label: assert(false);
                case none: break;
                case r:
                    final switch(inst.op_s[i2]) with(SizeType)
                    {
                        case infer: assert(false);
                        case s8: vars.put("    Reg8"); if(!isConstParam) ctorParams.put("Reg8"); break;
                        case s16: vars.put("    Reg16"); if(!isConstParam) ctorParams.put("Reg16"); break;
                        case s32: vars.put("    Reg32"); if(!isConstParam) ctorParams.put("Reg32"); break;
                        case s64: vars.put("    Reg64"); if(!isConstParam) ctorParams.put("Reg64"); break;
                    }
                    vars.put(" "~argName(i2)~";\n");
                    if(!isConstParam) ctorParams.put(" "~argName(i2));
                    break;
                case imm:
                    final switch(inst.op_s[i2]) with(SizeType)
                    {
                        case infer: assert(false);
                        case s8: vars.put("    Imm8Expression"); if(!isConstParam) ctorParams.put("Imm8Expression"); break;
                        case s16: vars.put("    Imm16Expression"); if(!isConstParam) ctorParams.put("Imm16Expression"); break;
                        case s32: vars.put("    Imm32Expression"); if(!isConstParam) ctorParams.put("Imm32Expression"); break;
                        case s64: vars.put("    Imm64Expression"); if(!isConstParam) ctorParams.put("Imm64Expression"); break;
                    }
                    vars.put(" "~argName(i2)~";\n");
                    if(!isConstParam) ctorParams.put(" "~argName(i2));
                    break;
                case mem:
                    vars.put("        Mem");
                    ctorParams.put("Mem");
                    final switch(inst.op_s[i2]) with(SizeType)
                    {
                        case infer: assert(false);
                        case s8: break;
                        case s16: break;
                        case s32: break;
                        case s64: break;
                    }
                    vars.put(" "~argName(i2)~";\n");
                    if(!isConstParam) ctorParams.put(" "~argName(i2));
                    break;
                case rm:
                    final switch(inst.op_s[i2]) with(SizeType)
                    {
                        case infer: assert(false);
                        case s8:
                        case s16:
                        case s32:
                        case s64: vars.put("    Rm64"); if(!isConstParam) ctorParams.put("Rm64"); break;
                    }
                    vars.put(" "~argName(i2)~";\n");
                    if(!isConstParam) ctorParams.put(" "~argName(i2));
                    break;
            }
        }
        ctorParams.put(")\n");
        ctorBody.put("    }\n");

        getBytes.put(`
    override ubyte[] getBytes(scope ref return ubyte[32] bytes)
    {
        return emit!(typeof(this))(this, bytes);
    }
`);

        output.put(vars.data);
        output.put(ctorParams.data);
        output.put(ctorBody.data);
        output.put(getBytes.data);
        output.put("}\n");
    }

    writeln(output.data);
    std.file.write("../source/jupiter/x86_64/ir.d", output.data);
}

string argName(size_t index)
{
    return "arg"~index.to!string;
}
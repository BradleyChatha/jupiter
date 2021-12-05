import std;

version(Info)
{
    void main()
    {
        auto temp = import("partials/x86_64_info.d");
        Appender!(char[]) output;
        const info = parse();

        foreach(inf; info)
        {
            Out o;
            o.mneumonic = inf.mneumonic;
            o.name = inf.mneumonic;
            foreach(arg; inf.args)
                o.name ~= arg;
            o.op = cast(ubyte[])inf.op;

            switch(inf.encoding)
            {
                case "NI":
                    o.oe[0] = "none";
                    o.oe[1] = "imm";
                    break;
                case "MI":
                    o.oe[0] = "rm_rm";
                    o.oe[1] = "imm";
                    break;
                case "MR":
                    o.oe[0] = "rm_rm";
                    o.oe[1] = "rm_reg";
                    break;
                case "RM":
                    o.oe[0] = "rm_reg";
                    o.oe[1] = "rm_rm";
                    break;
                case "O":
                    o.oe[0] = "add";
                    break;
                default: throw new Exception("Unknown encoding: "~inf.encoding);
            }

            foreach(i, arg; inf.args)
            {
                switch(arg)
                {
                    case "al":
                        o.ot[i] = "r";
                        o.os[i] = "s8";
                        o.or[i] = `regi!"`~arg~'"';
                        break;
                    case "ax":
                        o.ot[i] = "r";
                        o.os[i] = "s16";
                        o.or[i] = `regi!"`~arg~'"';
                        break;
                    case "eax":
                        o.ot[i] = "r";
                        o.os[i] = "s32";
                        o.or[i] = `regi!"`~arg~'"';
                        break;
                    case "rax":
                        o.ot[i] = "r";
                        o.os[i] = "s64";
                        o.or[i] = `regi!"`~arg~'"';
                        break;

                    default:
                        string type;
                        string size;

                        if(arg.startsWith("rm"))
                        {
                            type = "rm";
                            size = arg[2..$];
                        }
                        else if(arg.startsWith("r") || arg.startsWith("i"))
                        {
                            type = arg[0..1] == "i" ? "imm" : arg[0..1];
                            size = arg[1..$];
                        }

                        o.ot[i] = type;
                        o.os[i] = "s"~size;
                        break;
                }
            }

            foreach(flag; inf.flags)
            {
                switch(flag)
                {
                    case "REG0": o.reg = "reg0"; break;
                    case "REG1": o.reg = "reg1"; break;
                    case "REG2": o.reg = "reg2"; break;
                    case "REG3": o.reg = "reg3"; break;
                    case "REG4": o.reg = "reg4"; break;
                    case "REG5": o.reg = "reg5"; break;
                    case "REG6": o.reg = "reg6"; break;
                    case "REG7": o.reg = "reg7"; break;
                    case "REXW": o.rex = "w"; break;
                    case "P3OP": o.pg3 = "opSize"; break;
                    case "LOCK": o.pg1 = "lock"; break;
                    case "REPE": o.pg1 = "rep"; break;
                    case "REPN": o.pg1 = "repnz"; break;
                    default: throw new Exception("Unknown flag: "~flag);
                }
            }

            output.put(o.toString());
            output.put('\n');
        }

        std.file.write("../source/jupiter/x86_64/info.d", temp.format(output.data));
    }

    struct Out
    {
        string mneumonic;
        string name;
        string pg1 = "none";
        string pg2 = "none";
        string pg3 = "none";
        string pg4 = "none";
        string rex = "none";
        string reg = "none";
        ubyte[] op;
        string[3] ot = ["none", "none", "none"];
        string[3] os = ["infer", "infer", "infer"];
        string[3] oe = ["none", "none", "none"];
        string[3] or = ["ri", "ri", "ri"];
        string flag = "none";

        string toString() const
        {
            return "i(m.%s, \"%s\", pg1.%s, pg2.%s, pg3.%s, pg4.%s, rex.%s, reg.%s, [%s], [ot.%s, ot.%s, ot.%s], [st.%s,  st.%s,  st.%s], [oe.%s, oe.%s, oe.%s], [%s, %s, %s], f.%s),".format(
                mneumonic,
                name,
                pg1,
                pg2,
                pg3,
                pg4,
                rex,
                reg,
                op.map!(o => "0x"~o.to!string(16)).fold!((a,b)=>a.length ? a~','~b : b)(""),
                ot[0], ot[1], ot[2],
                os[0], os[1], os[2],
                oe[0], oe[1], oe[2],
                or[0], or[1], or[2],
                flag
            );
        }
    }

    struct Info
    {
        string mneumonic;
        string[] args;
        ubyte[] op;
        string encoding;
        string[] flags;
    }

    Info[] parse()
    {
        const data = import("isa/x86_64.txt");
        return data
                .split('\n')
                .map!((line)
                {
                    auto data = line.split(' ').filter!(d => d.length > 0).array;
                    writeln(data);
                    return Info(
                        data[0],
                        data[1].split(',').array,
                        data[2].split(',').map!(s => s.to!ubyte(16)).array,
                        data[3],
                        data[4..$]
                    );
                })
                .array;
    }
}
else version(Ir)
{
    import jupiter.x86_64.info;
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

            const hasRm = inst.op_t[].canFind(Instruction.OperandType.rm);
            string rmArg;

            output.put("final class %s : %s {\n".format(inst.name, hasRm ? "IrWithRm" : "Ir"));
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
                            case s8: vars.put("    Imm8"); if(!isConstParam) ctorParams.put("Imm8"); break;
                            case s16: vars.put("    Imm16"); if(!isConstParam) ctorParams.put("Imm16"); break;
                            case s32: vars.put("    Imm32"); if(!isConstParam) ctorParams.put("Imm32"); break;
                            case s64: vars.put("    Imm64"); if(!isConstParam) ctorParams.put("Imm64"); break;
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
                        rmArg = argName(i2);
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

            if(hasRm)
                getBytes.put("    override ref Rm64 getRm(){ return %s; }\n".format(rmArg));

            output.put(vars.data);
            output.put(ctorParams.data);
            output.put(ctorBody.data);
            output.put(getBytes.data);
            output.put("}\n");
        }

        std.file.write("../source/jupiter/x86_64/ir.d", output.data);
    }

    string argName(size_t index)
    {
        return "arg"~index.to!string;
    }
}
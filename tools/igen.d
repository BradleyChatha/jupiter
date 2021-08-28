import jupiter.assembler.info, std;

void main()
{
    Appender!(char[]) aliases;
    Appender!(char[]) main;

    main.put("module jupiter.assembler._ir;\n\nimport jupiter.assembler, std;\n");

    aliases.put("alias ALL_IR = AliasSeq!(\n");
    foreach(i, inst; INSTRUCTIONS)
        gen(aliases, main, i, inst);
    aliases.put(");\n");

    main.put(aliases.data);
    std.file.write("source/jupiter/assembler/_ir.d", main.data);
}

void gen(ref Appender!(char[]) aliases, ref Appender!(char[]) main, size_t i, Instruction inst)
{
    aliases.put("\t"); aliases.put(inst.debugName); aliases.put(",\n");

    main.put("struct "); main.put(inst.debugName); main.put(" {\n");
        main.put("\tInstruction.Rex rex;\n");
        foreach(j, op_t; [inst.o1_t, inst.o2_t, inst.o3_t])
        {
            if(op_t == Instruction.OperandType.none)
                continue;

            const name = "o"~j.to!string;
            main.put('\t');
            final switch(op_t) with(Instruction.OperandType)
            {
                case none:   assert(false);
                case _infer: assert(false);
                case _label: assert(false);
                case _m:     assert(false);
                case r8:     main.put("R8"); break;
                case r16:    main.put("R16"); break;
                case r32:    main.put("R32"); break;
                case r64:    main.put("R64"); break;
                case imm8:   main.put("Imm8"); break;
                case imm16:  main.put("Imm16"); break;
                case imm32:  main.put("Imm32"); break;
                case imm64:  main.put("Imm64"); break;
                case m8:     main.put("Mem"); break;
                case m16:    main.put("Mem"); break;
                case m32:    main.put("Mem"); break;
                case m64:    main.put("Mem"); break;
                case rm8:    main.put("RM8"); break;
                case rm16:   main.put("RM16"); break;
                case rm32:   main.put("RM32"); break;
                case rm64:   main.put("RM64"); break;
            }

            main.put(' ');
            main.put(name);
            main.put(";\n");
        }
        main.put("\tthis(ExpressionNode2[] params) {\n");
            main.put("\t\tthis.rex = Instruction.Rex."~inst.rex.to!string~";\n");
            foreach(j, op_t; [inst.o1_t, inst.o2_t, inst.o3_t])
            {
                if(op_t == Instruction.OperandType.none)
                    continue;

                const name = "o"~j.to!string;
                main.put("\t\t");
                final switch(op_t) with(Instruction.OperandType)
                {
                    case none:   assert(false);
                    case _infer: assert(false);
                    case _label: assert(false);
                    case _m:     assert(false);
                    case r8:     main.put("tryGetReg!8(params["~j.to!string~"], this."~name~")"); break;
                    case r16:    main.put("tryGetReg!16(params["~j.to!string~"], this."~name~")"); break;
                    case r32:    main.put("tryGetReg!32(params["~j.to!string~"], this."~name~")"); break;
                    case r64:    main.put("tryGetReg!64(params["~j.to!string~"], this."~name~")"); break;
                    case imm8:   main.put("tryGetImm!byte(params["~j.to!string~"], this."~name~")"); break;
                    case imm16:  main.put("tryGetImm!short(params["~j.to!string~"], this."~name~")"); break;
                    case imm32:  main.put("tryGetImm!int(params["~j.to!string~"], this."~name~")"); break;
                    case imm64:  main.put("tryGetImm!long(params["~j.to!string~"], this."~name~")"); break;
                    case m8:     main.put("tryGetMem(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case m16:    main.put("tryGetMem(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case m32:    main.put("tryGetMem(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case m64:    main.put("tryGetMem(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case rm8:    main.put("tryGetRegMem!8(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case rm16:   main.put("tryGetRegMem!16(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case rm32:   main.put("tryGetRegMem!32(params["~j.to!string~"], this."~name~", this.rex)"); break;
                    case rm64:   main.put("tryGetRegMem!64(params["~j.to!string~"], this."~name~", this.rex)"); break;
                }
                main.put(";\n");
            }
        main.put("\t}\n");
        main.put("\tvoid putIntoBytes(ref ByteStream bytes, ref IRState state) {\n");
            main.put("\t\tbytes.putInstruction!([");
                foreach(op_e; [inst.o1_e, inst.o2_e, inst.o3_e])
                    main.put("Instruction.OperandEncoding."~op_e.to!string~", ");
            main.put("])(state, ");
                main.put("Prefix.none, ");
                main.put("G2Prefix."~inst.p_g2.to!string~", ");
                main.put("G3Prefix."~inst.p_g3.to!string~", ");
                main.put("G4Prefix."~inst.p_g4.to!string~", ");
                main.put("this.rex, ");
                main.put("Instruction.RegType."~inst.reg_t.to!string);
                main.put(", [");
                ubyte[3] opcodes = [inst.op_1, inst.op_2, inst.op_3];
                ubyte[] codes = opcodes[$-inst.op_c..$];
                foreach(c; codes)
                    main.put("cast(ubyte)0x"~c.to!string(16)~", ");
                main.put("], ");
                foreach(j, op_t; [inst.o1_t, inst.o2_t, inst.o3_t])
                {
                    if(op_t == Instruction.OperandType.none)
                        continue;
                    main.put("o"~j.to!string);
                    main.put(", ");
                }
            main.put(");");
        main.put("\t}\n");
    main.put("}\n");
}
module jupiter.assembler.ir;

import std, jupiter.assembler;

struct OpIr
{
    Instruction inst;
    const(Expression)*[3] arg;
}

struct DbIr
{
    const(Expression)*[] args;
}

struct LabelIr
{
    string name;
}

alias Ir = SumType!(OpIr, LabelIr, DbIr);

struct IrResult
{
    string[]        globals;
    string[]        externs;
    Ir[][string]    irBySection;
    string          currSection;
    
    ref Ir[] getSectionIr()
    {
        if(auto ptr = currSection in irBySection)
            return *ptr;
        irBySection[currSection] = null;
        return irBySection[currSection];
    }
}

IrResult ir(const Node[] ast)
{
    IrResult ret;
    ret.currSection = ".text";
    foreach(node; ast)
        astToIr(ret, node);

    return ret;
}

private:

void astToIr(ref IrResult ret, const Node node)
{
    node.match!(
        (const LabelNode n)
        {
            ret.getSectionIr() ~= Ir(LabelIr(n.token.slice));
        },
        (const DirectiveNode n)
        {
            switch(n.token.slice)
            {
                case "@global":
                    enforce(n.args.length == 1, "Expected 1 argument for global directive.%s".format(n.token));
                    const value = n.args[0].expectLabel;
                    ret.globals ~= value;
                    break;
                case "@extern":
                    enforce(n.args.length == 1, "Expected 1 argument for extern directive.%s".format(n.token));
                    const value = n.args[0].expectLabel;
                    ret.externs ~= value;
                    break;
                case "@section":
                    enforce(n.args.length == 1, "Expected 1 argument for section directive.%s".format(n.token));
                    const value = n.args[0].expectLabel;
                    ret.currSection = value;
                    break;

                default: 
                    throw new Exception("Unsupported directive.\n%s".format(n.token));
            }
        },
        (const OpNode n)
        {
            if(n.mneumonic == Mneumonic.db)
            {
                ret.getSectionIr() ~= Ir(DbIr(cast(const(Expression)*[])n.args));
                return;
            }

            auto allOfMneumonic = INSTRUCTIONS.filter!(i => i.mneumonic == n.mneumonic);
            const info = getArgInfo(n);

            Nullable!Instruction matched;
            foreach(inst; allOfMneumonic)
            {
                const inferredInfo = inferTypes(info, inst);
                Instruction.OperandType[3] types = [
                    inferredInfo[0].type,
                    inferredInfo[1].type,
                    inferredInfo[2].type,
                ];
                const SizeType[3] sizes = [
                    inferredInfo[0].size,
                    inferredInfo[1].size,
                    inferredInfo[2].size,
                ];

                if(inst.op_s == sizes && inst.op_t[].equal!"(a & b) > 0 || a == b"(types[]))
                {
                    matched = cast()inst;
                    break;
                }
            }

            enforce(
                !matched.isNull, 
                format!"Could not match opcode form: %s %s(%s), %s(%s), %s(%s)\n%s\nAvailable forms are:%s"
                (
                    n.mneumonic,
                    info[0].type, info[0].size,
                    info[1].type, info[1].size,
                    info[2].type, info[2].size,
                    n.token,
                    allOfMneumonic
                        .map!(i => 
                            format!"%s %s(%s), %s(%s), %s(%s)"
                            (
                                i.mneumonic,
                                i.op_t[0], i.op_s[0],
                                i.op_t[1], i.op_s[1],
                                i.op_t[2], i.op_s[2],
                            )
                        )
                        .fold!((a,b)=>a~"\n\t"~b)("")
                )
            );

            const(Expression)*[3] retArgs;
            foreach(i, arg; n.args)
                retArgs[i] = arg;
            ret.getSectionIr() ~= Ir(OpIr(matched.get, retArgs));
        }
    );
}

struct ArgInfo
{
    Instruction.OperandType type;
    SizeType size;
}

ArgInfo[3] inferTypes(const ArgInfo[3] init, const Instruction inst)
{
    typeof(return) ret;

    foreach(i, info; init)
    {
        ret[i].type = info.type;
        ret[i].size = info.size;

        if(info.size == SizeType.infer)
            ret[i].size = inst.op_s[i];
    }

    return ret;
}

ArgInfo[3] getArgInfo(const OpNode n)
{
    typeof(return) ret;

    enforce(n.args.length <= 3, "Opcodes cannot have more than 3 arguments.\n%s".format(n.token));
    foreach(i, arg; n.args)
    {
        if(arg.kind != arg.Kind.value)
        {
            ret[i].type = Instruction.OperandType.imm;
            continue;
        }

        arg.value.match!(
            (const StringValue v) 
            {
                enforce(v.token.slice, 
                    "When used as an opcode argument, strings can only contain one character.\n%s"
                    .format(v.token)
                );
                ret[i].type = Instruction.OperandType.imm; 
            },
            (const LabelValue v)
            {
                ret[i].type = Instruction.OperandType.imm;
            },
            (const NumberValue v)
            {
                ret[i].type = Instruction.OperandType.imm;
            },
            (const RegisterValue v)
            {
                ret[i].type = Instruction.OperandType.r;
                ret[i].size = v.reg.size;
            },
            (const IndirectExpression v)
            {
                ret[i].type = Instruction.OperandType.mem;
            }
        );
    }

    if(n.size != SizeType.infer)
    {
        foreach(ref v; ret)
        {
            if(v.size == SizeType.infer)
                v.size = n.size;
        }
    }

    return ret;
}
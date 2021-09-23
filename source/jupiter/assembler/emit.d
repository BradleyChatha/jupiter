module jupiter.assembler.emit;

import std, jupiter.assembler;

struct AddressingExpression
{
    enum Kind
    {
        FAILSAFE,
        direct,

        _base = 1 << 1,
        _index = 1 << 2,
        _disp = 1 << 3,
        _scale = 1 << 4,

        base                = _base,
        baseIndex           = _base | _index,
        baseDisp            = _base | _disp,
        baseIndexDisp       = _base | _index | _disp,
        baseIndexScale      = _base | _index | _scale,
        indexScaleDisp      = _index | _scale | _disp,
        baseIndexScaleDisp  = _base | _index | _scale | _disp
    }

    Kind kind;
    Token token;

    Expression* direct;
    struct {
        Register base;
        Register index;
        const(Expression)* disp;
        ubyte scale; // 2, 4, or 8
    }
}

struct EmitResult
{
    static struct LabelDef
    {
        string name;
        string section;
        size_t offsetInSection;
    }

    static struct ExpressionDep
    {
        Instruction inst;
        const(Expression)* exp;
        string section;
        size_t offsetInSection;
        size_t byteCount;
    }

    Appender!(ubyte[])[string] bytesBySection;
    LabelDef[string] labelDefs;
    ExpressionDep[] expressions;
    string currSection;
    IrResult irResult;

    ref Appender!(ubyte[]) getSectionBytes()
    {
        if(auto ptr = currSection in bytesBySection)
            return *ptr;
        bytesBySection[currSection] = Appender!(ubyte[]).init;
        return bytesBySection[currSection];
    }
}

EmitResult emit(const IrResult res)
{
    EmitResult ret;
    ret.irResult = cast()res;

    foreach(section, ir; res.irBySection)
    {
        ret.currSection = section;
        emitSection(ret, ir);
    }

    return ret;
}

private:

void emitSection(ref EmitResult res, const Ir[] sectionIr)
{
    foreach(ir; sectionIr)
    {
        ir.match!(
            (const OpIr op)
            {
                emitOp(res, op);
            },
            (const LabelIr label)
            {
                res.labelDefs[label.name] = EmitResult.LabelDef(
                    label.name,
                    res.currSection,
                    res.getSectionBytes().data.length
                );
            },
            (const DbIr ir)
            {
            }
        );
    }
}

void emitOp(ref EmitResult res, const OpIr op)
{
    ubyte[4]                prefixes;
    size_t                  prefixCount;
    Instruction.Rex         rex;
    ubyte                   modrm, sib;
    long                    disp;
    long                    imm_v;
    size_t                  dispBytes, immBytes;
    const(Expression)*      dispExp, immExp;
    bool                    hasModrm, hasDisp, hasImm;

    scope bytes = &res.getSectionBytes();

    // Add predefined info
    rex = op.inst.rex;
    if(op.inst.reg_t != Instruction.RegType.r)
        modrm |= (cast(ubyte)op.inst.reg_t << 3);

    if(op.inst.p_g2 != G2Prefix.none)
        prefixes[prefixCount++] = cast(ubyte)op.inst.p_g2;
    if(op.inst.p_g3 != G3Prefix.none)
        prefixes[prefixCount++] = cast(ubyte)op.inst.p_g3;
    if(op.inst.p_g4 != G4Prefix.none)
        prefixes[prefixCount++] = cast(ubyte)op.inst.p_g4;

    // Figure out modrm and SIB, and disp... and imm
    foreach(i, encoding; op.inst.op_e) with(Instruction.OperandEncoding)
    {
        void addIndex(AddressingExpression exp)
        {
            enforce(exp.base.size == SizeType.infer || exp.base.size == exp.index.size, "The base and index are different bit-width registers.\n%s".format(
                exp.token
            ));

            if(exp.base.size == SizeType.s32)
                prefixes[prefixCount++] = cast(ubyte)G4Prefix.addrSize;

            modrm |= 0b00_000_100; // SIB
            sib |= exp.base.regNum;
            sib |= exp.index.regNum << 3;

            if(exp.index.cat >= Register.Category.r8)
                rex |= Instruction.Rex.x;
            if(exp.base.cat >= Register.Category.r8)
                rex |= Instruction.Rex.b;
        }

        void addDisp(AddressingExpression exp)
        {
            hasDisp = true;
            dispExp = exp.disp;

            if(exp.base.size == SizeType.s32)
                prefixes[prefixCount++] = cast(ubyte)G4Prefix.addrSize;

            modrm |= 0b10_000_000; // [reg] + disp32
            dispBytes = 4;
        }

        void addScale(AddressingExpression exp)
        {
            if(exp.scale == 2) sib |= 0b01_000_000;
            if(exp.scale == 4) sib |= 0b10_000_000;
            if(exp.scale == 8) sib |= 0b11_000_000;
        }

        final switch(encoding)
        {
            case add: assert(false, "TODO");
            case none: break;

            case Instruction.OperandEncoding.imm:
                immExp = op.arg[i];
                immBytes = cast(size_t)op.inst.op_s[i];
                hasImm = true;
                break;

            case rm_rm: 
                hasModrm = true; // edge case: Modrm can still be 0 sometimes.
                if(isRegister(op.arg[i]))
                {
                    modrm |= 0b11_000_000; // Not an indirect address.
                    modrm |= getRegValue(op.arg[i]).regNum;
                    break;
                }

                auto exp = decompose(getIndirect(op.arg[i]));
                enforce(
                    exp.base == Register.init || exp.base.size >= SizeType.s32, 
                    "Only 32-bit and 64-bit registers can be used as the base in indirect expressions.\n%s".format(
                        exp.token
                    )
                );
                enforce(
                    exp.index == Register.init || exp.index.size >= SizeType.s32, 
                    "Only 32-bit and 64-bit registers can be used as the index in indirect expressions.\n%s".format(
                        exp.token
                    )
                );
                switch(exp.kind) with(AddressingExpression.Kind)
                {
                    case base:
                        enforce(
                            exp.base.cat != Register.Category.rsp, 
                            "The stack pointer register cannot be used in an indirect expression.\n%s".format(
                                exp.token
                            )
                        );
                        enforce(
                            exp.base.cat != Register.Category.rbp, 
                            "The base pointer register can only be used in an indirect expression if it also contains a displacement. Perhaps try [bp + 0].\n%s".format(
                                exp.token
                            )
                        );
                        modrm |= exp.base.regNum;
                        if(exp.base.cat >= exp.base.Category.r8)
                            rex |= Instruction.Rex.b;
                        break;

                    case direct:
                        modrm = 0b000_000_100; // Has a SIB
                        sib   = 0b000_100_101; // Disp as base, no index

                        dispExp = exp.direct;
                        dispBytes = 4;
                        hasDisp = true;
                        break;

                    case baseIndex:
                        addIndex(exp);
                        break;

                    case baseDisp:
                        addDisp(exp);
                        modrm |= exp.base.regNum;
                        break;

                    case baseIndexDisp:
                        addIndex(exp);
                        addDisp(exp);
                        break;

                    case baseIndexScale:
                        addIndex(exp);
                        addScale(exp);
                        break;

                    case indexScaleDisp:
                        addIndex(exp);
                        addScale(exp);
                        addDisp(exp);
                        // Force scaled index + disp32 mode.
                        dispBytes = 4;
                        modrm &= 0b00_111_111;
                        sib |= 0b00_000_101;
                        break;

                    case baseIndexScaleDisp:
                        addIndex(exp);
                        addScale(exp);
                        addDisp(exp);
                        break;

                    default: throw new Exception("Currently can't handle indirect expression: "~exp.to!string);
                }
                break;

            case rm_reg:
                const reg = getRegValue(op.arg[i]);
                modrm |= reg.regNum << 3;
                if(reg.cat >= Register.Category.r8)
                    rex |= Instruction.Rex.r;
                break;
        }
    }

    // output bytes
    bytes.put(prefixes[0..prefixCount]);
    if(rex != Instruction.Rex.none)
    {
        rex |= 0b0100_0000;
        bytes.put(cast(ubyte)rex);
    }
    bytes.put(op.inst.op);
    if(modrm != 0 || hasModrm)
        bytes.put(modrm);
    if(sib != 0)
        bytes.put(sib);
    if(hasDisp)
    {
        assert(dispExp);
        res.expressions ~= EmitResult.ExpressionDep(
            cast()op.inst,
            dispExp,
            res.currSection,
            bytes.data.length,
            dispBytes
        );
        bytes.put(nativeToLittleEndian(disp)[0..dispBytes]);
    }
    if(hasImm)
    {
        assert(immExp);
        res.expressions ~= EmitResult.ExpressionDep(
            cast()op.inst,
            immExp,
            res.currSection,
            bytes.data.length,
            immBytes
        );
        bytes.put(nativeToLittleEndian(imm_v)[0..immBytes]);
    }
}

AddressingExpression decompose(IndirectExpression exp)
{
    typeof(return) ret;
    ret.token = exp.token;

    if(exp.exp.kind == Expression.Kind.value)
    {
        exp.exp.value.match!(
            (RegisterValue v){ ret.kind = AddressingExpression.Kind.base; ret.base = v.reg; },
            (_) { ret.kind = AddressingExpression.Kind.direct; ret.direct = exp.exp; }
        );
        return ret;
    }

    exp.exp.eachExpression((e)
    {
        if(!(ret.kind & ret.Kind._base) && !(ret.kind & ret.Kind._index) && !(ret.kind & ret.Kind._disp))
        {
            if(e.left.kind != Expression.Kind.value)
            {
                ret.disp = e.right;
                ret.kind |= ret.Kind._disp;
            }
            else if(e.kind == Expression.Kind.add)
            {
                ret.base = getRegValue(e.left);
                ret.kind |= ret.Kind._base;

                if(isRegister(e.right))
                {
                    ret.index = getRegValue(e.right);
                    ret.kind |= ret.Kind._index;
                }
            }
            else if(e.kind == Expression.Kind.mul)
            {
                ret.index = getRegValue(e.left);
                ret.kind |= ret.Kind._index;
            }
            else throw new Exception("Expected addition or multiplication on base/index register.\n%s".format(e.token));
        }
        else if(!(ret.kind & ret.Kind._index) && isRegister(e.left))
        {
            if(e.kind == Expression.kind.mul)
            {
                ret.index = getRegValue(e.left);
                ret.scale = getNumber(e.right).token.slice.to!ubyte;
                ret.kind |= ret.Kind._index | ret.Kind._scale;
            }
            else if(e.kind == Expression.kind.add)
            {
                ret.index = getRegValue(e.left);
                ret.disp = e.right;
                ret.kind |= ret.Kind._index | ret.Kind._disp;
            }
            else throw new Exception("Expected addition or multiplication on index register.\n%s".format(e.token));
        }
        else if(!(ret.kind & ret.Kind._disp) && e.kind == Expression.kind.add)
        {
            ret.disp = e;
            ret.kind |= ret.Kind._disp;
        }
    });

    return ret;
}

bool isRegister(const Expression* exp)
{
    return 
    exp.kind == Expression.Kind.value 
    && exp.value.match!(
        (RegisterValue _) => true,
        (_) => false
    );
}

Register getRegValue(const Expression* exp)
{
    enforce(exp.kind == Expression.Kind.value, "Expected a value, not a complex expression.\n%s".format(exp.token));

    Register ret;
    exp.value.match!(
        (const RegisterValue v) { ret = v.reg; },
        (_) { throw new Exception("Expected a register value.\n%s".format(exp.token)); }
    );
    return ret;
}

IndirectExpression getIndirect(const Expression* exp)
{
    enforce(exp.kind == Expression.Kind.value, "Expected a value, not a complex expression.\n%s".format(exp.token));

    IndirectExpression ret;
    exp.value.match!(
        (const IndirectExpression v) { ret = cast()v; },
        (_) { throw new Exception("Expected an indirect expression value.\n%s".format(exp.token)); }
    );
    return ret;
}

NumberValue getNumber(const Expression* exp)
{
    enforce(exp.kind == Expression.Kind.value, "Expected a value, not a complex expression.\n%s".format(exp.token));

    NumberValue ret;
    exp.value.match!(
        (const NumberValue v) { ret = cast()v; },
        (_) { throw new Exception("Expected a numeric value.\n%s".format(exp.token)); }
    );
    return ret;
}
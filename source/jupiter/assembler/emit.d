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

    static struct LabelDependency
    {
        Instruction inst;
        const(Expression)* exp;
        string section;
        size_t offsetInSection;
    }

    Appender!(ubyte[])[string] bytesBySection;
    LabelDef[string] labelDefs;
    LabelDependency[] labelDeps;
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

unittest
{
    const file  = "views/test/test.asm";
    const nodes = syntax1(preprocess(file), file);
    const irres = ir(nodes);
    auto emitted = emit(irres);
    std.file.write("raw.bin", emitted.getSectionBytes().data);
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
    bool                    hasModrm, hasDisp, hasImm, dispNeedsLabel, immNeedsLabel;

    scope bytes = &res.getSectionBytes();

    // Add predefined info
    rex = op.inst.rex;
    if(op.inst.reg_t != Instruction.RegType.r)
        modrm |= (cast(ubyte)op.inst.reg_t << 3);

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
        }

        void addDisp(AddressingExpression exp)
        {
            hasDisp = true;
            disp = solve(exp.disp, dispNeedsLabel);
            if(dispNeedsLabel)
            {
                disp = 0;
                dispBytes = 4;
                return;
            }

            if(exp.base.size == SizeType.s32)
                prefixes[prefixCount++] = cast(ubyte)G4Prefix.addrSize;

            if(disp <= ubyte.max)
            {
                modrm |= 0b01_000_000; // [reg] + disp8
                dispBytes = 1;
            }
            else
            {
                modrm |= 0b10_000_000; // [reg] + disp32
                dispBytes = 4;
            }
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
                imm_v = solve(op.arg[i], immNeedsLabel);
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
                        break;

                    case direct: assert(false, "TODO");

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
                modrm |= getRegValue(op.arg[i]).regNum << 3;
                break;
        }
    }

    // output bytes
    bytes.put(prefixes[0..prefixCount]);
    if(rex != Instruction.Rex.none)
        bytes.put(cast(ubyte)rex);
    bytes.put(op.inst.op);
    if(modrm != 0 || hasModrm)
        bytes.put(modrm);
    if(sib != 0)
        bytes.put(sib);
    if(hasDisp)
        bytes.put(nativeToLittleEndian(disp)[0..dispBytes]);
    if(hasImm)
        bytes.put(nativeToLittleEndian(imm_v)[0..immBytes]);
}

long solve(const(Expression)* exp, ref bool requiresLabel)
{
    if(requiresLabel)
        return 0;

    if(exp.kind == Expression.Kind.value)
    {
        long ret;
        exp.value.match!(
            (NumberValue v) { ret = v.token.slice.to!long; },
            (LabelValue v) { requiresLabel = true; },
            (_) { throw new Exception("Don't know how to convert %s into a numeric value.".format(_)); }
        );
        return ret;
    }

    switch(exp.kind) with(Expression.Kind)
    {
        case add:
            return solve(exp.left, requiresLabel) + solve(exp.right, requiresLabel);

        case mul:
            return solve(exp.left, requiresLabel) * solve(exp.right, requiresLabel);

        default: assert(false);
    }
}

// NOTE: Only call just before we write the Disp bytes, not any earlier, not any sooner.
void addLabelDeps(ref EmitResult res, const Instruction inst, const(Expression)* exp)
{
    exp.eachValue((v)
    {
        v.match!(
            (LabelValue v)
            {
                res.labelDeps ~= EmitResult.LabelDependency(
                    cast()inst,
                    exp,
                    res.currSection,
                    res.getSectionBytes().data.length
                );
            },
            (_){}
        );
    });
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
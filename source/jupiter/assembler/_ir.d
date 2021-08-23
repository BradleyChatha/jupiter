module jupiter.assembler._ir;

import jupiter.assembler, std, std.sumtype : match;

Imm8 expImm8(Expression ex)
{ 
    Imm8 ret; 
    ex.match!(
        (StringExpression str) 
        { 
            ret = Imm8(cast(ubyte)str.str[0]); 
        }, 
        (NumberExpression num)
        { 
            ret = Imm8(num.asInt.to!ubyte); 
        }, 
        (_){ assert(false); }
    ); 
    return ret;
}
Imm16 expImm16(Expression ex)
{ 
    Imm16 ret; 
    ex.match!(
        (StringExpression str) 
        { 
            ret = Imm16(cast(short)str.str[0]); 
        }, 
        (NumberExpression num)
        { 
            ret = Imm16(num.asInt.to!short); 
        }, 
        (_){ assert(false); }
    ); 
    return ret;
}
Imm32 expImm32(Expression ex)
{ 
    Imm32 ret; 
    ex.match!(
        (StringExpression str) 
        { 
            ret = Imm32(cast(int)str.str[0]); 
        }, 
        (NumberExpression num)
        { 
            ret = Imm32(num.asInt.to!int); 
        }, 
        (_){ assert(false); }
    ); 
    return ret;
}
Imm64 expImm64(Expression ex)
{ 
    Imm64 ret; 
    ex.match!(
        (StringExpression str) 
        { 
            ret = Imm64(cast(long)str.str[0]); 
        }, 
        (NumberExpression num)
        { 
            ret = Imm64(num.asInt.to!long); 
        }, 
        (_){ assert(false); }
    ); 
    return ret;
}
RM8 expRM8(Expression ex)
{
    RM8 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            auto r = R8(reg.reg);
            r.validate();
            ret = RM8(r);
        },
        (_){ assert(false); }
    );
    return ret;
}
RM16 expRM16(Expression ex)
{
    RM16 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            auto r = R16(reg.reg);
            r.validate();
            ret = RM16(r);
        },
        (_){ assert(false); }
    );
    return ret;
}
RM32 expRM32(Expression ex)
{
    RM32 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            auto r = R32(reg.reg);
            r.validate();
            ret = RM32(r);
        },
        (_){ assert(false); }
    );
    return ret;
}
RM64 expRM64(Expression ex)
{
    RM64 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            auto r = R64(reg.reg);
            r.validate();
            ret = RM64(r);
        },
        (_){ assert(false); }
    );
    return ret;
}
R8 expR8(Expression ex)
{
    R8 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            ret = R8(reg.reg);
            ret.validate();
        },
        (_){ assert(false); }
    );
    return ret;
}
R16 expR16(Expression ex)
{
    R16 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            ret = R16(reg.reg);
            ret.validate();
        },
        (_){ assert(false); }
    );
    return ret;
}
R32 expR32(Expression ex)
{
    R32 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            ret = R32(reg.reg);
            ret.validate();
        },
        (_){ assert(false); }
    );
    return ret;
}
R64 expR64(Expression ex)
{
    R64 ret;
    ex.match!(
        (RegisterExpression reg)
        {
            ret = R64(reg.reg);
            ret.validate();
        },
        (_){ assert(false); }
    );
    return ret;
}
struct add_rm8_i8
{
	static immutable Instruction inst = INSTRUCTIONS[0];
	RM8 o0;
	Imm8 o1;
	this(Expression[] args) {
		o0 = expRM8(args[0]);		o1 = expImm8(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		modrm |= 0 << 3;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x80);
		if(outMod){
			this.o0.match!((R8 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
		output.put(this.o1.bytes[]);
	}

}
struct add_rm16_i16
{
	static immutable Instruction inst = INSTRUCTIONS[1];
	RM16 o0;
	Imm16 o1;
	this(Expression[] args) {
		o0 = expRM16(args[0]);		o1 = expImm16(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		modrm |= 0 << 3;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x81);
		if(outMod){
			this.o0.match!((R16 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
		output.put(this.o1.bytes[]);
	}

}
struct add_rm32_i32
{
	static immutable Instruction inst = INSTRUCTIONS[2];
	RM32 o0;
	Imm32 o1;
	this(Expression[] args) {
		o0 = expRM32(args[0]);		o1 = expImm32(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		modrm |= 0 << 3;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x81);
		if(outMod){
			this.o0.match!((R32 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
		output.put(this.o1.bytes[]);
	}

}
struct add_rm64_i32
{
	static immutable Instruction inst = INSTRUCTIONS[3];
	RM64 o0;
	Imm32 o1;
	this(Expression[] args) {
		o0 = expRM64(args[0]);		o1 = expImm32(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outRex = true; rex |= 8;
		outMod = true;
		modrm |= 0 << 3;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x81);
		if(outMod){
			this.o0.match!((R64 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
		output.put(this.o1.bytes[]);
	}

}
struct add_rm8_r8
{
	static immutable Instruction inst = INSTRUCTIONS[4];
	RM8 o0;
	R8 o1;
	this(Expression[] args) {
		o0 = expRM8(args[0]);		o1 = expR8(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(this.o1.value.cat >= Register.Category.r8) {
			outRex = true;
			rex |= Instruction.Rex.r;
		}
		outMod = true;
		modrm |= this.o1.value.regNum << 3;
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x0);
		if(outMod){
			this.o0.match!((R8 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
	}

}
struct add_rm16_r16
{
	static immutable Instruction inst = INSTRUCTIONS[5];
	RM16 o0;
	R16 o1;
	this(Expression[] args) {
		o0 = expRM16(args[0]);		o1 = expR16(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(this.o1.value.cat >= Register.Category.r8) {
			outRex = true;
			rex |= Instruction.Rex.r;
		}
		outMod = true;
		modrm |= this.o1.value.regNum << 3;
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x1);
		if(outMod){
			this.o0.match!((R16 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
	}

}
struct add_rm32_r32
{
	static immutable Instruction inst = INSTRUCTIONS[6];
	RM32 o0;
	R32 o1;
	this(Expression[] args) {
		o0 = expRM32(args[0]);		o1 = expR32(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(this.o1.value.cat >= Register.Category.r8) {
			outRex = true;
			rex |= Instruction.Rex.r;
		}
		outMod = true;
		modrm |= this.o1.value.regNum << 3;
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x1);
		if(outMod){
			this.o0.match!((R32 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
	}

}
struct add_rm64_r64
{
	static immutable Instruction inst = INSTRUCTIONS[7];
	RM64 o0;
	R64 o1;
	this(Expression[] args) {
		o0 = expRM64(args[0]);		o1 = expR64(args[1]);
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		outRex = true; rex |= 8;
		outMod = true;
		this.o0.match!(
            (reg) { modrm |= reg.value.regNum; if(reg.value.type == Instruction.OperandType.r64) { outRex = true; rex |= Instruction.Rex.b; } },
            (_) { assert(false); }
        );
		if(this.o1.value.cat >= Register.Category.r8) {
			outRex = true;
			rex |= Instruction.Rex.r;
		}
		outMod = true;
		modrm |= this.o1.value.regNum << 3;
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0x1);
		if(outMod){
			this.o0.match!((R64 _) { modrm |= 0b1100_0000; }, (_) { assert(false); });
			output.put(modrm);
		}
	}

}
struct retn
{
	static immutable Instruction inst = INSTRUCTIONS[8];
	this(Expression[] args) {
	}
	void pushBytes(R)(ref R output, ref IRState state){
		ubyte rex = 0b0100_0000;
		ubyte modrm;
		bool outRex, outMod;
		if(outRex) output.put(rex);
		output.put(cast(ubyte)0xC3);
		if(outMod){
			output.put(modrm);
		}
	}

}
alias ALL_IR = AliasSeq!(
	add_rm8_i8,
	add_rm16_i16,
	add_rm32_i32,
	add_rm64_i32,
	add_rm8_r8,
	add_rm16_r16,
	add_rm32_r32,
	add_rm64_r64,
	retn,
);

module jupiter.assembler._ir;

import jupiter.assembler, std;
struct add_rm8_i8 {
	Instruction.Rex rex;
	RM8 o0;
	Imm8 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!8(params[0], this.o0, this.rex);
		tryGetImm!byte(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.imm, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.reg0, [cast(ubyte)0x80, ], o0, o1, );	}
}
struct add_rm16_i16 {
	Instruction.Rex rex;
	RM16 o0;
	Imm16 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!16(params[0], this.o0, this.rex);
		tryGetImm!short(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.imm, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.reg0, [cast(ubyte)0x81, ], o0, o1, );	}
}
struct add_rm32_i32 {
	Instruction.Rex rex;
	RM32 o0;
	Imm32 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!32(params[0], this.o0, this.rex);
		tryGetImm!int(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.imm, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.reg0, [cast(ubyte)0x81, ], o0, o1, );	}
}
struct add_rm64_i32 {
	Instruction.Rex rex;
	RM64 o0;
	Imm32 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.w;
		tryGetRegMem!64(params[0], this.o0, this.rex);
		tryGetImm!int(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.imm, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.reg0, [cast(ubyte)0x81, ], o0, o1, );	}
}
struct add_rm8_r8 {
	Instruction.Rex rex;
	RM8 o0;
	R8 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!8(params[0], this.o0, this.rex);
		tryGetReg!8(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.rm_reg, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.r, [cast(ubyte)0x0, ], o0, o1, );	}
}
struct add_rm16_r16 {
	Instruction.Rex rex;
	RM16 o0;
	R16 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!16(params[0], this.o0, this.rex);
		tryGetReg!16(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.rm_reg, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.opSize, G4Prefix.none, this.rex, Instruction.RegType.r, [cast(ubyte)0x1, ], o0, o1, );	}
}
struct add_rm32_r32 {
	Instruction.Rex rex;
	RM32 o0;
	R32 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
		tryGetRegMem!32(params[0], this.o0, this.rex);
		tryGetReg!32(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.rm_reg, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.r, [cast(ubyte)0x1, ], o0, o1, );	}
}
struct add_rm64_r64 {
	Instruction.Rex rex;
	RM64 o0;
	R64 o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.w;
		tryGetRegMem!64(params[0], this.o0, this.rex);
		tryGetReg!64(params[1], this.o1);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.rm_reg, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.r, [cast(ubyte)0x1, ], o0, o1, );	}
}
struct lea_r64_m64 {
	Instruction.Rex rex;
	R64 o0;
	Mem o1;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.w;
		tryGetReg!64(params[0], this.o0);
		tryGetMem(params[1], this.o1, this.rex);
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.rm_reg, Instruction.OperandEncoding.rm_rm, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.r, [cast(ubyte)0x8D, ], o0, o1, );	}
}
struct retn {
	Instruction.Rex rex;
	this(ExpressionNode2[] params) {
		this.rex = Instruction.Rex.none;
	}
	void putIntoBytes(ref ByteStream bytes, ref IRState state) {
		bytes.putInstruction!([Instruction.OperandEncoding.none, Instruction.OperandEncoding.none, Instruction.OperandEncoding.none, ])(state, Prefix.none, G2Prefix.none, G3Prefix.none, G4Prefix.none, this.rex, Instruction.RegType.none, [cast(ubyte)0xC3, ], );	}
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
	lea_r64_m64,
	retn,
);

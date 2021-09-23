module jupiter.assembler.objbin;

import jupiter.assembler, std;

unittest
{
    const file   = "views/test/test.asm";
    const nodes  = syntax1(preprocess(file), file);
    const irres  = ir(nodes);
    auto emitted = emit(irres);
    
    Appender!(ubyte[]) bytes;
    emitBin(emitted, bytes);

    std.file.write("raw.bin", bytes.data);
}

void emitBin(const EmitResult emit, ref Appender!(ubyte[]) bytes)
{
    enforce(!emit.irResult.externs.length, "You cannot use external symbols when outputting a flat binary.");

    // First, write out all the bytes.
    size_t[string] offsetBySection;
    foreach(section, secBytes; emit.bytesBySection)
    {
        offsetBySection[section] = bytes.data.length;
        bytes.put(secBytes.data);
    }

    // Create the absolute positions for all defined labels
    size_t[string] labelOffsetsByName;
    foreach(name, label; emit.labelDefs)
        labelOffsetsByName[name] = offsetBySection[label.section] + label.offsetInSection;

    // Solve and emplace all expressions. 
    foreach(exp; emit.expressions)
    {
        const value      = solve(exp.exp, labelOffsetsByName);
        const valueBytes = value.nativeToLittleEndian();
        const start      = exp.offsetInSection + offsetBySection[exp.section];
        const end        = start + exp.byteCount;
        bytes.data[start..end] = valueBytes[0..exp.byteCount];
    }
}
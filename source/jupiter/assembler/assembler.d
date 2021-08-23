module jupiter.assembler.assembler;

import std, std.sumtype, jupiter.assembler;
import std.sumtype : match;

alias ByteStream = Appender!(ubyte[]);
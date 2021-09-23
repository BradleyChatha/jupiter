module jupiter.assembler.objhelper;

import jupiter.assembler, std;

long solve(const(Expression)* exp, size_t[string] labels)
{
    if(exp.kind == Expression.Kind.value)
    {
        long ret;
        exp.value.match!(
            (StringValue v)
            {
                enforce(
                    v.token.slice.length == 1, 
                    "When used within assembly instructions, strings can only be 1 character long.\n"~v.token.toString()
                );
                ret = cast(long)v.token.slice[0];
            },
            (NumberValue v)
            {
                if(v.token.slice.startsWith("0x"))
                    ret = v.token.slice[2..$].to!long(16);
                else if(v.token.slice.startsWith("0b"))
                    ret = v.token.slice[2..$].to!long(2);
                else
                    ret = v.token.slice.to!long;
            },
            (LabelValue v)
            {
                scope ptr = (v.token.slice in labels);
                enforce(ptr, "Non-extern label '%s' not found.\n%s".format(v.token.slice, v.token));
                ret = cast(long)*ptr;
            },
            (RegisterValue r){},
            (v) { assert(false, "Unexpected: "~v.to!string~" "~typeof(v).stringof); }
        );
        return ret;
    }

    final switch(exp.kind) with(Expression.Kind)
    {
        case add: return solve(exp.left, labels) + solve(exp.right, labels);
        case sub: return solve(exp.left, labels) - solve(exp.right, labels);
        case mul: return solve(exp.left, labels) * solve(exp.right, labels);
        case div: return solve(exp.left, labels) / solve(exp.right, labels);
        case mod: return solve(exp.left, labels) % solve(exp.right, labels);

        case FAILSAFE:
        case value: assert(false);
    }
}
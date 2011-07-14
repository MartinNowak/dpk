import std.stdio;
import std.ascii;
import std.demangle;

void main()
{
    char[] buffer;
    bool inword;

    while (!stdin.eof)
    {
        foreach(c; stdin.readln())
        {
            if (inword)
            {
                if (c == '_' || isAlphaNum(c))
                    buffer ~= c;
                else
                {
                    inword = false;
                    write(demangle(buffer.idup), c);
                }
            }
            else
            {
                if (c == '_' || isAlpha(c))
                {
                    inword = true;
                    buffer.length = 0;
                    buffer ~= c;
                }
                else
                    write(c);
            }
        }
        if (inword)
            writef(demangle(buffer.idup));
    }
}

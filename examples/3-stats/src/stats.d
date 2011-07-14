import statclasses.stats;

import std.exception, std.stdio, std.string;

void main(string[] args) {
  Stat[] stats;
  args = args[1 .. $];

  enforce(args.length, "\nusage: stats fun0 fun1 \n" ~ allowedStats());

  foreach(arg; args)
    stats ~= Stat.create(arg);

  for (double x; readf(" %s ", &x) == 1; ) {
    foreach(st; stats)
      st.accumulate(x);
  }

  foreach(i, st; stats) {
    st.postprocess();
    writefln("%s: %s", args[i], st.result());
  }
}

private string allowedStats() {
  return "available stat functions: " ~ join(Stat.available(), " ");
}

module dpk.dflags;

import std.algorithm, std.array, std.getopt, std.string, std.conv;

struct DFlags {

  this(string[] args) {
    if (!find(args, "-debug").empty)
      this.buildstyle = DFlags.style.dbg;
    if (!find(args, "-release").empty)
      this.buildstyle = DFlags.style.rls;
    if (!find(args, "-m32").empty)
      this.wordsize = 32;
    if (!find(args, "-m64").empty)
      this.wordsize = 64;
    if (!find(args, "-profile").empty)
      this.profile = true;
    if (!find(args, "-cov").empty)
      this.coverage = true;
    if (!find(args, "-gc").empty)
      this.dinfo = DFlags.debuginfo.gc;
    if (!find(args, "-g").empty)
      this.dinfo = DFlags.debuginfo.g;
  }

  @property string suffix() const {
    string result;
    if (this.buildstyle == style.dbg)
      result ~= "_d";
    if (this.profile)
      result ~= "_profile";
    if (this.coverage)
      result ~= "_cov";
    return result;
  }

  enum style { dbg, rls };
  enum debuginfo { no, gc, g };
  style buildstyle = style.rls;
  uint wordsize = 32;
  debuginfo dinfo = debuginfo.no;
  bool profile, coverage;
}

unittest {
  assert(DFlags().suffix == "");
  assert(DFlags(["-debug"]).suffix == "_d");
  assert(DFlags(["-debug", "-m64", "-gc", "-profile", "-cov"]).suffix == "_d_profile_cov");
  assert(DFlags(["-debug", "-cov", "-profile", "-m64", "-gc"]).suffix == "_d_profile_cov");
}

module dpk.dflags;

import std.algorithm, std.array, std.getopt, std.string, std.conv;
import std.stdio;

struct DFlags
{

    this(string[] args, string[] defaults=null)
    {
        string[] scan = defaults;
    Lagain:

        foreach(arg; scan)
        {
            switch (arg)
            {
            case "-debug":
                this.buildstyle = DFlags.style.dbg;
                break;

            case "-release":
                this.buildstyle = DFlags.style.rls;
                break;

            case "-m32":
                this.wordsize = 32;
                break;

            case "-m64":
                this.wordsize = 64;
                break;

            case "-profile":
                this.profile = true;
                break;

            case "-cov":
                this.coverage = true;
                break;

            case "-gc":
                this.dinfo = DFlags.debuginfo.gc;
                break;

            case "-g":
                this.dinfo = DFlags.debuginfo.g;
                break;

            case "-vv":
                this.verbose = 2;
                break;

            case "-v":
                this.verbose = 1;
                break;

            default:
                this.additional ~= arg;
                break;
            }
        }

        if (scan.ptr != args.ptr)
        {
            scan = args;
            goto Lagain;
        }
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

  @property string[] args() const {
      string[] res;
      final switch (buildstyle)
      {
      case style.no: break;
      case style.dbg: res ~= "-debug"; break;
      case style.rls: res ~= "-release"; break;
      }
      switch (wordsize)
      {
      case 32: res ~= "-m32"; break;
      case 64: res ~= "-m64"; break;
      default: assert(0);
      }
      final switch (dinfo)
      {
      case debuginfo.no: break;
      case debuginfo.gc: res ~= "-gc"; break;
      case debuginfo.g: res ~= "-g"; break;
      }
      if (profile)
          res ~= "-profile";
      if (coverage)
          res ~= "-cov";
      switch (verbose)
      {
      case 1: break;
      case 2: res ~= "-v"; break;
      default: break;
      }
      res ~= additional;
      return res;
  }

  enum style { no, dbg, rls };
  enum debuginfo { no, gc, g };
  style buildstyle;
  // TODO: ugly heuristic for dmd default wordsize
  uint wordsize = size_t.sizeof == 8 ? 64 : 32;
  debuginfo dinfo;
  bool profile, coverage;
  uint verbose;
  string[] additional;
}

unittest {
  assert(DFlags().suffix == "");
  assert(DFlags(["-debug"]).suffix == "_d");
  assert(DFlags(["-debug", "-m64", "-gc", "-profile", "-cov"]).suffix == "_d_profile_cov");
  assert(DFlags(["-debug", "-cov", "-profile", "-m64", "-gc"]).suffix == "_d_profile_cov");
  assert(DFlags(["-debug"], ["-release"]).suffix == "_d");
  assert(DFlags(["-m64"], ["-debug"]).suffix == "_d");
  assert(DFlags(["--m64 -release -inline -O"], ["-m64 -debug -gc -w -wi"]).suffix == "");
}

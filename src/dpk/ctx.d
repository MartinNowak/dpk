module dpk.ctx;

import std.algorithm, std.bitmanip, std.functional, std.path, std.process;
import dpk.config, dpk.dflags, dpk.util;

class Ctx {
  string[] args;
  string _prefix;
  string[] _installedPkgs;
  Section _dpkcfg;
  DFlags _dflags;

  mixin(bitfields!(
          bool, "hasprefix", 1,
          bool, "hasinstalledPkgs", 1,
          bool, "hasdpkcfg", 1,
          bool, "hasdflags", 1,
          uint, "", 4,
        ));

  this(string[] args) {
    this.args = args;
  }

  @property string prefix() {
    if (!this.hasprefix) {
      this._prefix = environment.get("PREFIX");
      if (this._prefix is null)
        this._prefix = this.dpkcfg.get("prefix");
      std.stdio.writeln("prefix", this.classinfo.classInvariant);
      this._prefix = std.path.expandTilde(this._prefix);
      this.hasprefix = true;
    }

    return this._prefix;
  }

  @property string[] installedPkgs() {
    if (!this.hasinstalledPkgs) {
      this._installedPkgs = apply!basename(
        resolveGlobs("*.cfg", join(this.prefix, "dpk")));
      this.hasinstalledPkgs = true;
    }

    return this._installedPkgs;
  }

  @property Section dpkcfg() {
    if (!this.hasdpkcfg) {
      this._dpkcfg = parseConfig("/etc/dmd.conf").get("dpk",
        new Exception("Missing [dpk] section in dmd.conf"));
      this.hasdpkcfg = true;
    }

    return this._dpkcfg;
  }

  @property DFlags dflags() {
    if (!this.hasdflags) {
      this._dflags = DFlags(this.args);
      this.hasdflags = true;
    }

    return this._dflags;
  }
}

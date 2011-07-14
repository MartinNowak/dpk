module statclasses.stats;

import std.algorithm, std.exception, std.stdio, std.string;

interface Stat {
  void accumulate(double x);
  void postprocess();
  double result();

  static Stat create(string name) {
    return enforce(
        cast(Stat)Object.factory("statclasses.stats." ~ capitalize(name)),
        "\nInvalid stats function \'" ~ name ~ "\'\n available" ~ join(available(), " "));
  }

  static string[] available() {
    return availableStats();
  }
}

class __IncrementalStat : Stat {
  private double _result;
  void postprocess() {}
  abstract void accumulate(double);
  double result() { return this._result; }
}

class Min : __IncrementalStat {
  this() { this._result = double.max; }
  override void accumulate(double x) { if (x < this._result) this._result = x; }
}

class Max : __IncrementalStat {
  this() { this._result = double.min; }
  override void accumulate(double x) { if (x > this._result) this._result = x; }
}

class Sum : __IncrementalStat {
  this() { this._result = 0.0; }
  override void accumulate(double x) { this._result += x; }
}

class Avg : Sum {
  protected size_t count;
  override void accumulate(double x) { ++this.count; super.accumulate(x); }
  override double result() { return this._result / count; }
}

class Dev : Avg {
  private double sumSq = 0.0;
  override void accumulate(double x) { this.sumSq += x ^^2; super.accumulate(x); }
  override double result() {
    return std.math.sqrt(
        (this.sumSq - 2 * this.Sum.result * this.Avg.result) / super.count
        + this.Avg.result ^^ 2);
  }
}

private:

ModuleInfo* ownModule() {
  foreach(m; ModuleInfo)
    if (m.name == "statclasses.stats")
      return m;
  assert(0);
}

string[] availableStats() {
  string[] classes;
  foreach(c; ownModule().localClasses) {
    auto name = c.name;
    enforce(findSkip(name, "stats."));
    if (!name.startsWith("__"))
      classes ~= name;
  }
  return classes;
}

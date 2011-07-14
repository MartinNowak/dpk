module test.test_stats;

import statclasses.stats;
import std.algorithm, std.math, std.range;

void testStat(S)(double[] input, double expected) {
  scope auto s = new S;
  foreach(v; input)
    s.accumulate(v);
  s.postprocess();
  assert(s.result() == expected);
}

unittest {
  auto input = [2.0, 3.0, -4.0];
  testStat!(Min)(input, -4.0);
  testStat!(Max)(input, 3.0);
  testStat!(Sum)(input, 1.0);
  testStat!(Avg)(input, 1.0 / 3.0);
  auto squares = map!q{(a - 1.0 / 3.0) ^^ 2}(input);
  testStat!(Dev)(input, sqrt(reduce!q{a+b}(squares) / squares.length));

  assert(!Stat.available().empty);
  assert(Stat.create("min") !is null);
}

void main() {
}

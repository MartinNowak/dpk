module dpk.util;

import std.array, std.exception, std.file, std.format, std.functional, std.path, std.regex, std.string;

string fmtString(Args...)(string fmt, Args args) {
  auto app = appender!string();
  formattedWrite(app, fmt, args);
  return app.data;
}

Range apply(alias fun, Range)(Range range) {
  foreach(ref elem; range)
    elem = fun(elem);
  return range;
}

void execCmd(string cmd) {
  enforce(!std.process.system(cmd),
    new Exception(fmtString("Error executing cmd: \n\n %s", cmd)));
}

void execCmdInDir(string cmd, string dir) {
  auto dc = DirChanger(dir);

  execCmd(cmd);
}

string[] resolveGlobs(alias pred=unaryFun!(q{a.isFile}))(string globs, string root = std.path.curdir) {
  auto dc = DirChanger(root);

  string[] result;
  foreach(glob; splitter(globs)) {
    auto matcher = reMatcher(glob);
    foreach(DirEntry de; dirEntries(std.path.curdir, SpanMode.depth)) {
      if (pred(de) && !match(de.name, matcher).empty) {
        result ~= de.name;
      }
    }
  }
  return result;
}

struct DirChanger {
  string olddir;
  this(string newdir) {
    this.olddir = std.file.getcwd();
    std.file.chdir(newdir);
  }
  ~this() { std.file.chdir(this.olddir); }
}

private:

auto reMatcher(string dpkmatcher) {
  enum string seps = std.path.sep ~ std.path.altsep;

  string translateGlobs(RegexMatch!string m) {
    return enforce(
      m.hit == "**" ? ".+"
      : m.hit == "*" ? "[^" ~ seps ~ "]+"
      : null
    );
  }
  auto escaped = std.array.replace(dpkmatcher, r".", r"\.");
  auto re = std.regex.replace!(translateGlobs)(
    escaped, regex(r"\*\*|\*", "g"));

  return regex(re ~ "$");
}

unittest {
  bool matches(string pattern, string path) {
    return !match(path, reMatcher(pattern)).empty;
  }
  assert(matches("foo/b*/src.d", "foo/bar/src.d"));
  assert(matches("foo/b**/src.d", "foo/bar/src.d"));
  assert(matches("foo/b**/src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/b**src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/b**/funk/src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/*.d", "foo/a.d"));
  assert(matches("foo/*", "foo/a"));
  assert(!matches("foo/*/*", "foo/a"));
  assert(!matches("foo/*", "foo/"));
  assert(!matches("foo/*.d", "foo/bar/a.d"));
  assert(matches("foo/**", "foo/a"));
  assert(!matches("foo/**", "foo/"));
  assert(!matches("foo/**/.d", "foo/src.d"));
  assert(matches("foo/**.d", "foo/src.d"));
  assert(matches("foo/**.d", "foo/1/2/3/src.d"));

  version(Windows) {
    assert(matches("foo/**.d", "foo\\1\\2\\3\\src.d"));
    assert(matches("foo/*", "foo\\a"));
    assert(!matches("foo/*", "foo\\"));
    assert(matches("foo/**", "foo\\a"));
    assert(matches("foo/**", "foo\\"));
    assert(matches("foo/b**/src.d", "foo\\bar\\funk\\src.d"));
    assert(matches("foo/b**src.d", "foo\\bar\\funk\\src.d"));
  }
}

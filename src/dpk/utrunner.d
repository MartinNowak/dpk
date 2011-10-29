module dpk.utrunner;

import std.path, std.stdio;
import dpk.util;

string createEmptyMainSrc(string dir) {
  if (!std.file.exists(dir))
    std.file.mkdirRecurse(dir);
  auto path = buildPath(dir, "__emptyMain.d");
  if (!std.file.exists(path))
    std.file.write(path, "void main() {}");
  return path;
}

string createUtRunnerSrc(string dir) {
  if (!std.file.exists(dir))
    std.file.mkdirRecurse(dir);
  auto path = buildPath(dir, "__utRunner.d");
  if (!std.file.exists(path))
    std.file.write(path, utRunnerSrc);
  return path;
}

enum utRunnerSrc = q{
module _utrunner;

import core.runtime;
import std.algorithm : min, max;
import std.string : rightJustify;
import std.datetime;
import std.stdio : writeln, writefln;

static this() {
  core.runtime.Runtime.moduleUnitTester(&unittestrunner);
}

bool unittestrunner()
{
  auto mt = measureTime!((a){ return writefln("Running tests took: %s ms", a.msecs);});
  writeln("\nRUNNING UNITTESTS\n");
  size_t failCnt = 0;
  foreach(m; ModuleInfo)
  {
    if( m )
    {
      auto fp = m.unitTest;
      if( fp !is null )
      {
	auto msg = "TEST: "~m.name;
	try
	{
	  fp();
	  msg ~= " OK".rightJustify(max(0, 79 - msg.length));
	}
	catch( Throwable e )
	{
	  msg ~= " FAILED".rightJustify(max(0, 79 - msg.length))
	    ~ "\n" ~ e.toString ~ "\n";
	  ++failCnt;
	}
	writeln(msg);
      }
    }
  }
  if (failCnt != 0) {
    throw new Exception("Unittest failed.");
  } else {
    return false; // quit after tests
  }
}
};


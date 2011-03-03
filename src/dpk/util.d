module dpk.util;

import std.array, std.format;

string fmtString(Args...)(string fmt, Args args) {
  auto app = appender!string();
  formattedWrite(app, fmt, args);
  return app.data;
}
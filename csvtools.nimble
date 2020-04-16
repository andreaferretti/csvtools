mode = ScriptMode.Verbose

version       = "0.2.1"
author        = "Andrea Ferretti"
description   = "Manage CSV files in Nim"
license       = "Apache2"
skipFiles     = @["test.nim", "goog.csv", "goog-tab.csv", "expected.csv"]

requires: "nim >= 1.0"

task test, "run standard tests":
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."
  --run
  setCommand "c", "test.nim"
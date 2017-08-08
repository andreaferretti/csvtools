mode = ScriptMode.Verbose

version       = "0.1.2"
author        = "Andrea Ferretti"
description   = "Manage CSV files in Nim"
license       = "Apache2"
skipFiles     = @["test.nim", "goog.csv", "goog-tab.csv", "expected.csv"]

requires: "nim >= 0.13.1"

task test, "run standard tests":
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."
  --run
  setCommand "c", "test.nim"
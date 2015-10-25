# Copyright 2015 UniCredit S.p.A.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import unittest, sequtils, csvtools, times

const file = "goog.csv"

suite "reading csv":
  test "reading raw rows":
    let ticks = toSeq(csvRows(file))
    check(ticks[1][0] == "2004-09-09 00:00:00")
    check(ticks[4][1] == "102.349982071")
  test "reading typed rows":
    type Tick = object
      Date: string
      Open, High, Low, Close, Volume, AdjClose: float64
    let ticks = toSeq(csv[Tick](file, skipHeader = true))
    check(ticks[0].Date == "2004-09-09 00:00:00")
    check(ticks[3].Open == 102.349982071)
  test "reading typed rows with dates":
    type Tick = object
      Date: TimeInfo
      Open, High, Low, Close, Volume, AdjClose: float64
    let ticks = toSeq(csv[Tick](file, dateLayout = "yyyy-MM-dd HH:mm:ss", skipHeader = true))
    check(ticks[0].Date.weekday == dThu)
    check(ticks[3].Open == 102.349982071)

suite "writing csv":
  test "converting a single row":
    type Person = object
      name, surname: string
      age: int
    let
      me = Person(name: "Andrea", surname: "Ferretti", age: 34)
      unpack = genUnpack(Person)
    check(unpack(me) == @["Andrea","Ferretti","34"])
  test "quoting strings":
    let x = "string\""
    check(quoteString(x) == "\"string\"\"\"")
  # test "writing a single row":
  #   let x = @["Hello", "this\"", "is\\", "a,", "string"]
  #   check(line(x) == """Hello,this"",is\,"a,",string\n""")
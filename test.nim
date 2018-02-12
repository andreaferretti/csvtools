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

type Tick = object
  Date: string
  Open, High, Low, Close, Volume, AdjClose: float64

type TickD = object
  Date: DateTime
  Open, High, Low, Close, Volume, AdjClose: float64

suite "reading csv":
  test "reading raw rows":
    let ticks = toSeq(csvRows(file))
    check(ticks[1][0] == "2004-09-09 00:00:00")
    check(ticks[4][1] == "102.349982071")
  test "reading typed rows":
    let ticks = toSeq(csv[Tick](file, skipHeader = true))
    check(ticks[0].Date == "2004-09-09 00:00:00")
    check(ticks[3].Open == 102.349982071)
  test "reading typed rows with dates":
    let ticks = toSeq(csv[TickD](file, dateLayout = "yyyy-MM-dd HH:mm:ss", skipHeader = true))
    check(ticks[0].Date.weekday == dThu)
    check(ticks[3].Open == 102.349982071)
  test "reading rows with custom delimiters":
    type Tick3 = object
      Date: string
      Open, High, Low, Close, Volume, AdjClose: float64
    let ticks = toSeq(csv[Tick]("goog-tab.csv", skipHeader = false, separator = '\t'))
    check(ticks[0].Date == "2004-09-09 00:00:00")
    check(ticks[3].Open == 102.349982071)

suite "writing csv":
  type Person = object
    name, surname: string
    age: int
  test "converting a single row":
    let
      me = Person(name: "Andrea", surname: "Ferretti", age: 34)
      unpack = genUnpack(Person)
    check(unpack(me) == @["Andrea","Ferretti","34"])
  test "quoting strings":
    let x = "string\""
    check(quoteString(x) == "\"string\"\"\"")
  test "writing a row from a seq":
    let x = @["Hello", "this\"", "is\\", "a,", "string"]
    check(connect(x) == "Hello,\"this\"\"\",is\\,\"a,\",string\l")
  test "writing a typed row":
    let me = Person(name: "Andrea", surname: "Ferretti", age: 34)
    check(line(me) == "Andrea,Ferretti,34\l")
  test "generating row iterator":
    let people = [
      Person(name: "Andrea", surname: "Ferretti", age: 34),
      Person(name: "Marco", surname: "Firrincieli", age: 34),
      Person(name: "Stefano", surname: "Pascolutti", age: 32)
    ]
    check(toSeq(lines(people)) == @[
      "Andrea,Ferretti,34\l",
      "Marco,Firrincieli,34\l",
      "Stefano,Pascolutti,32\l"
    ])
  test "generating row iterator from iterator":
    proc people(): auto =
      iterator inner: Person {.closure.} =
        yield Person(name: "Andrea", surname: "Ferretti", age: 34)
        yield Person(name: "Marco", surname: "Firrincieli", age: 34)
        yield Person(name: "Stefano", surname: "Pascolutti", age: 32)

      return inner

    check(toSeq(lines(people())) == @[
      "Andrea,Ferretti,34\l",
      "Marco,Firrincieli,34\l",
      "Stefano,Pascolutti,32\l"
    ])
  test "writing to file":
    let people = [
      Person(name: "Andrea", surname: "Ferretti", age: 34),
      Person(name: "Marco", surname: "Firrincieli", age: 34),
      Person(name: "Stefano", surname: "Pascolutti", age: 32)
    ]
    people.writeToCsv("test.csv")

    check(readFile("test.csv") == readFile("expected.csv"))
  test "writing to file with custom delimiters":
    let ticks = toSeq(csv[Tick](file, skipHeader = true))
    ticks[0 .. 4].writeToCsv("test.csv", separator = '\t')

    check(readFile("test.csv") == readFile("goog-tab.csv"))
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
import streams, macros, sequtils, strutils, parseutils, parsecsv, times

## Manage CSV files easily in Nim.
##
## Example of a simple iterator over rows as ``seq[string]``
##
##   .. code-block::nim
##     import csvtools
##
##     for row in csvRows("myfile.csv"):
##       echo row[4]
##
## Example of a typed iterator supporting numbers, strings and dates:
##
##   .. code-block::nim
##     import csvtools, times
##
##     type Payment = object
##       time: TimeInfo
##       accountFrom, accountTo: string
##       amount: float
##
##     for payment in csv[Payment]("payments.csv",
##       dateLayout = "yyyy-MM-dd HH:mm:ss", skipHeader = true):
##       echo payment.amount
##       echo payment.time.weekday
## Writing back into a file
##
##   .. code-block::nim
##     import csvtools
##
##     type Payment = object
##       accountFrom, accountTo: string
##       amount: float
##
##     let payments: seq[Payment] = # ...
##
##     payments.writeToCsv("payments.csv")
##
## Writing back, one line at a time
##
##   .. code-block::nim
##     import csvtools
##
##     type Payment = object
##       accountFrom, accountTo: string
##       amount: float
##
##     let payments: seq[Payment] = # ...
##
##     var f = open("payments.csv", fmWrite)
##     # lines is an iterator of strings
##     for line in lines(payments):
##       f.write(line)
##     f.close()


proc string2int*(s: string): int =
  ## Parses a string as integer, throwing an assertion error over failure.
  ##
  ## This is a helper proc that should not be needed explicitly in client code.
  doAssert parseInt(s, result) > 0

proc string2float*(s: string): float =
  ## Parses a string as float, throwing an assertion error over failure.
  ##
  ## This is a helper proc that should not be needed explicitly in client code.
  doAssert parseFloat(s, result) > 0

proc hasType(x: NimNode, t: static[string]): bool =
  sameType(x, bindSym(t))

proc unsupported(x: NimNode): NimNode =
  error("Unsupported type for field: " & $(x))
  newNimNode(nnkEmpty)

proc nthField(pos: int, field, all: NimNode): NimNode =
  let
    value = newNimNode(nnkBracketExpr).add(all, newIntLitNode(pos))
    arg = if field.hasType("string"): value
      elif field.hasType("int"): newCall("string2int", value)
      elif field.hasType("float"): newCall("string2float", value)
      elif field.hasType("DateTime"): newCall("string2date", value)
      else: unsupported(field)
  newNimNode(nnkExprColonExpr).add(ident($(field)), arg)

proc nthFieldWrite(param, field: NimNode): NimNode =
  let value = newDotExpr(param, field)
  result = if field.hasType("string"): value
    elif field.hasType("int"): newCall("$", value)
    elif field.hasType("float"): newCall("$", value)
    elif field.hasType("DateTime"): newCall("date2string", value)
    else: unsupported(field)

proc objectTypeName(T: NimNode): NimNode =
  # BracketExpr
  # Sym "typeDesc"
  # Sym "Person"
  getType(T)[1]

macro genPackM(t, T: typed): untyped =
  let
    typeSym = objectTypeName(T)
    typeSpec = getType(t)
  typeSym.expectKind(nnkSym)
  typeSpec.expectKind(nnkObjectTy)
  let param = genSym(nskParam, "s")
  var
    pos = 0
    body = newNimNode(nnkObjConstr).add(typeSym)
  for sym in typeSpec[2]:
    body.add(nthField(pos, sym, param))
    inc(pos)
  let procName = genSym(nskProc)
  result = newStmtList(
    newProc(
      name = procName,
      params = [typeSym,
        newIdentDefs(param, newNimNode(nnkBracketExpr).add(ident("seq"), ident("string")))],
      body = newStmtList(body)
    ),
    procName)

proc genPack*(T: typedesc, dateLayout: string = ""): proc (s: seq[string]): T =
  ## Generater a deserializer for the type ``T``.
  ##
  ## This is a procedure that will convert from a sequence of strings to
  ## an object of type ``T``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``DateTime``.
  var t = default(T)
  proc string2date(s: string): DateTime = parse(s, dateLayout)
  return genPackM(t, T)

iterator csvRows*(path: string, separator = ','; quote = '\"'; escape = '\0';
  skipInitialSpace = false): CsvRow =
  ## Raw iterator over the rows of ``path``.
  ##
  ## Does not perform any deserialization, so elements of the
  ## iterators are plain ``seq[string]``.
  ##
  ## The parser's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters. '\0' disables the parsing
  ##   of quotes.
  ## - `escape`: removes any special meaning from the following character;
  ##   '\0' disables escaping; if escaping is disabled and `quote` is not '\0',
  ##   two `quote` characters are parsed one literal `quote` character.
  ## - `skipInitialSpace`: If true, whitespace immediately following the
  ##   `separator` is ignored.
  var s = newFileStream(path, fmRead)
  if s == nil: quit("cannot open the file" & path)
  var x: CsvParser
  open(x, s, path, separator, quote, escape, skipInitialSpace)
  while readRow(x):
    yield x.row
  close(x)

iterator csv*[T](path: string, separator = ','; quote = '\"'; escape = '\0';
  skipInitialSpace = false, skipHeader = false, dateLayout: string = ""): T =
  ## Typed iterator over the rows of ``path``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The parser's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters. '\0' disables the parsing
  ##   of quotes.
  ## - `escape`: removes any special meaning from the following character;
  ##   '\0' disables escaping; if escaping is disabled and `quote` is not '\0',
  ##   two `quote` characters are parsed one literal `quote` character.
  ## - `skipInitialSpace`: If true, whitespace immediately following the
  ##   `separator` is ignored.
  ## - `skipHeader`: If true, the first line of the file will be considered
  ##   a header, and thus skipped
  let pack = genPack(T, dateLayout)
  var first = true
  for row in csvRows(path, separator, quote, escape, skipInitialSpace):
    if unlikely(skipHeader and first):
      first = false
    else:
      yield pack(row)

macro genUnpackM(t, T: typed): untyped =
  let
    typeSym = objectTypeName(T)
    typeSpec = getType(t)
  typeSym.expectKind(nnkSym)
  typeSpec.expectKind(nnkObjectTy)
  let param = genSym(nskParam, "s")
  var s = newSeq[NimNode]()
  for sym in typeSpec[2]:
    s.add(nthFieldWrite(param, sym))
  let
    fields = newNimNode(nnkBracket).add(s)
    procName = genSym(nskProc)
  result = newStmtList(
    newProc(
      name = procName,
      params = [newNimNode(nnkBracketExpr).add(ident("seq"), ident("string")),
        newIdentDefs(param, typeSym)],
      body = newStmtList(prefix(fields, "@"))
    ),
    procName)

proc genUnpack*(T: typedesc, dateLayout: string = ""): proc (t: T): seq[string] =
  ## Generater a serializer for the type ``T``.
  ##
  ## This is a procedure that will convert from an object of type ``T`` to
  ## a sequence of strings.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  var t: T
  proc date2string(s: DateTime): string = format(s, dateLayout)
  return genUnpackM(t, T)

proc quoteString*(s: string, quote = '\"'; escape = '\"'): string {.inline.} =
  ## Quote a single field in order to write it in CSV format
  quote & s.replace($(quote), escape & quote) & quote

proc connect*(s: seq[string], separator = ',', quote = '\"'; escape = '\"';
  quoteAlways = false): string =
  ## Returns a string that represents a row in a CSV, obtained by quoting
  ## and joining the fields in ``s``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  let
    newline = '\l'
    quoted = s.map(proc(x: string): string =
      if quoteAlways or x.contains(quote) or x.contains(separator) or x.contains(newline):
        quoteString(x, quote, escape)
      else:
        x
    )
    row = quoted.join($separator)
  return row & newline

proc line*[T](t: T, separator = ',', quote = '\"'; escape = '\"';
  quoteAlways = false; dateLayout: string = ""): string =
  ## Returns a string that represents a row in a CSV, obtained by quoting
  ## and joining the fields in ``t``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  let unpack = genUnpack(T, dateLayout)
  connect(unpack(t), separator, quote, escape, quoteAlways)

iterator lines*[T](ts: openarray[T], separator = ',', quote = '\"';
  escape = '\"'; quoteAlways = false; dateLayout: string = ""): string =
  ## Iterator over the rows in a CSV, each one obtained by calling ``line``
  ## on an element in ``ts``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  let unpack = genUnpack(T, dateLayout)
  for t in ts:
    yield connect(unpack(t), separator, quote, escape, quoteAlways)

iterator lines*[T](ts: iterator: T, separator = ',', quote = '\"';
  escape = '\"'; quoteAlways = false; dateLayout: string = ""): string =
  ## Iterator over the rows in a CSV, each one obtained by calling ``line``
  ## on an element in ``ts``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  let unpack = genUnpack(T, dateLayout)
  for t in ts():
    yield connect(unpack(t), separator, quote, escape, quoteAlways)

proc writeToCsv*[T](ts: openarray[T], f: var File, separator = ',',
  quote = '\"'; escape = '\"'; quoteAlways = false; dateLayout: string = "") =
  ## Writes rows in a CSV file ``f``, each one obtained by calling ``line``
  ## on an element in ``ts``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  for line in lines(ts, separator, quote, escape, quoteAlways, dateLayout):
    f.write(line)

proc writeToCsv*[T](ts: openarray[T], path: string, separator = ',',
  quote = '\"'; escape = '\"'; quoteAlways = false; dateLayout: string = "", writeHeaders: bool = false) =
  ## Writes rows in a CSV file with path ``path``, each one obtained
  ## by calling ``line`` on an element in ``ts``.
  ##
  ## The type ``T`` must be a flat object whose fields are numbers, strings or ``TimeInfo``.
  ##
  ## The writer's behaviour can be controlled by
  ## the diverse optional parameters:
  ## - `separator`: character used to separate fields
  ## - `quote`: Used to quote fields containing special characters like
  ##   `separator`, `quote` or new-line characters.
  ## - `escape`: removes any special meaning from the following character;
  ## - `quoteAlways`: If true, fields are quoted regardless of whether they
  ##   contain special characters.
  ## - `writeHeaders`: if true, fields from ``T`` will be used to genorate a header line
  var f = open(path, fmWrite)
  defer:
    f.close()

  if writeHeaders:
      var headers = newSeq[string]()
      for a,b in fieldPairs(T()):
        headers.add a
      f.write(connect(headers, separator, quote, escape, quoteAlways))
  writeToCsv(ts, f, separator, quote, escape, quoteAlways, dateLayout)

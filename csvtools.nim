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
import os, streams, macros, parseutils, parsecsv, times

proc string2int*(s: string): int =
  doAssert parseInt(s, result) > 0

proc string2float*(s: string): float =
  doAssert parseFloat(s, result) > 0

proc hasType(x: NimNode, t: static[string]): bool {. compileTime .} =
  sameType(x, bindSym(t))

proc unsupported(x: NimNode): NimNode {. compileTime .} =
  error("Unsupported type for field: " & $(x))
  newNimNode(nnkEmpty)

proc nthField(pos: int, field, all: NimNode): NimNode {. compileTime .} =
  let
    value = newNimNode(nnkBracketExpr).add(all, newIntLitNode(pos))
    arg = if field.hasType("string"): value
      elif field.hasType("int"): newCall("string2int", value)
      elif field.hasType("float"): newCall("string2float", value)
      elif field.hasType("TimeInfo"): newCall("string2date", value)
      else: unsupported(field)
  newNimNode(nnkExprColonExpr).add(ident($(field)), arg)

proc objectTypeName(T: NimNode): NimNode {. compileTime .} =
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
  for sym in typeSpec[1]:
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

proc genPack*(T: typedesc, dateLayout: string = nil): proc (s: seq[string]): T =
  var t: T
  proc string2date(s: string): TimeInfo = parse(s, dateLayout)
  return genPackM(t, T)

iterator csvRows*(path: string, separator = ','; quote = '\"'; escape = '\0';
  skipInitialSpace = false): CsvRow =
  var s = newFileStream(path, fmRead)
  if s == nil: quit("cannot open the file" & path)
  var x: CsvParser
  open(x, s, path)
  while readRow(x):
    yield x.row
  close(x)

iterator csv*[T](path: string, separator = ','; quote = '\"'; escape = '\0';
  skipInitialSpace = false, skipHeader = false, dateLayout: string = nil): T =
  let pack = genPack(T, dateLayout)
  var first = true
  for row in csvRows(path):
    if unlikely(skipHeader and first):
      first = false
    else:
      yield pack(row)
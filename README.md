CSVtools
========

[![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag)

Manage CSV files easily in Nim.

The aim is to be able to transform CSV files into typed iterators, infering
layout of things like dates and number where possible, with minimal user intervention.

In this preliminary version, english locale is assumed for numbers and layout
of dates must be specified. Still, the automatic typed deserialization is
already quite handy.

A symmetric API exists for writing typed sequences into CSV files.

The conversion from an object of type `T` into a sequence of strings - or
viceversa the transformation from a sequence of strings into a `T` - is handled
by a macro. This macro assumes that `T` is a flat type, meaning that its
members are either numbers, dates (`TimeInfo`) or strings.

The library is updated on Nim devel. For Nim up to 0.13, use version 0.1.0
of csvtools.

[Api documentation](http://andreaferretti.github.io/csvtools/)

Examples
--------

Simple iterator over rows as `seq[string]`

```nim
import csvtools

for row in csvRows("myfile.csv"):
  echo row[4]
```

Typed iterator supporting numbers, strings and dates

```nim
import csvtools, times

type Payment = object
  time: TimeInfo
  accountFrom, accountTo: string
  amount: float

for payment in csv[Payment]("payments.csv", dateLayout = "yyyy-MM-dd HH:mm:ss", skipHeader = true):
  echo payment.amount
  echo payment.time.weekday
```

Writing back into a file

```nim
import csvtools

type Payment = object
  accountFrom, accountTo: string
  amount: float

let payments: seq[Payment] = # ...

payments.writeToCsv("payments.csv")
```

Writing back, one line at a time

```nim
import csvtools

type Payment = object
  accountFrom, accountTo: string
  amount: float

let payments: seq[Payment] = # ...

var f = open("payments.csv", fmWrite)
# lines is an iterator of strings
for line in lines(payments):
  f.write(line)
f.close()
```

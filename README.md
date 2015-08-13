CSVtools
========

Manage CSV files easily in Nim. At this moment only reading is supported.

The aim is to be able to transform CSV files into typed iterators, infering layout of things like dates and number where possible, with minimal user intervention.

In this preliminary version, english locale is assumed for numbers and layout of dates must be specified. Still, the automatic typed deserialization is already quite handy:

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
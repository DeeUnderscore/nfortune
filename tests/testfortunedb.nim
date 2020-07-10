## Tests for the fortunedb module

import unittest
import sequtils
# import sets

import nfortunepkg/fortunedb
import nfortunepkg/fortunefile

suite "filtering by length":
  setup:
    let 
      pool = FortunePool( @[ 
        newFortuneFile("tests/samples/sample", "tests/samples/sample.dat"),
        newFortuneFile("tests/samples/exoticdelim", "tests/samples/exoticdelim.dat")
      ] )

  test "count with greater than filter":
    let filter = fortunedb.Filter(
      filterType: filterGreaterThan,
      threshold: 13
    )

    check( 
      map(pool, proc (f: FortuneFile): Natural = filteredCount(f, filter))
        .foldl(a + b) == 6
    )

  test "count with less than filter":
    let filter = fortunedb.Filter(
      filterType: filterLessThan,
      threshold: 11
    )

    check( 
      map(pool, proc (f: FortuneFile): Natural = filteredCount(f, filter))
        .foldl(a + b) == 1
    )

  test "count with no filter":
    check( 
      map(pool, proc (f: FortuneFile): Natural = filteredCount(f, nil))
        .foldl(a + b) == 7
    )

suite "random picks":
  setup:
    let fortuneSeq = @[ 
      newFortuneFile("tests/samples/sample", "tests/samples/sample.dat"),
      newFortuneFile("tests/samples/exoticdelim", "tests/samples/exoticdelim.dat")
    ]

# this one is potentially flaky due to randomness 
#[
  test "pick with greater than filter":
    let 
      pool = FortunePool(
        pool: fortuneSeq,
        filterType: filterGreaterThan,
        threshold: 65
      ) 
      possible = toHashSet([ 
        "Third quote!\n\nAnd  what a twist, this one has multiple lines, even!\n",
        "Hello I'm a file separated by a = separator instead of the usual % separator\n"
      ])

    for _ in 1..1000:
      let picked = pool.pickRandomFromPool()[0]
      check( possible.contains(picked) )
]#
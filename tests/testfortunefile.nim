## Tests for the fortunefile module

import unittest

import sequtils
import re
import sets

import nfortunepkg/fortunefile



suite "processing fortune files without dat files":
  setup:
    let loadedFile = newFortuneFile("tests/samples/sample")

  test "load file contents":
    const desiredSampleString = staticRead("samples/sample")

    check:
      loadedFile.rawText == desiredSampleString
      # try twice, the second time it should come from cache
      loadedFile.rawText == desiredSampleString

  test "dynamically generate datfile":
    let outputDatFile = loadedFile.datFile

    check:
      outputDatFile.version == 2
      outputDatFile.stringCount == 4
      outputDatFile.shortestLength == 9
      outputDatFile.longestLength == 67
      outputDatFile.randomized == false
      outputDatFile.ordered == false
      outputDatFile.rot == false
      outputDatFile.delimiter == '%'

      # recheck that cache works

      outputDatFile == loadedFile.datFile

  test "iterate over fortunes":
    const
      desiredList: array[4, string] = [
        "Hello, world!\n",
        "Second quote.\n",
        "Third quote!\n\nAnd what a twist, this one has multiple lines, even!\n",
        "Last one\n"
      ]

    let gotList = toSeq( loadedFile.fortunes() )

    for (got, desired) in zip(gotList, desiredList):
      check( got == desired )

    check( gotList.len() == 4)

  test "get a fortune":
    check:
      "Second quote.\n" == loadedFile.getFortune(1)

  test "try to index a fortune out of bounds":
    expect IndexDefect:
      discard loadedFile.getFortune(6)

  test "get filtered fortunes":
    const desiredSet = toHashSet([
      "Second quote.\n",
      "Third quote!\n\nAnd what a twist, this one has multiple lines, even!\n"])

    let gotSet = toHashSet(toSeq(loadedFile.filteredFortunes(re"quote[!.]")))

    check( desiredSet == gotSet )

# would be cool to parametrize this somehow to eliminate duplicate code
suite "processing fortune files without dat files":
  setup:
    let loadedFile = newFortuneFile("tests/samples/sample",
                                    "tests/samples/sample.dat")
  
  test "load dat file":

    let outputDatFile = loadedFile.datFile

    check:
      outputDatFile.version == 2
      outputDatFile.stringCount == 4
      outputDatFile.shortestLength == 9
      outputDatFile.longestLength == 67
      outputDatFile.randomized == false
      outputDatFile.ordered == false
      outputDatFile.rot == false
      outputDatFile.delimiter == '%'

  test "get filtered fortunes":
    const desiredSet = toHashSet([
      "Second quote.\n",
      "Third quote!\n\nAnd what a twist, this one has multiple lines, even!\n"])

    let gotSet = toHashSet(toSeq(loadedFile.filteredFortunes(re"quote[!.]")))

    check( desiredSet == gotSet )

  test "get a fortune":
    check:
      "Second quote.\n" == loadedFile.getFortune(1)

  test "get the length of a fortune":
    check:
      # note: the sizes include trailing delims!
      loadedFile.getFortuneLength(0) == 16
      loadedFile.getFortuneLength(1) == 16
      loadedFile.getFortuneLength(2) == 69
      loadedFile.getFortuneLength(3) == 11
    
    let seqFromIter = toSeq(loadedFile.fortuneLengths())

    check( seqFromIter == @[Natural(16), 16, 69, 11] )

suite "processing fortune files with nonstandard delimiter":
  test "without dat file":
    let loadedFile = newFortuneFile("tests/samples/exoticdelim", '=')

    check ( loadedFile.getFortune(2) == "This is the third string.\n" )

  test "with dat file":
    let loadedFile = newFortuneFile("tests/samples/exoticdelim",
                                    "tests/samples/exoticdelim.dat")

    check ( loadedFile.getFortune(2) == "This is the third string.\n" )

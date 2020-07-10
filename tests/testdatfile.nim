## Tests for datfile parsing

import unittest

import streams

import nfortunepkg/datfile

const desiredSampleDat: string = staticRead("samples/sample.dat")

suite "datfile processing":

  test "file parsing":
    let input = openFileStream("tests/samples/sample.dat")
    defer: input.close()
    let parsed = datfile.deserialize(input)

    check:
      parsed.version == 2
      parsed.stringCount == 4
      parsed.shortestLength == 9
      parsed.longestLength == 67
      parsed.randomized == false
      parsed.ordered == false
      parsed.rot == false
      parsed.delimiter == '%'
    
    let wantedOffsets: seq[int32] = @[0'i32, 16, 32, 101, 112]

    check( parsed.offsets == wantedOffsets )

  test "file output":
    let 
      input = DatFile(
        version: 2,
        stringCount: 4,
        shortestLength: 9,
        longestLength: 67,
        randomized: false,
        ordered: false,
        rot: false,
        delimiter: '%',
        offsets: @[0'i32, 16, 32, 101, 112] )

    let outputStream = newStringStream()

    input.serialize(outputStream)
    outputStream.setPosition(0)

    check( outputStream.readAll() == desiredSampleDat )
  
suite "datfile generation":
  test "generate from strings file":
    let inputFile = openFileStream("tests/samples/sample")
    defer: inputFile.close()

    let output = datfile.generateFromFile(inputFile)

    check:
      output.version == 2
      output.stringCount == 4
      output.shortestLength == 9
      output.longestLength == 67
      output.randomized == false
      output.ordered == false
      output.rot == false
      output.delimiter == '%'

    let wantedOffsets: seq[int32] = @[0'i32, 16, 32, 101, 112]
    
    check( output.offsets == wantedOffsets )

  test "strings file without terminating delim":
    let inputFile = newStringStream("""Hello, world!
%
Second quote.""")

    let output = datfile.generateFromFile(inputFile)

    let wantedOffsets: seq[int32] = @[0'i32, 16, 29]

    check( output.offsets == wantedOffsets )

  test "generate from strings file with non-standard delim":
    let inputFile = openFileStream("tests/samples/exoticdelim")
    defer: inputFile.close()

    let output = datfile.generateFromFile(inputFile, '=')

    check:
      output.version == 2
      output.delimiter == '='
      output.stringCount == 3
      output.shortestLength == 26
      output.longestLength == 77
      output.randomized == false
      output.ordered == false
      output.rot == false

    let wantedOffsets: seq[int32] = @[0'i32, 79, 143, 171]

    check( output.offsets == wantedOffsets )


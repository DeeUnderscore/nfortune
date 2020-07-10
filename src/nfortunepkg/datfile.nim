## Code related to handling ``fortune-mod`` .dat files (ones genereted by the
## ``strfile`` utility). Includes both deseralizing, serializing, and generation.
## 
## This code aims to be compatible with version 2 ``fortune-mod`` dat files.

import streams
import system
import endians
import strformat

type 
  DatFile* = ref object 
    ## deserialized .dat file
    ## 
    ## The original ``strfile`` provides options for both randomizing and
    ## ordering the offsets, and indicates if that was done by setting a flag in
    ## the datfile. nfortune does not provide functionality for randomizing or
    ## ordering the offsets, and so will never set the flags. 
    ## 
    ## Original strfile outputs n+1 offsets, where n is the number of strings in
    ## file. The offsets point to the first byte of a given string, except for
    ## the last offset, which will point one byte past the end of file.

    version*: uint32
    stringCount*: uint32       ## total number of fortunes in this file
    longestLength*: uint32     ## length of longest fortune
    shortestLength*: uint32    ## lenght of shortest fortune
    randomized*: bool          ## are the offsets randomized
    ordered*: bool             ## are the offsets ordered
    rot*: bool                 ## is the text rot-13'd
    delimiter*: char           ## delimiter character used in fortune file, ``%`` by default
    offsets*: seq[int32]       ## offsets into the fortune file where each fortune begins

  DatFileParseError = object of system.ValueError


const
  # These correspond to the bool fields in DatFile
  StrRandom: uint32 = 0x1
  StrOrdered: uint32 = 0x2
  StrRotated: uint32 = 0x4
  DatfileVersion: uint32 = 2  # corresponds to fortune-mod's 
  DefaultDelim*: char = '%'


proc read32(input: streams.Stream): uint32 
           {.raises: [DatFileParseError, OSError, IOError, Defect].} =
  ## Read a big endian int32 from stream. Consumes 4 bytes from ``input``.
  var buffer: array[4, char]
  if input.readData(addr(buffer), 4) != 4:
    raise newException(DatFileParseError, "Failed to parse int32")

  # streams assumes machine endianness but datfiles are explicitly big endian, 
  # so we have to do this memory poking flip
  bigEndian32(addr(result), addr(buffer))

proc toBigEndian(input: uint32): array[4, char] = 
  ## Read a 32 bit number and convert it to big endian. Does not type check 
  ## input. 
  
  bigEndian32(addr(result), unsafeAddr(input))

proc deserialize*(input: Stream): DatFile 
                 {.raises: [DatFileParseError, OSError, IOError, Defect].} = 
  ## Deserialize a dat file in ``input`` into a ``DatFile`` object

  result = new DatFile

  result.version = read32(input)

  if result.version != DatfileVersion:
    raise newException(DatFileParseError, "Unrecognized dat file version")

  result.stringCount = read32(input)
  result.longestLength = read32(input)
  result.shortestLength = read32(input)

  var flags = read32(input)
  result.randomized = cast[bool](flags and StrRandom)
  result.ordered = cast[bool](flags and StrOrdered)
  result.rot = cast[bool](flags and StrRotated)
  result.delimiter = input.readChar()


  if result.delimiter == '\x00':
    raise newException(DatFileParseError, "Unexpected EOF")

  input.setPosition(input.getPosition + 3) # skip padding

  # note that the dat file always includes one extra offset past the end of the
  # fortune file, not included in stringCount
  result.offsets = newSeq[int32](result.stringCount+1)
  var buffer: array[4, char]
  for i, _ in result.offsets:
    if input.readData(addr(buffer), 4) < 4:
      raise newException(DatFileParseError, "Failed to prase a string offset")
    
    var currentNum: int32
    bigEndian32(addr(currentNum), addr(buffer))

    result.offsets[i] = currentNum

proc serialize*(self: DatFile, output: Stream) = 
  ## Serialize ``self`` to ``output`` stream (which should be availble for
  ## writing). Does not close stream.
  
  output.write(toBigEndian(self.version))
  output.write(toBigEndian(self.stringCount))
  output.write(toBigEndian(self.longestLength))
  output.write(toBigEndian(self.shortestLength))


  let flags: uint32 = ( 0 or 
                        (if self.randomized: StrRandom else: 0) or
                        (if self.ordered: StrOrdered else: 0) or
                        (if self.rot: StrRotated else: 0) )

  output.write(toBigEndian(flags))
  output.write(self.delimiter)
  
  for _ in countup(1,3): output.write(0'u8) # 3 bytes of padding

  var buffer: array[4, char]
  for offset in self.offsets:

    bigEndian32(addr(buffer), unsafeAddr(offset))
    
    output.write(buffer)
  
proc generateFromFile*(input: Stream, delim: char = DefaultDelim): DatFile = 
  ## Generate a DatFile from ``input``, a fortune file. 

  result = Datfile(
    version: DatfileVersion,
    longestLength: low(uint32),
    shortestLength: high(uint32),
    randomized: false,
    ordered: false,
    rot: false,
    delimiter: delim,
    offsets: @[0'i32]  # first offset is always zero, the start of file
  )

  var currentOffset: int32 = 0

  # delimiters have to be on a line by themselves
  let delimString: array[3, char] = ['\n', delim, '\n']

  var peeked: array[3, char]

  while not input.atEnd():
    # we copy directly to a char array here to avoid allocating a lot of strings
    let charCount = input.peekData(addr(peeked), 3)
    
    if charCount < 3:
      # we're approaching the end and there isn't enough chars left for there to
      # be a valid delimiter, so we seek one past the end and bail
      currentOffset += cast[int32](charCount)
      input.setPosition(cast[int](currentOffset))
      break

    if peeked == delimString:
      # lengths include the final newline, hence the +1
      let lastLen: uint32 = cast[uint32](currentOffset -
                             result.offsets[result.offsets.high()]) + 1

      if lastLen < result.shortestLength:
        result.shortestLength = lastLen
      if lastlen > result.longestLength:
        result.longestLength = lastLen 

      # advancing 3 puts us after the second newline in delim string
      currentOffset += 3'i32
      result.offsets.add(currentOffset)
    else:
      currentOffset += 1'i32

    input.setPosition(cast[int](currentOffset))
  
  # if the last string is terminated with a delimiter, we'll have added the last
  # offset already; if not we'll have to add it now. This is consistent with
  # original strfile behavior
  if result.offsets[result.offsets.len()-1] == current_offset:
    result.stringCount = cast[uint32](result.offsets.len() - 1)
  else: 
    result.stringCount = cast[uint32](result.offsets.len())
    result.offsets.add(currentOffset)
    
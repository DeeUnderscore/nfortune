## Module for handling fortune files
## 
## This module handles fortune files, ie the files which contain a number of
## quotes, separated with delimiters.

import options
import streams
import strformat
import sequtils
import re

import datfile

type
  FortuneFile* = ref object
    ## A fortune file
    ## 
    ## Files can either be loaded with a related.dat file containing indices
    ## of quotes in the fortune file, or without a .dat file.
    ##
    ## When loaded with a .dat file, the metadata is loaded from the .dat file, 
    ## and loading of the actual fortune file is deferred until it is needed 
    ## (such as when a fortune is requested).
    ## 
    ## When loaded without a .dat file, the metadata is generated when needed by
    ## loading the fortune file into memory and generating metadata from it. The
    ## fortune file remains cached in memory for further use. 
  
    path: string  ## Path to the fortune file
    cRawText: Option[string]  ## cached contents of the file
    cDatFile: DatFile  ## cached datfile, either loaded or generated
    delimiter: char  ## delimiter used to separate quotes
  FortuneIndexError* = ref object of IndexDefect
    ## Raised on attempts to read a fortune past the end of file. Can happen
    ## with dat file out of sync.
    path*: string  ## Path to file we were trying to read

proc newFortuneIndexError(file: FortuneFile,
                          message: string, 
                          parentException: ref Exception = nil): 
                          FortuneIndexError =
  FortuneIndexError(msg: message, parent: parentException, path: file.path)

proc path*(f: FortuneFile): string = f.path

proc `$`*(f: FortuneFile): string = &"""FortuneFile(path: "{f.path}")"""

proc newFortuneFile*(fortunePath: string, 
                    delimiter: char = DefaultDelim): FortuneFile =
  ## Create a ``FortuneFile`` object from a fortune file. 
  ## 
  ## A delimiter can optionally be supplied, otherwise the default is used. 
  
  result = FortuneFile(
    path: fortunePath,
    cRawText: none(string),
    cDatFile: nil,
    delimiter: delimiter
  )

proc newFortuneFile*(fortunePath: string,
                     datfilePath: string): FortuneFile =
  ## Create a ``FortuneFile`` object from a fortune file and its corresponding
  ## dat file

  let datfileStream = openFileStream(datfilePath)
  defer: datfileStream.close()
  let cDatFile = datfile.deserialize(datfileStream)

  result = FortuneFile(
    path: fortunePath,
    cRawText: none(string),
    cDatFile: cDatFile,
    delimiter: cDatFile.delimiter
  )

proc getContents(self: FortuneFile): string =
  ## Return entire contents of this fortune file
  
  let inputFile = openFileStream(self.path)
  defer: inputFile.close()

  result = inputFile.readAll()

proc rawText*(self: FortuneFile): string =
  if self.cRawText.isSome:
    return self.cRawText.get()

  result = self.getContents()
  self.cRawText = some(result)

proc datFile*(self: FortuneFile): DatFile =
  ## Get the ``DatFile`` corresponding to this ``FortuneFile``
  ## 
  ## If not loaded from an actual dat file, the ``DatFile`` will be generated
  ## dynamically on first call. 
  
  if self.cDatFile != nil:
    return self.cDatFile

  let inputString = newStringStream(self.rawText)
  result = datfile.generateFromFile(inputString, self.delimiter)

  self.cDatFile = result

proc chompFortune(fortune: string; 
                  delim: char = DefaultDelim): string {.inline.} =
  ## chomp any trailing delimiters present in the ``fortune`` string
  
  var toChomp = 0

  if fortune[^2..^1] == &"{delim}\n":
    toChomp += 2
  elif fortune[^1] == '\n':
    toChomp += 1
  
  fortune[0..^(1+toChomp)]


proc getFortune*(self: FortuneFile; startOffset, endOffset: int32): string =
  ## Get the fortune between ``startOffset`` and ``endOffset`` in the fortune
  ## file.
  ## 
  ## This proc will strip any trailing delimiters included in the requested
  ## range

  # we assume that we don't want to cache the whole fortune file, because we're
  # likely just exiting after printing this
  if self.cRawText.isSome():
    try:
      result = chompFortune(self.cRawText.get()[startOffset..endOffset],
                            self.delimiter)
    except IndexDefect as parentExc:
      raise self.newFortuneIndexError("fortune file index out of range",
                                      parentExc)

  else:
    let inputFile = openFileStream(self.path)
    defer: inputFile.close()

    inputFile.setPosition(startOffset)

    # if we setPosition anywhere past the end, atEnd will be true
    if inputFile.atEnd():
      raise self.newFortuneIndexError("start index past the end of file")

    let
      wantedLen = endOffset - startOffset + 1
      unchomped = inputFile.readStr(wantedLen)

    if len(unchomped) < wantedLen:
      raise self.newFortuneIndexError("got a fortune that is shorter than expected")

    result = chompFortune(unchomped, self.delimiter)

proc getFortune*(self: FortuneFile, nth: Natural): string =
  ## Get ``nth`` fortune in this fortune file, counting up from 0
  ##
  ## If ``nth`` is over the number of fortunes, ``IndexError`` will be raised

  let datFile = self.datFile() 
  if nth > high(datFile.offsets) - 1:  # no fortune starts at the last one
    raise newException(IndexDefect, "fortune index out of bound")

  # the next offset points to the first byte of the next string, so we subtract 1
  self.getFortune(datFile.offsets[nth], datFile.offsets[nth+1]-1)

proc getFortuneLength*(self: FortuneFile, nth: Natural): Natural =
  ## Get the size of ``nth`` fortune in bytes
  ##
  ## As this is calculated from offsets, it potentially includes the trailing 
  ## delimiter, and so can be more bytes than after chomping. 

  let datFile = self.datFile()
  
  datFile.offsets[nth+1] - datFile.offsets[nth]

iterator fortuneLengths*(self: FortuneFile): Natural {.closure.} = 
  ## Iterate through all the fortunes in this file, getting their lengths
  
  let datFile = self.datFile()

  for i in 0..<datFile.stringCount:
    yield datFile.offsets[i+1] - datFile.offsets[i]

iterator fortunes*(self: FortuneFile): string {.closure.} =
  ## Iterate over all the fortunes in the file, in file order

  let 
    rawTextString = self.rawText

  for (l, r) in zip(self.datFile.offsets, self.datFile.offsets[1..^1]):
    # the last index is past the end of file 
    yield chompFortune(rawTextString[l..r-1], self.delimiter)

iterator filteredFortunes*(self: FortuneFile, 
                           pattern: Regex): string {.closure.} =
  ## return all fortunes which match the ``pattern`` regex
  
  for fortune in self.fortunes():
    if contains(fortune, pattern):
      yield fortune

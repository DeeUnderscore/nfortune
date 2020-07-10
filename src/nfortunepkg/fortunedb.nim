## Code handling a fortune database
##
## nfortune, in keeping with fortune-mod functionality, allows the user to
## specify percentage probability of picking different fortune databases. 
## 
## Since probability can be specified for both individual files and directories,
## this is implemented by creating separate pools of one or more fortune files, 
## doing a random weighed selection of a pool, and then randomly selecting from
## within the pool. In case there are no percentages specified, one pool is 
## used, which contains all the fortune files. 

import random
import sequtils
import math
import os
import options

import fortunefile
import datfile

randomize()

type
  FilterType* = enum ## Which fortunes to allow
    filterLessThan, ## only fortunes smaller than or equal to threshold allowed 
    filterGreaterThan  ## only fortunes bigger than threshold allowed
  Filter* = ref object
    filterType*: FilterType ## Whether to filter greater or lower than threshold
    threshold*: Natural ## Size threshold for fortunes
  FortunePool* = seq[FortuneFile] ## One or more fortune files pooled together
  NoPossiblePickError* = object of CatchableError ## \
    ## All possible picks have been filtered out

proc getFilterProc(self: Filter): proc (l: Natural): bool = 
  ## get a proc that returns true for lengths that the filter allows

  case self.filterType
  of filterLessThan:
    (proc (l: Natural): bool = l <= self.threshold)
  of filterGreaterThan:
    (proc (l: Natural): bool = l > self.threshold)

proc filteredCount*(file: FortuneFile,
                    filter: Filter = nil): Natural =
  ## Get count of fortunes in the given ``file`` after the FortunePool's filter
  ## is applied
  
  if filter == nil :
    return file.datFile.stringCount
  
  let filterProc = filter.getFilterProc()

  let lengths = toSeq(file.fortuneLengths())
  let filtered = sequtils.filter(lengths, filterProc)
  
  len(filtered)


proc totalFortunes*(pool: FortunePool, filter: Filter = nil): Natural =
  ## Total fortunes in this pool
  result = 0

  for file in pool:
    result += file.filteredCount(filter)


proc getFilteredFromFile(file: FortuneFile,
                         nth: Natural,
                         filter: Filter = nil): string = 
  ## Get ``nth`` fortune from the ``file`` after applying the FortunePool's
  ## filter. ``nth`` is 0-indexed. 
  ## 
  ## For example, ``nth`` = 1 means pick the second fortune in the file that 
  ## passes the filter. 
  
  if filter == nil:
    return file.getFortune(nth)

  let 
    filterProc = filter.getFilterProc()
    lengths = toSeq(file.fortuneLengths())
    # seq of tuples (index, len), where `index` is the index in the unfiltered
    # sequence, and len is the length, filtered to only incude the ones that 
    # pass the filter
    filteredLengths = (
      zip(toSeq(countup(0, high(lengths))), lengths)
      .filter(proc (i: (Natural, Natural)): bool = filterProc(i[1]))
    )
  
  result = file.getFortune(filteredLengths[nth][0])


proc pickFromPool*(pool: FortunePool, 
                   filter: Filter = nil): Option[(string, FortuneFile)] =
  ## Pick a single fortune out of all the fortunes in the pool
  ## 
  ## Returns a tuple of the fortune, and the source file, or None if no pick was
  ## available (such as when filters filter everything out)

  let counts = map(pool,
    proc (f: FortuneFile): Natural = filteredCount(f, filter) )
  let maxNumber = counts.foldl(a + b)

  if maxNumber <= 0:
    return none((string, FortuneFile))
  
  # fortunes are 0-indexed in individual FortuneFiles, but it's easier to skip
  # files in the pool if we use 1-indexing. We just have to remember to subtract
  # 1 when actually fetching the fortune. 
  var picked = rand(Natural(1)..maxNumber)

  for (file, count) in zip(pool, counts):
    if picked <= count:
      return some((file.getFilteredFromFile(picked-1, filter), file))
    
    picked -= count


proc pickPool(pools: seq[FortunePool]): FortunePool =
  ## Pick a random fortune pool from ``pools``
  
  random.sample(pools)

proc pickPool(pools: seq[FortunePool], 
              percentages: seq[float]): FortunePool =
  ## Pick a random fortune pool from ``pools``, weighed with ``percentages``
  ## 
  ## ``percentages`` should be the same length as ``pools``.


  let cdf = percentages.cumsummed()
  random.sample(pools, cdf)


proc pickFromPools*(pools: seq[FortunePool],
                    filter: Filter = nil): Option[(string, FortuneFile)] =
  ## Pick a pool, and then pick a fortune from that pool
  ## 
  ## Returns a tuple of the fortune and the file it came from, or none, if none
  ## were available.
  
  let pool = pickPool(pools)
  pool.pickFromPool(filter)


proc pickFromPools*(pools: seq[FortunePool],
                    percentages: seq[float],
                    filter: Filter = nil): Option[(string, FortuneFile)] =
  ## Pick a pool, and then pick a fortune from that pool. Pool pick is weighed
  ## by ``percentages``
  ## 
  ## Returns a tuple of the fortune and the file it came from, or none, if none
  ## were available.

  let pool = pickPool(pools, percentages)
  pool.pickFromPool(filter)



type 
  AddMode* = enum
    ## Mode to use when loading fortune files
    amDatOnly,  ## Only load files if there is a corresponding .dat file
    amNoDat,  ## Ignore any existing .dat files when loading fortune files
    amBoth  ## Use .dat files if present

proc fortuneFileFromPath(path: string, 
                         mode: AddMode, 
                         delim: char = DefaultDelim): FortuneFile  = 

  ## Return a new FortuneFile from the given ``path``, either using or not using
  ## a .dat file, depending on ``mode``
  let datFilePath = changeFileExt(path, "dat")

  case mode
  of amNoDat:
    return newFortuneFile(path, delim)
  of amDatOnly:
    if existsFile(datFilePath):
      return newFortuneFile(path, datFilePath)
    else:
      return nil
  of amBoth:
    if existsFile(datFilePath):
      return newFortuneFile(path, datFilePath)
    else:
      return newFortuneFile(path, delim)


proc poolFromPath*(path: string,
                   mode: AddMode,
                   delim: char = DefaultDelim): FortunePool =
  ## Create a new pool from file or directory at ``path``
  ## 
  ## ``mode`` can be set to ``amDatOnly`` to only include fortune files with
  ## corresponding dat files, ``amNoDat`` to ignore dat files entirely, or to
  ## ``amBoth`` to use dat files optionally, if present.
  ## 
  ## ``delim`` can be used to specify the delimiter when not using dat files. If
  ## a dat file is used, ``delim`` is ignored. 
  ## 
  ## Files which do not meet the filter requirements will be skipped, so the
  ## pool can potentially be empty. Raises IOError if the path is not valid.
  
  if existsFile(path):
    let fortuneFile = fortuneFileFromPath(path, mode, delim)

    if fortuneFile != nil:
      return @[fortuneFile]
    else:
      return @[]
  
  if existsDir(path):

    if mode == amDatOnly:
      # iterate through dat files and then find the corresponding fortune files

      for file in walkDirRec(path):
        if splitFile(file).ext != ".dat":
          continue

        let fortuneFilePath = file.changeFileExt("")
        if existsFile(fortuneFilePath):
          result.add(newFortuneFile(fortuneFilePath, file))
    
    else:
      # iterate through fortune files, and (optionally) find the corresponding
      # dat file

      for file in walkDirRec(path):
        if splitFile(file).ext == ".dat":
          continue
        let fortuneFile = fortuneFileFromPath(file, mode, delim)

        if fortuneFile != nil:
          result.add(fortuneFile)
     
    return result

  # fall through if path is neither a dir nor a file
  raise newException(IOError, "invalid path")

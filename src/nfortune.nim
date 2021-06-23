import strformat
import os
import streams
import options
import re
import strutils
import sequtils

import simple_parseopt

import nfortunepkg/fortunedb
import nfortunepkg/fortunefile
import nfortunepkg/datfile

const DefaultDBDir = "/usr/share/games/fortunes"

proc strfile(args: seq[string], delim: char) = 
  ## -strfile functionality 
  if len(args) == 0:
    stderr.writeLine(&"Please provide at least one fortune file")
    quit(QuitFailure)

  for file in args:
    if not existsFile(file):
      stderr.writeLine(&"Error: cannot open path: {file}")
      continue

    var 
      loadedFile: FortuneFile
      generatedDat: DatFile
    try: 
      loadedFile = newFortuneFile(file, delim)
      generatedDat = loadedFile.datFile()
    except Exception as e:
      stderr.writeLine(&"Error: Cannot load file: {e.msg}")
      continue
    
    let
      datPath = file.changeFileExt("dat")
    
    try:
      let datFileStream = openFileStream(datPath, mode=fmWrite)
      generatedDat.serialize(datFileStream)
    except Exception as e:
      stderr.writeLine(&"Error: Cannot write dat file: {e.msg}")
      continue

    stderr.writeLine(&"Generated: {file} → {datPath}")
    stderr.writeLine(&"String count: {generatedDat.stringCount}")
    stderr.writeLine(&"Longest string: {generatedDat.longestLength} bytes")
    stderr.writeLine(&"Shortest string: {generatedDat.shortestLength} bytes")

proc getAbsPath(input: string, bases: openArray[string]): Option[string] = 
  ## If ``input`` is absolute, return input. If not, try ``input`` with every 
  ## one of ``bases`` and return first path that exists. Multiple bases are 
  ## allowed so we can search both the default db dir and cwd. 
  
  if isAbsolute(input):
    return some(input)
  
  for base in bases:
    let absPath = base / input
    if existsFile(absPath) or existsDir(absPath):
      return some(absPath)

  # fall through case
  return none(string) 
  

proc getDatabases(files: openArray[string],
                  mode: AddMode,
                  equalProb: bool = false,
                  delim: char = DefaultDelim): (seq[FortunePool], seq[float]) = 
  ## get FortuneFiles from provided arguments 
  ## 
  ## Returns a tuple of FortunePools and corresponding probability perecentages.
  ## Files without a percentage specifier all go into one pool together, unless 
  ## equalProb is set to true, in which case each file goes into a separate pool
  ## with equal probability. 
  var dbDir = getEnv("NFORTUNE_DATABASE")
  if dbDir == "": 
    dbDir = DefaultDBDir
  if not existsDir(dbDir):
    stderr.writeLine(&"Error: Cannot open {dbDir} (set via NFORTUNE_DATABASE)")
    quit(QuitFailure)


  let bases = [dbDir, getCurrentDir()]

  # We return floats, even though percentages can only be specified as ints
  # by the user. This allows us to subdivide the reminder equally among the
  # remaining files if equalProb is true (at least as long as float precision
  # errors don't ruin it for us).
  let digitRe = re"(\d{1,3})%"
  var 
    fallthroughPool: FortunePool = @[]
    percentSet = false

  for entry in files:
    var matches: array[1, string]

    # match percentage specifier
    if entry.match(digitRe, matches):
      if percentSet:
        # we got two percentages in row
        stderr.writeLine(&"Files should follow percentages")
        quit(QuitFailure)
      let value: Natural = parseInt(matches[0])
      percentSet = true
      result[1].add((float) value)

    # match paths 
    else: 
      let fortunePath = getAbsPath(entry, bases)
      var loadedPool: FortunePool

      if fortunePath.isNone:
        stderr.writeLine(&"Could not find a path for {entry}")
        quit(QuitFailure)

      try:
        loadedPool = poolFromPath(fortunePath.get, mode, delim)
      except Exception as e:
        stderr.writeLine(&"Error: Cannot load file: {e.msg}")
        continue

      if len(loadedPool) == 0:
        stderr.writeLine(&"Error: Found no useable fortune files under {fortunePath}")

      if percentSet:
        result[0].add(loadedPool)
        percentSet = false
      else:
        fallthroughPool &= loadedPool

  
  if percentSet:
    # We finished but we had a hanging percentage at the end
    stderr.writeLine(&"Files should follow percentages")
    quit(QuitFailure)

  # the total of all percentage explicitly specified. the leftover is what will
  # be used for the fallthrough pool
  let totalSoFar = if len(result[1]) > 0:
      foldl( result[1], a + b )
  else:
    0

  if totalSoFar > 100:
    stderr.writeLine(&"Percentages should sum up to 100 or less")
    quit(QuitFailure)
  
  if not equalProb:
    result[1].add( 100 - totalSoFar )
    result[0].add(fallthroughPool)
  else:
    # -e is handled by putting each file in a separate pool, instead of putting
    # them in one pool as usual. 

    let individualProb = (100 - totalSoFar) / (float) len(fallthroughPool)

    for entry in fallthroughPool:
      result[1].add(individualProb)
      result[0].add(@[entry])


proc printFileList(databases: seq[FortunePool], percentages: seq[float]) =
  for (percentage, db) in zip(percentages, databases):
    echo &"{percentage}% :"
    for file in db:
      echo &"\t{file.datFile.stringCount} {file.path}"

proc printFortune(pools: seq[FortunePool],
                  percentages: seq[float],
                  filter: Filter,
                  printSource: bool) =
  let (fortune, source) = try:
    let picked = pickFromPools(pools, percentages,filter)
    if picked.isNone():
      if filter != nil:
        stderr.writeLine("There were no fortunes to pick from after filter was applied.")
      else:
        stderr.writeLine("There were no fortunes to pick from.")
      quit(QuitFailure)
    else:
      picked.get()
  except FortuneIndexError as e: 
    stderr.writeLine(&"Attempted out of bounds read on '{e.path}'.")
    stderr.writeLine("This may be caused by the .dat file being out of date (regenerate with -strfile)")
    quit(QuitFailure)
  
  if printSource:
    echo &"({source.path})"
  
  # fortunes end with a newline, so we avoid extra ones here
  stdout.write(fortune)

proc searchFortunes(pools: seq[FortunePool],
                    regexString: string, 
                    caseInsensitive: bool = false,
                    printSource: bool = false) =
    
  let regex = try:
    let flags = if caseInsensitive:
      {reStudy, reIgnoreCase}
    else:
      {reStudy}
    re(regexString, flags)
  except RegexError as e:
    # regex exception messages can be multiline so we make them start on their
    # own line
    stderr.writeLine("Error parsing regular expression:")
    stderr.writeLine(e.msg)  
    quit(QuitFailure)

  for pool in pools:
    for file in pool:
      for result in file.filteredFortunes(regex):
        if printSource:
          echo &"({file.path})"
        stdout.write(result)
        echo "%"


proc main() =
  simple_parseopt.no_slash()
  simple_parseopt.dash_dash_parameters()
  simple_parseopt.help_text("Print random quotes")

  let options = get_options:
    c:bool = false {. info("show the cookie file the fortune came from") .}
    e:bool = false {. info("give all specified databases equal probability of being picked") .}
    f:bool = false {. info("print list of files and directories that would be searched without searching them") .}
    l:bool = false {. info("print long fortunes only") .}
    m:string {. info("search through fortunes with a regular expression") .}
    n:uint = 160 {. info("set the threshold in bytes for what is considered a short fortune. Default 160 bytes") .}
    s:bool = false {. info("print short fortunes only") .}
    i:bool = false {. info("make -m searches case insensitive") .}
    strfile:bool = false {. info("generate dat files") .}
    # simple_parseopt apparently can only take a literal here 🤷
    delim:char = '%' {. info("delimiter to use for separating fortunes, when generating dat files, or when existing dat files are not used") .}
    onlydat:bool = false {. info("Only consider fortune files with corresponding .dat files") .}
    nodat:bool = false {. info("Do not use .dat files at all, only use fortune files directly") .}
    files:seq[string] {. info("paths to files or directories to pick fortunes from, or paths to files to generate dat files for (when -delim supplied)") .}

  # --strfile can ignore all other options
  if options.strfile:
    strfile(options.files, options.delim)
    return

  # handle --onlydat and --nodat
  let mode = if options.onlydat and options.nodat:
    stderr.writeLine("--onlydat and --nodat are exclusive to each other")
    quit(QuitFailure)
  elif options.onlydat: 
    amDatOnly
  elif options.nodat:
    amNoDat
  else:
    amBoth

  # handle file path arguments
  let files = if len(options.files) > 0:
    options.files
  else:
     @[""]  # will be appended to the base dir

  let (databases, percentages) = getDatabases(files = files,
                                              mode = mode,
                                              equalProb = options.e,
                                              delim = options.delim)

  # handle printing list of files that would be searched
  if options.f:
    printFileList(databases, percentages)
    return

  # handle regex searches 
  if options.m != "":
    searchFortunes(databases, 
                   regexString=options.m, 
                   caseInsensitive=options.i,
                   printSource=options.c)
    return
  
  # handle setting length thresholds 
  let filter = if options.l and options.s:
    stderr.writeLine("-s (short) and -l (long) options are exclusive to each other")
    quit(QuitFailure)
  elif options.l:
    Filter(filterType: filterGreaterThan, threshold: options.n)
  elif options.s:
    Filter(filterType: filterLessThan, threshold: options.n)
  else:
    nil

  # with no overriding switches, the default is to print a fortune
  printFortune(databases, 
               percentages,
               filter=filter,
               printSource=options.c) 


when isMainModule:
  main()

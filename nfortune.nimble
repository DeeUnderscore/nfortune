# Package

version       = "1.0.0"
author        = "D Anzorge"
description   = "fortune, but in Nim"
license       = "ISC"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nfortune"]



# Dependencies

requires "nim >= 1.2.0",
         "simple_parseopt >= 1.1.0 & < 2.0.0"

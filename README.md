# nfortune
A reimplementation of the Unix `fortune` program in Nim. Displays randomly selected quotes from files provided to it. 

## Details
*nfortune* uses the same file formats and some of the same command line switches as *fortune-mod* 1.99.1. Nevertheless, it offers some extra functionality, while omitting some of the functionality present in *fortune-mod*. Some of the differences are:

* It can operate without pre-generated `.dat` files. If they are missing, it can generate them dynamically in memory, which is fairly viable on a modern computer.
* *nfortune* does not ship with a fortune database. It also does not have the `-o` offensive switch, as it has no offensive fortunes to pick from.
* Fortune database path can be supplied by an environment variable (`NFORTUNE_DATABASE`)
* `.dat` files can be generated with the same binary, using the `--datfile` switch. 
* Output from some of the more esoteric switches, like `-f` (list files), is different
* The algorithm which randomly picks which file will be used is different
* *nfortune* is (probably) slightly slower than the *fortune-mod* `fortune` command

## Building
*nfortune* can be built on Linux systems using Nimble. If you've installed Nim the usual way, you should have `nimble` available. Simply obtain the code (such as by cloning the *nfortune* repository), change to its directory, and then, to compile in debug mode:

```shellsession
$ nimble build 
```

This will produce a `nfortune` binary in the current directory.

To compile and install (into the Nimble bin directory) in release mode:

```shellsession
$ nimble install 
```

Provided you have Nim and Nimble configured the usual way (ie, you have the Nimble `bin/` directory added to `PATH`), you should now be able to issue `nfortune` on the command line. 

Keep in mind that although *nfortune* uses the same fortune database path as *fortune-mod* by default, it does *not* ship with fortune (cookie) files. You will have to supply them yourself (you can use *fortune-mod*'s database).

*nfortune* has not been tested on other operating systems.

## Usage
*nfortune* behaves similarly but not identically to the `fortune` command from *fortune-mod*. For details, please see the manual at [doc/nfortune.6.rst](./doc/nfortune.6.rst). This document can also be built into a manual page, using `rst2man` from the Docutils package.

Example usage:

```shellsession
$ echo 'Hello world!\n%\nGreetings!' > hello
$ nfortune hello
Greetings!
$ nfortune hello
Hello world!
```

## Related projects

*nfortune* is inspired by *fortune-mod*, an updated version of which is available at <https://github.com/shlomif/fortune-mod/>

## Project
*nfortune* is available under the ISC license: see [LICENSE](./LICENSE). 

The project Github repository is at <https://github.com/DeeUnderscore/nfortune>
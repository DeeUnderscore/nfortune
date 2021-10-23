========
nfortune
========

print random quotes from fortune files
=============================================

:Date: 2021-10-23
:Version: 1.0.2
:Manual section: 6
:Manual group: nfortune manual


Synopsis
----------------------

| **nfortune** [ **-ceflsi** ] [ **-m** *pattern* ] [ **-n** *size* ] [ **--nodat** | **--onlydat** ] [ **--delim** *delimiter* ]  [ [ *n*\ **%** ] *file* | *directory* ] ...
| **nfortune** **--strfile** [ **--delim** *delimiter* ]  *file* ...


Description
-----------------------
When called without any arguments, **nfortune** will pick a random fortune from the default database (see ENVIRONMENT section). Alternate file or directory paths can be provided to make **nfortune** search those for fortune files instead. The paths can either be absolute, or relative; in the latter case, current working directory is searched first, and then the default database directory. Unlike *fortune-mod*, **nfortune** will search directories recursively.

Each path can be preceded by an integer probability percentage specifier. These determine how likely that path is to be picked at random, relative to other paths specified. The precentages should add up to 100, and any remaining percentage points will be distributed among paths without percentage specifiers.

Unlike *fortune-mod*, use of ``.dat`` files is optional with **nfortune**. If a ``.dat`` file is not present, **nfortune** will process the fortune file in memory. For *fortune-mod*–like behavior, ``--onlydat`` can be used. 

If invoked with ``--strfile``, **nfortune** will behave like the *strfile* utility, and generate ``.dat`` files. In this case, no fortunes are output.

Options
-----------------------
``--strfile``
    Generate a ``.dat`` file from the listed fortune files. Options other than ``-delim`` are ignored when ``-strfile`` is selected.

``-c``
    Print the file that the fortune came from, in addition to the fortune itself. Printed to stdout.

``-e``
    Give all files equal probability of being selected. The default behavior makes files with more fortunes proportionally more likely to be selected.

``-f``
    Print list of files and directories that would be searched, without searching them. Each group is shown as the percentage probability that this group will be selected, followed by an indented list of files in the group. Each file listed is preceded by the total count of fortunes in it. ``-s`` and ``-l`` are ignored for counting purposes.  

``-l``
    Select long fortunes only. See ``-n`` for what constitutes a long fortune.

``-m`` *pattern* 
    Search through fortunes with a regular expression. Fortunes are printed separated with a ``%`` delimiter. If ``-c`` is also provided, the path of the fortune comes from precedes each fortune. Case sensitive by default (see ``-i``). Unlike *fortune-mod*, everything is printed to stdout.

``-n``
    Threshold in bytes for what is considered a short fortune for the purposes of ``-l`` and ``-s``. Default is 160 bytes.

``-s``
    Print short fortunes only. See ``-n`` for what constitutes a short fortune.

``-i``
    Make ``-m`` searches case-insensitive.

``--delim`` *character*
    Set the delimiter character that separates the fortunes in the input files. Default is ``%``. Must be single byte. This parameter is only used when generating dat files, or when parsing a fortune file without an existing dat file present. 

``--onlydat``
    Only consider fortune files which have a corresponding ``.dat`` file.

``--nodat``
    Do not use ``.dat`` files, even if they are found. Instead, parse the fortune files in memory.

Environment 
-----------------------
``NFORTUNE_DATABASE``
    Path to the default fortune database directory. Fortunes from this directory will be used if nfortune is called without specifying a directory explicitly, and it will also be searched for requested relative paths. If undefined, defaults to **/usr/share/games/fortunes**.


Examples
-------------------
Pick a random fortune from the pool formed by fortunes from the files "foo" and "bar"::

    nfortune foo bar

Pick a random fortune from the files "foo" and "bar", with 70% chance of picking a fortune from "foo", and implicit 30% for "bar"::

    nfortune 70% foo bar

Generate a ``.dat`` file for the file "myAwesomeFortunes", which uses "*" as the delimiter::

    nfortune -strfile -delim '*' myAwesomeFortunes

Fortune file
~~~~~~~~~~~~~

An example fortune file using the default separator, ``%``, and also using UTF-8::

    Hello, I'm the first fortune! 👋
    %
    I'm the second fortune
    and I have two lines!
    %
    and this is the third fortune
    
    it has three lines!
    %
    
nfortune
---------

**nfortune** is available under the ISC license.

The project (and its issue tracker) is hosted at https://github.com/DeeUnderscore/nfortune

See also
--------
fortune(6)

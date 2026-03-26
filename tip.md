```
TIP:          ???
Title:        Add zip-based tclkit build target to static build
Version:      $Revision: 1.0 $
Author:       Steve Landers <steve@digitalsmarties.com>
Author:       Eric <et99@rocketship1.biz>
State:        Draft
Type:         Project
Tcl-Version:  9.1
Vote:         Pending
Created:      24-Mar-2026
Post-History:
```

## Abstract

This TIP proposes adding a zip-based tclkit build target to the static
build process for both Tcl and Tk. When a static build is performed,
the build system would automatically produce a self-contained tclkit
executable -- a single file containing the Tcl/Tk runtime, standard
libraries, and a built-in tool for creating, wrapping and unwrapping
zip-based starpacks. This restores the single-file application
distribution capability that has been central to the Tcl ecosystem for
over 20 years, now using Tcl 9's built-in zipfs infrastructure instead
of the Metakit-based tclkit system.

## Background

The tclkit/starpack system has been a popular way to distribute
self-contained Tcl applications as single executable files since the
early 2000s. The workflow was simple: download a tclkit executable and
an sdx.kit tool, wrap your application, distribute a single .exe.

With Tcl 9, the Metakit-based tclkit system is no longer actively
maintained and does not work reliably with Tcl 9. However, Tcl 9
includes built-in zipfs support which provides a natural foundation
for a zip-based equivalent. The zipfs mkimg command can append a zip
archive to an executable, and the result mounts automatically at
startup -- all the infrastructure needed is already present in Tcl 9.

What is currently missing is:

1. A statically built wish/tclsh with the standard libraries bundled
   inside it, produced as part of the official build process
2. A user-facing tool equivalent to sdx.kit for creating, wrapping
   and unwrapping starpacks

This TIP addresses both by proposing that the static build
automatically produce a tclkit executable, and that the tool
functionality be built into that executable rather than distributed
as a separate file as sdx.kit was.

## Specification

### Source tree additions

Two files are added to the Tcl source tree under library/zipkit/:

- **ziptool.tcl** -- a pure Tcl tool providing qwrap, wrap, unwrap
  and readkit commands, plus the bootstrap code to create the
  initial tclkit executable
- **readkit.tcl** -- JCW's original pure-Tcl Metakit reader,
  unmodified, bundled for backward compatibility with old Metakit
  starpacks and starkits

### Build system changes

A final step is added to the static build target in both
makefile.vc (MSVC/Windows) and the autoconf/make build system
(MinGW/Windows, Linux, macOS):

1. Copy ziptool.tcl and readkit.tcl to the bin directory
2. Run the just-built static tclsh or wish against ziptool.tcl to
   produce the tclkit executable

For the Tcl static build this produces tclkit91t (console, no Tk).
For the Tk static build this produces tclkit91w (GUI, includes Tk).

The base name defaults to tclkit but can be overridden on the
command line. The version number and w/t suffix are appended
automatically.

### The tclkit executable

The resulting tclkit executable contains:
- The static Tcl/Tk runtime (no external DLL dependencies)
- tcl_library bundled in the appended zip
- tk_library bundled in the appended zip (wish-based only)
- main.tcl handling interactive mode and command dispatch
- ziptool.tcl providing the wrap/unwrap commands
- readkit.tcl for Metakit backward compatibility

### Directory structure compatibility

The zip-based starpack uses the same directory structure as the old
tclkit system. The application code is packaged as a Tcl package in
the lib directory, and main.tcl loads it with a package require
command -- exactly as before. After a qwrap or unwrap, the user can:

- Add additional code to the application package
- Bundle third-party packages by copying them into the lib directory
- Use wrap to produce a new starpack in the same workflow as the
  old tclkit/sdx system

This means existing knowledge of the tclkit/sdx workflow transfers
directly to the new system.

### Commands

When invoked with no arguments, the tclkit starts in interactive
mode -- opening a console under wish or providing a command prompt
under tclsh -- making it a general-purpose Tcl interpreter as well
as a packaging tool.

When invoked with a known subcommand as the first argument, the
tclkit dispatches to the appropriate tool function:

**qwrap** -- creates a starpack from a single Tcl script:
```
tclkit91w qwrap script.tcl ?-runtime|-run tclkit?
```

**wrap** -- packages a .vfs folder into a starpack:
```
tclkit91w wrap appname.vfs ?-runtime|-run tclkit?
```

**unwrap** -- extracts a zip-based starpack to a .vfs folder:
```
tclkit91w unwrap starpack.exe
```

**readkit** -- extracts an old Metakit starpack or starkit:
```
tclkit91w readkit oldapp.exe
tclkit91w readkit oldapp.kit
```

When invoked with any other first argument, it is treated as a
script to source, making the tclkit a general-purpose Tcl interpreter
as well as a packaging tool.

### Backward compatibility

The zip-based starpack format is not compatible with the old
Metakit-based format. Old starpacks cannot be run directly by the
new tclkit. However the readkit command uses the bundled
readkit.tcl to extract old Metakit starpacks and starkits, allowing
migration to the new format.

## Implementation

A reference implementation is available at:
https://github.com/rocketship88/zipkit


The implementation is a single pure-Tcl file (ziptool.tcl) of
approximately 500 lines. It has been tested on Windows with Tcl 9.1a1
and demonstrates the complete workflow: bootstrap from a static build,
qwrap, unwrap, wrap, and readkit of old Metakit starpacks.

## Copyright

This document is placed in the public domain.

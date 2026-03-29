# zipkit

A zip-based implementation of the tclkit/starpack system for Tcl 9,
using Tcl 9's built-in zipfs infrastructure instead of Metakit.

## Background

The tclkit/starpack system has been a popular way to distribute
self-contained Tcl applications as single executable files for over
20 years. With Tcl 9, the built-in zipfs subsystem provides a natural
foundation for a zip-based equivalent.

This project was developed by Eric with assistance from Claude
(claude.ai) as a proof of concept, and is intended as a candidate for
incorporation into the Tcl core build system via a TIP. Steve Landers,
one of the original tclkit authors, has provided guidance and will
assist with the TIP and fossil integration.

Note: efforts are also underway to get the original Metakit-based
tclkit working with Tcl 9.1. zipkit is an alternative approach, not
necessarily a replacement.

## How it works

A tclkit executable is a statically built wish or tclsh with a zip
archive appended containing tcl_library, tk_library, a minimal
main.tcl and the ziptool.tcl utility code. This is functionally
equivalent to the old tclkit, just using zip instead of Metakit as
the virtual filesystem format.

## Prerequisites

- A static build of Tcl/Tk 9.1 or later, producing wish91s.exe
  and/or tclsh91s.exe
- readkit.tcl placed alongside the static executable (for readkit
  support of old Metakit starpacks and starkits)
- ziptool.tcl placed alongside the static executable

## Bootstrap

To create the initial tclkit executable from a static build:

```batch
cd /path/to/static/build/bin
wish91s.exe ziptool.tcl
```

This produces tclkit91w.exe (wish/GUI based) or tclkit91t.exe
(tclsh/console based) depending on which static executable is used.

Static build required -- Dynamic builds do not have tcl_library and tk_library bundled in the executable itself -- they are stored in the DLL instead. Attempting to use a dynamic build will fail with "archive directory end signature not found".

The output base name defaults to **tclkit** (as in the original system)
but can be overridden by passing a name as the first argument after
ziptool.tcl:

```batch
wish91s.exe ziptool.tcl zipkit
```

Which would produce zipkit91w.exe or zipkit91t.exe. The version number
and w/t suffix are always appended automatically based on the running
Tcl version and whether wish or tclsh is used.

Some suggested names:
- **tclkit** -- matches the original naming convention
- **zipkit** -- makes it clear this is the zip-based variant

## Commands

### qwrap
```
tclkit91w.exe qwrap script.tcl ?-runtime|-run tclkit.exe?
```
Creates a starpack from a single Tcl script. Produces script.exe
containing the script packaged as app-script, with tcl_library and
tk_library bundled in.

### unwrap
```
tclkit91w.exe unwrap script.exe
```
Extracts a zip-based starpack into a folder script.vfs containing
main.tcl and lib/ ready for editing. The .vfs extension is used
for the output folder by convention.

### wrap
```
tclkit91w.exe wrap appname.vfs ?-runtime|-run tclkit.exe?
```
Packages a .vfs folder into a starpack exe. The .vfs extension is
required on the input folder. The output exe uses the same base name
as the .vfs folder -- so appname.vfs produces appname.exe and
script.vfs produces script.exe, making it natural to re-wrap after
unwrapping and editing. Overwrites existing output with a notice.

### readkit
```
tclkit91w.exe readkit oldstarpack.exe
tclkit91w.exe readkit oldstarkit.kit
```
Extracts an old Metakit-based starpack or starkit using readkit.tcl.
Produces a .vfs folder in the same directory as the input file.
Accepts both .exe starpacks and .kit starkits. Requires readkit.tcl
to be bundled inside the tclkit (done automatically during bootstrap).

## Example workflow

```batch
# Create a starpack from hello.tcl
tclkit91w.exe qwrap hello.tcl

# Run it
hello.exe

# Unwrap for editing
tclkit91w.exe unwrap hello.exe

# Edit hello.vfs/lib/app-hello/hello.tcl

# Re-wrap
tclkit91w.exe wrap hello.vfs

# Run the updated version
hello.exe
```

## Notes

**No separate .kit files** -- unlike the old tclkit/sdx system which
could produce standalone .kit starkits, zipkit always produces a
single self-contained .exe starpack. There is no intermediate .kit
format. This simplifies the workflow -- one command, one executable.

**Windows only for now** -- the current implementation targets Windows
and produces .exe files. Linux and macOS support is possible in the
future since zipfs is cross-platform, but would require adjustments
to the bootstrap and output naming (no .exe extension on those
platforms).

## Comparison with old tclkit/sdx

| Old system | zipkit |
|---|---|
| tclkit.exe | tclkit91w.exe |
| tclsh sdx.kit qwrap | tclkit91w.exe qwrap |
| tclsh sdx.kit wrap | tclkit91w.exe wrap |
| tclsh sdx.kit unwrap | tclkit91w.exe unwrap |
| N/A | tclkit91w.exe readkit |

The key difference is that sdx was a separate tool requiring a tclkit
to run it. With zipkit, the tool functionality is built into the
executable itself -- one file does everything.

## Files

- **ziptool.tcl** -- the main tool, bootstraps the zipkit and provides
  qwrap/wrap/unwrap/readkit commands
- **readkit.tcl** -- JCW's original pure-Tcl Metakit reader (unmodified),
  bundled into the tclkit for readkit support
- **starkit.tcl** -- Keith's starkit compatibility package

## Related Work

Keith Nash has developed a `starkit` 2.0 package (`starkit.tcl`) 
included in this repository that provides compatibility with old 
Metakit-based starkits and zip-based starkits. If integrated into 
the tclkit lib folder it would allow running old .kit files 
transparently by sourcing them directly -- the kit file's own header 
calls either `starkit::header mk4` or `starkit::header zip` and the 
package handles the appropriate mounting or extraction.

Integration is not yet implemented but should not be particularly 
difficult. See the email thread on tcl-core for discussion.

## License

MIT

# ziptool.tcl - zip-based tclkit/starpack tool for Tcl 9
#
# Copyright (c) 2025 Eric Taylor
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

namespace eval ::ziptool {}
proc ::ziptool::dispatch {cmd args} {
#    puts "inside ::ziptool::dispatch cmd = |$cmd| args = |$args|"
     
    if {$cmd eq "qwrap"} {
        ::ziptool::qwrap {*}$args
    } elseif {$cmd eq "wrap"} {
        ::ziptool::wrap {*}$args
    } elseif {$cmd eq "unwrap"} {
        ::ziptool::unwrap {*}$args
    } elseif {$cmd eq "readkit"} {
        ::ziptool::readkit {*}$args
    } elseif {$cmd eq "create"} {
        # TODO: implement ::ziptool::create as a dispatched command
    } else {
        error "::ziptool::dispatch: unknown command |$cmd|, expected one of: qwrap wrap unwrap readkit create"
    }
}
proc ::ziptool::reconstruct {procname} {
# reconstruct derived from Ashok's tcl book
    set procname [uplevel 1 [list namespace which -command $procname]]
    set args {}
    foreach arg [info args $procname] {
        if {[info default $procname $arg def]} {
            lappend args [list $arg $def]
        } else {
            lappend args $arg
        }
    }
    return "proc $procname [list $args] [list [info body $procname]]"
}
proc ::ziptool::copydir {src dst} {
    file mkdir $dst
    foreach f [glob -nocomplain -directory $src *] {
        set tail [file tail $f]
        if {[file isdirectory $f]} {
            ::ziptool::copydir $f [file join $dst $tail]
        } else {
            file copy -force $f [file join $dst $tail]
        }
    }
}


proc ::ziptool::wrap {args} {
    # Validate we got at least a folder argument
    if {[llength $args] == 0} {
        error "wrap: missing folder argument\nusage: wrap appname.vfs ?-runtime|-run tclkit.exe?"
    }

    # First argument must be the .vfs folder
    set vfsDir [file normalize [lindex $args 0]]
    set args [lrange $args 1 end]

    # Validate .vfs extension
    if {[file extension $vfsDir] ne ".vfs"} {
        error "wrap: folder must have .vfs extension: |$vfsDir|"
    }

    # Validate folder exists and is a directory
    if {![file exists $vfsDir] || ![file isdirectory $vfsDir]} {
        error "wrap: folder not found or not a directory: |$vfsDir|"
    }

    # Derive output exe name from folder name
    set outputExe [file normalize "[file rootname $vfsDir].exe"]

    # Determine runtime - default to currently running executable
    set runtime [info nameofexecutable]
    set idx [lsearch $args -runtime]
    if {$idx < 0} {
        set idx [lsearch $args -run]
    }
    if {$idx >= 0} {
        if {$idx+1 >= [llength $args]} {
            error "wrap: -runtime|-run requires a filename argument"
        }
        set runtime [file normalize [lindex $args $idx+1]]
    }

    # Check for any unrecognized options
    foreach arg $args {
        if {[string match -* $arg]} {
            if {$arg ne "-runtime" && $arg ne "-run"} {
                error "wrap: unrecognized option |$arg|, expected: -runtime|-run"
            }
        }
    }

    # Validate runtime exists and is a file
    if {![file exists $runtime] || ![file isfile $runtime]} {
        error "wrap: runtime not found or not a file: |$runtime|"
    }

    # Notify if overwriting existing output
    if {[file exists $outputExe]} {
        puts "note: overwriting existing |$outputExe|"
        file delete -force $outputExe
    }

    # Create temp directory in system temp folder with PID to avoid conflicts
    set tmpDir [file join $::env(TEMP) _ziptool_tmp_[pid]]
    file delete -force $tmpDir
    file mkdir $tmpDir

    # Mount runtime exe and copy tcl_library and tk_library to temp
    if {[catch {
        zipfs mount $runtime //zipfs:/ziptool_tmp
    } err]} {
        file delete -force $tmpDir
        error "wrap: failed to mount runtime |$runtime|: $err"
    }
    foreach f [glob -nocomplain -directory //zipfs:/ziptool_tmp *] {
        set tail [file tail $f]
        if {$tail in {tcl_library tk_library}} {
            file copy -force $f $tmpDir
        }
    }
    zipfs unmount //zipfs:/ziptool_tmp

    # Copy contents of .vfs folder into temp
    foreach f [glob -nocomplain -directory $vfsDir *] {
        file copy -force $f $tmpDir
    }

    # Create the starpack
    if {[catch {
        zipfs mkimg $outputExe $tmpDir $tmpDir {} $runtime
    } err]} {
        file delete -force $tmpDir
        error "wrap: zipfs mkimg failed: $err"
    }

    # Clean up temp directory
    file delete -force $tmpDir

    puts "wrapped to: |$outputExe|"
}

proc ::ziptool::unwrap {args} {
    # Validate we got a file argument
    if {[llength $args] == 0} {
        error "unwrap: missing starpack argument\nusage: unwrap starpack.exe"
    }

    set file [file normalize [lindex $args 0]]

    # Validate file exists and is a file
    if {![file exists $file] || ![file isfile $file]} {
        error "unwrap: file not found or not a file: |$file|"
    }

    # Derive output folder name
    set outDir [file normalize "[file rootname $file].vfs"]

    # Check output folder doesn't already exist
    if {[file exists $outDir]} {
        error "unwrap: output directory already exists: |$outDir|"
    }

    # Mount the starpack zip
    if {[catch {
        zipfs mount $file //zipfs:/unwrap_tmp
    } err]} {
        error "unwrap: failed to mount |$file|: $err"
    }

    # Copy contents skipping runtime files
    foreach f [glob -nocomplain -directory //zipfs:/unwrap_tmp *] {
        set tail [file tail $f]
        if {$tail ni {tcl_library tk_library ziptool.tcl readkit.tcl}} {
            if {[file isdirectory $f]} {
                ::ziptool::copydir $f [file join $outDir $tail]
            } else {
                file copy -force $f $outDir
            }
        }
    }

    zipfs unmount //zipfs:/unwrap_tmp

    puts "unwrapped to: |$outDir|"
}
proc ::ziptool::create {sourceExe outputExe} { 
    set myscript [info script]
#    puts "myscript= |$myscript| "
    # Normalize to absolute paths
    set sourceExe [file normalize $sourceExe]
    set outputExe [file normalize $outputExe]
    file delete -force $outputExe
    # Create temp directory in system temp folder with PID to avoid conflicts
    set tmpDir [file join $::env(TEMP) _ziptool_tmp_[pid]]
    file delete -force $tmpDir
    file mkdir $tmpDir

    # Mount source exe and copy its existing zip contents to temp dir
    zipfs mount $sourceExe //zipfs:/ziptool_tmp
    foreach f [glob -nocomplain -directory //zipfs:/ziptool_tmp *] {
        file copy -force $f $tmpDir
    }
    # copy this file also (only copy it's procs, not the bootstrap code)
    set f [open [file join $tmpDir "ziptool.tcl"] w]
    puts $f "namespace eval ::ziptool {}\n"
    foreach procedure {
        ::ziptool::dispatch
        ::ziptool::reconstruct
        ::ziptool::create
        ::ziptool::qwrap
        ::ziptool::readkit
        ::ziptool::unwrap
        ::ziptool::wrap
        ::ziptool::copydir
    } {
        puts $f "[::ziptool::reconstruct $procedure]\n\n"
    }
#    puts $f {;#debugger extras can be included here
#    }    
    close $f
    
    file copy -force readkit.tcl $tmpDir
    # Append exit to ensure tclsh/wish exits when done
    set tmpReadkit [file join $tmpDir readkit.tcl]
    set f [open $tmpReadkit a]
    puts $f "\nexit 0"
    close $f
    
    zipfs unmount //zipfs:/ziptool_tmp
    
    set f [open [file join $tmpDir main.tcl] w]

    set main_code {
lappend auto_path //zipfs:/app/lib

if {$argc == 0} {
    set ::tcl_interactive 1
#    puts "interactive mode, argc is 0"

    if {[info exists tk_version]} {
#        puts "wish"
        catch {console show}
        # Tk event loop will take over automatically
    } else {
#        puts "tclsh"

        set buffer ""
        while {1} {
            if {$buffer eq ""} {
                puts -nonewline "% "
            } else {
                puts -nonewline "> "
            }
            flush stdout

            if {[gets stdin line] < 0} {
                puts ""
                break
            }

            append buffer $line "\n"

            if {[info complete $buffer]} {
                if {[catch {uplevel #0 $buffer} result]} {
                    puts stderr $result
                } elseif {$result ne ""} {
                    puts $result
                }
                set buffer ""
            }
        }
        exit
    }

} else {
    set script [lindex $argv 0]
    set ::argv0 $script
    set ::argv [lrange $argv 1 end]
    set ::argc [llength $::argv]

    if {[info exists tk_version]} {
        catch {console show}
    }

    if {$script in {qwrap wrap unwrap create readkit}} {
#        puts "dispatch with script= |$script| ::argv= |$::argv|"
        source //zipfs:/app/ziptool.tcl
        
        catch {pack [button .exit -text Exit -command exit] -fill both ; update} 
        if {[catch {
        	 ::ziptool::dispatch $script {*}$::argv
        } msg opts]} {
            # Detect if Tk is available (i.e., running under wish)
            if {[info commands tk_messageBox] ne ""} {
                tk_messageBox -icon error -type ok -message $msg
            } else {
                puts stderr $msg
            }
            exit 1
        }
        
        
    
    } else {
        if {[file exists $script]} {
            source $script
        } else {
            set msg "Could not find script (or mispelled command): $script"
            if {[info commands tk_messageBox] ne ""} {
                tk_messageBox -icon error -type ok -message $msg
            } else {
                puts stderr $msg
            }
            exit 1
        }
    }
}

} ;# end of main_code set

    puts $f $main_code
    close $f

    # Create the new zipkit by appending zip to a copy of sourceExe
    # sourceExe is used as template so its executable header is preserved
    if {[catch {
        zipfs mkimg $outputExe $tmpDir $tmpDir {} $sourceExe
    } err]} {
        # Clean up temp directory on error
        file delete -force $tmpDir
        error "zipfs mkimg failed: $err"
    }

    # Clean up temp directory on success
#    puts "tmpDir= |$tmpDir| "
    file delete -force $tmpDir
}


proc ::ziptool::qwrap {args} {
    # Validate we got at least a script argument
    if {[llength $args] == 0} {
        error "qwrap: missing script argument\nusage: qwrap script.tcl ?-runtime|-run tclkit.exe?"
    }

    # First argument must be the script
    set script [file normalize [lindex $args 0]]
    set args [lrange $args 1 end]

    # Validate script exists and is a file
    if {![file exists $script] || ![file isfile $script]} {
        error "qwrap: script not found or not a file: |$script|"
    }

    # Derive app name and output exe name from script filename
    set appname [file rootname [file tail $script]]
    set outputExe [file normalize "[file rootname $script].exe"]

    # Determine runtime - default to currently running executable
    set runtime [info nameofexecutable]
    set idx [lsearch $args -runtime]
    if {$idx < 0} {
        set idx [lsearch $args -run]
    }
    if {$idx >= 0} {
        # Validate a value follows -runtime/-run
        if {$idx+1 >= [llength $args]} {
            error "qwrap: -runtime|-run requires a filename argument"
        }
        set runtime [file normalize [lindex $args $idx+1]]
    }

    # Check for any unrecognized options
    foreach arg $args {
        if {[string match -* $arg]} {
            if {$arg ne "-runtime" && $arg ne "-run"} {
                error "qwrap: unrecognized option |$arg|, expected: -runtime|-run"
            }
        }
    }

    # Validate runtime exists and is a file
    if {![file exists $runtime] || ![file isfile $runtime]} {
        error "qwrap: runtime not found or not a file: |$runtime|"
    }

    # Create temp directory in system temp folder with PID to avoid conflicts
    set tmpDir [file join $::env(TEMP) _ziptool_tmp_[pid]]
    file delete -force $tmpDir
    file mkdir $tmpDir

    # Mount runtime exe and copy its existing zip contents to temp dir
    # Skip main.tcl, ziptool.tcl and readkit.tcl - we will create our own main.tcl
    # and ziptool.tcl and readkit.tcl are not needed in user's starpack
    if {[catch {
        zipfs mount $runtime //zipfs:/ziptool_tmp
    } err]} {
        file delete -force $tmpDir
        error "qwrap: failed to mount runtime |$runtime|: $err"
    }
    foreach f [glob -nocomplain -directory //zipfs:/ziptool_tmp *] {
        set tail [file tail $f]
        if {$tail ni {main.tcl ziptool.tcl readkit.tcl}} {
            file copy -force $f $tmpDir
        }
    }
    zipfs unmount //zipfs:/ziptool_tmp

    # Create lib/app-appname directory structure
    set appDir [file join $tmpDir lib app-$appname]
    file mkdir $appDir

    # Read user's script
    if {[catch {
        set f [open $script r]
        set scriptdata [read $f]
        close $f
    } err_code]} {
        error "qwrap: error reading script file |$script|: $err_code"
    }

    # Write script into appDir with package provide prepended
    set f [open [file join $appDir $appname.tcl] w]
    puts $f "package provide app-$appname 1.0"
    puts $f $scriptdata
    close $f

    # Write pkgIndex.tcl into appDir
    set f [open [file join $appDir pkgIndex.tcl] w]
    puts $f "package ifneeded app-$appname 1.0 \[list source \[file join \$dir $appname.tcl\]\]"
    close $f

    # Write main.tcl into tmpDir
    set f [open [file join $tmpDir main.tcl] w]
    puts $f "lappend auto_path //zipfs:/app/lib"
    puts $f "package require app-$appname"
    close $f

    # Create the starpack by appending zip to runtime
    if {[catch {
        zipfs mkimg $outputExe $tmpDir $tmpDir {} $runtime
    } err]} {
        file delete -force $tmpDir
        error "qwrap: zipfs mkimg failed: $err"
    }
#    puts "tmpDir=    |$tmpDir| "
#    puts "appDir=    |$appDir| "
#    puts "outputExe= |$outputExe| "
    # Clean up temp directory
    file delete -force $tmpDir

    puts "wrapped to: |$outputExe|"
}
proc ::ziptool::readkit {file} {
    # Normalize before cd so we don't lose track of it
    set file [file normalize $file]
    
    # Extract readkit.tcl from our own zip to a temp file
    set tmpReadkit [file join $::env(TEMP) readkit_[pid].tcl]
    file copy -force //zipfs:/app/readkit.tcl $tmpReadkit
    
    # cd to input file's directory so .vfs appears next to it
    set savedDir [pwd]
    cd [file dirname $file]
    
    if {[catch {
        puts "starting extraction of $file" ; update
        exec [info nameofexecutable] $tmpReadkit -x $file
        puts "Finished extraction of $file"
    } err]} {
        cd $savedDir
        file delete -force $tmpReadkit
        error "readkit: extraction failed: $err"
    }
    
    cd $savedDir
    file delete -force $tmpReadkit
}

# bootstrap (and possibly debug) code
# this is run only during the creation of the first zipkit
# it is not included in that zipkit however

set exename [file tail [info nameofexecutable]]
set ver [string map {. {}} [info tclversion]]
set base_name "tclkit"
if { $::argc > 0 } {
	set base_name [lindex $::argv 0]
}

if {[string match *wish* $exename]} {
    set outexe "${base_name}${ver}w.exe"
} else {
    set outexe "${base_name}${ver}t.exe"
}
catch {console show;wm withdraw .; puts "---- Creating $outexe" ;update}
cd [file dirname [info nameofexecutable]]
::ziptool::create [info nameofexecutable] $outexe
update
puts "-------------------------->  Created $outexe"
if {[string match *wish* $exename]} {
    after 5000 {exit 0}
} else {
    exit 0
}






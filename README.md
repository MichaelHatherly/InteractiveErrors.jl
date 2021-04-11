# InteractiveErrors.jl

Interactive error messages for the Julia REPL.

![demo](https://user-images.githubusercontent.com/6144086/113480599-fc0d6280-948c-11eb-9dd2-19fa3a85ff59.gif)

## Installation

Requires Julia `1.6+`.

```
julia> using Pkg

julia> Pkg.add("InteractiveErrors")
```

Add `using InteractiveErrors` to your `startup.jl` file after `using Revise`.
If you don't have that installed yet you should install it.

## Usage

Just start using your REPL normally. Once you hit an error you'll be presented
with an interactive tree representing your stacktrace which you can explore.

Press `up` and `down` arrows to move through the stacktrace. Press `space` to
fold or unfold the currently selected line. A `+` will appear on folded lines.
Press `enter` once finished. If you are on a line that references a particular
file then that will present additional options in the next menu. `q` can be
pressed to exit back to the REPL.

**Note:** a lot of information is hidden inside some of the folded lines and
some is completely stripped from the display (such as method arguments). The
default choice of information to display is up for discussion. Unfolding a
line containing a file and line number will display the immediate lines
surrounding it.

The second menu offers several actions that can be taken on the selected line.

```
[press: d=done, a=all, n=none]
 • [ ] ascend
   [ ] descend
   [ ] JET
   [ ] edit
   [ ] retry
   [ ] breakpoint
   [ ] less
   [ ] clipboard
   [ ] print
   [ ] stacktrace
   [ ] exception
   [ ] backtrace
```

Press `enter` to choose the currently selected line. More than one can be chosen:

  - `ascend` (available if `Cthulhu` is loaded) calls `Cthulhu.ascend` on the selected method.
  - `descend` (available if `Cthulhu` is loaded) calls `Cthulhu.descend` on the selected method.
  - `JET` (available if `JET` is loaded) calls `JET.report_call` on the selected method.
  - `edit` opens default editor on the selected file and line.
  - `retry` runs the code entered in the REPL again.
  - `breakpoint` (available if `Debugger` is loaded) sets a `Debugger.breakpoint` on the selected file and line.
  - `less` opens the pager on the selected file and line.
  - `clipboard` copies the normal Julia stacktrace to the clipboard. Useful for
    posting bug reports. Don't send the interactive printout as an error
    message when reporting issues to packages or Julia.
  - `print` prints out the normal Julia stacktrace to `stdout`.
  - `stacktrace` returns the stacktrace object.
  - `exception` returns the exception object that was caught.
  - `backtrace` returns the *raw* backtrace object. Contains `Ptr`s. Not
    terribly useful.

More than one action can be selected at once. A common combination is `edit`
and `retry`. Press `d` (for done) once you're finished making your choices.

## Themes

Most of the default coloring in the stack-tree can be adjusted to the user's
liking via a simple theming system.

  - `current_theme()` returns the currently active theme: a nested `NamedTuple`
    of customisation options.

  - `set_theme!` can be used to set your own custom theme that follows the same
    naming scheme as the default theme. Takes either keyword arguments, or a
    `NamedTuple`.

  - `reset_theme!` will reset the theme.

  - `adjust_theme!` can be used if you only want to make some minor adjustments
    to the `current_theme`. Takes a `NamedTuple` or keyword arguments that will
    be `merge`d with the `current_theme`.

The default theme is shown below:

```
julia> pairs(current_theme())
pairs(::NamedTuple) with 16 entries:
  :function_name   => (bold = true,)
  :directory       => (color = :light_black,)
  :filename        => (color = :magenta, bold = true)
  :line_number     => (color = :green, bold = true)
  :user_stack      => (color = :green, bold = true)
  :system_stack    => (color = :red, bold = true)
  :stdlib_module   => (color = :yellow,)
  :base_module     => (color = :blue,)
  :core_module     => (color = :light_black,)
  :package_module  => (color = :cyan, bold = true)
  :unknown_module  => (color = :red,)
  :inlined_frames  => (color = :light_black,)
  :toplevel_frames => (color = :light_black,)
  :repeated_frames => (color = :red,)
  :file_contents   => (color = :light_black,)
  :line_range      => (before = 0, after = 5)
```

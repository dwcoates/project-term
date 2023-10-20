
![ProjectTerm Search Example](https://github.com/dwcoates/project-term/blob/master/images/project-term-search-example.png)

# Prerequisites

ProjectTerm depends on Telescope and ToggleTerm, both of which are included in Lunarvim as of this writing.

# Installation 

After installing from this repository using your package manager (e.g., by adding `{dwcoates/project-term}` to your `lazy.nvim` initialization list), you can configure `project-term` with the following:

```lua
local projectterm = require('projectterm').projectterm

lvim.keys.normal_mode["<leader>X"] = ":ProjectTerm<CR>"
```

If you install manually from source, you'll need to adjust the `require('projectterm')` path accordingly.

# Usage 

`:ProjectTerm` (or the above `<leader>X` binding) will kick off a Telescope search for the previously input shell commands, and automatically launch the selection in a terminal popup. 

By default, the popup will exit if the command is successful, and stay open on failure. To view the output of the last closed terminal, do `:buffer ProjectTerm output`.

Command history is project-specific, which is decided with `git`.

To view debug output, do `:buffer ProjectTerm debug`.

You can edit the recent commands history by editing `/path/to/git/project/.projectterm_commands`.

**NOTE:** To choose the input text (rather than the selected text), you need to do `<leader>\` in normal mode.

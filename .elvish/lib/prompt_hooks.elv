# Convenience functions to add hooks to the prompt hook lists.
# Diego Zamboni <diego@zzamboni.org>
# 
# $edit:before-readline hooks are executed before right after the prompt is shown
# $edit:after-readline hooks are executed after the user presses Enter, before
#   the command is executed. The typed command is passed as argument.
#
# Use like this:
# prompt_hooks:add-before-readline { code to execute }
# prompt_hooks:add-after-readline { code to execute }
#
# Multiple hooks can be added, they execute in sequence.

fn add-before-readline [hook]{
  edit:before-readline=[ $@edit:before-readline $hook ]
}

fn add-after-readline [hook]{
  edit:after-readline=[ $@edit:after-readline $hook ]
}

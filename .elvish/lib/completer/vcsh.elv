# Completer for vcsh - https://github.com/RichiH/vcsh
# Diego Zamboni <diego@zzamboni.org>

# Return all elements in $l1 except those who are already in $l2
fn all-except [l1 l2]{
	if (eq (count $l2) 0) {
		put $@l1
	} else {
		put (echo (joins "\n" $l1) | egrep -v -- (joins "|" $l2))
	}
}

fn vcsh_completer [cmd @rest]{
	n = (count $rest)
	repos = [(vcsh list)]
	if (eq $n 1) {
		# Extract valid commands and options from the vcsh help message itself
		cmds = [(vcsh 2>&1 | grep '^   [a-z-]' | grep -v ':$' | awk '{print $1}')]
		put $@repos $@cmds
	} elif (eq $n 2) {
		# Subcommand- or option-specific completions
		if (eq $rest[0] "-c") {
			put (edit:complete-filename $rest[1])
		} elif (re:match "delete|enter|rename|run|upgrade|write-ignore|list-tracked" $rest[0]) {
			put $@repos
		} elif (eq $rest[0] "list-untracked") {
			put $@repos "-a" "-r"
		} elif (eq $rest[0] "status") {
			put $@repos "--terse"
		}
	} elif (> $n 2) {
		# For more than two arguments, we recurse, removing any options that have been typed already
		# Not perfect but it allows completion to work properly after "vcsh status --terse", for example,
		# without too much repetition
		put (all-except [(vcsh_completer $cmd (explode $rest[0:(- $n 1)]))] $rest[0:(- $n 1)])
	}
}

edit:arg-completer[vcsh] = [@arg]{ vcsh_completer $@arg }

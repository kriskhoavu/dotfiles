#!/bin/sh
# Hand a file from lazygit to the nvim instance hosting it.
#
# lazygit runs this as `os.edit` (see ../lazygit-nvim.yml). Because lazygit is a
# terminal job of that nvim, $NVIM holds the parent's RPC socket, so this can
# call back in instead of starting a nested editor.
#
# $LAZYGIT_NVIM_FN names the Lua function to call, so each float can hand the
# file to its own handler -- the single-repo one hides one window, the org-wide
# one also has a tabline to drop. Defaults to the single-repo handler.
#
# Usage: lazygit-open.sh <file> [line]

set -eu

if [ -z "${NVIM:-}" ]; then
	printf 'lazygit-open: $NVIM is unset -- not running inside nvim\n' >&2
	exit 1
fi

file=${1:?lazygit-open: no file given}
line=${2:-0}

# lazygit reports paths relative to the repo root, which is its working
# directory. nvim's own cwd may be elsewhere, so resolve before handing it over.
case $file in
/*) ;;
*) file=$PWD/$file ;;
esac

# The path travels as a luaeval argument rather than being pasted into the
# expression, so spaces and quotes in a filename cannot break out. Only the
# Vimscript list literal needs escaping, and there a single quote doubles.
escaped=$(printf '%s' "$file" | sed "s/'/''/g")

fn=${LAZYGIT_NVIM_FN:-LazygitOpenFile}

exec nvim --server "$NVIM" --remote-expr \
	"luaeval('${fn}(_A[1], _A[2])', ['$escaped', $line])"

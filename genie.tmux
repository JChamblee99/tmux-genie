#!/usr/bin/env bash
# tmux-genie: natural language -> shell command, with review-before-run

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1")"
  echo "${value:-$2}"
}

key="$(get_tmux_option "@genie_key" "C-g")"
no_prefix="$(get_tmux_option "@genie_no_prefix" "off")"

# With @genie_no_prefix on, bind in the root table: the key fires
# directly, no prefix needed. Pick a key nothing inside tmux uses (M-g, F12).
bind_args=()
[ "$no_prefix" = "on" ] && bind_args+=("-n")

# command-prompt substitutes %% with the user's input.
# run-shell -b runs in the background so tmux isn't blocked while claude thinks.
# #{pane_id} is expanded by run-shell, so the command lands in the pane
# that was active when you pressed the key, even if you switch panes meanwhile.
tmux bind-key "${bind_args[@]}" "$key" command-prompt -p "claude> " \
  "run-shell -b \"$CURRENT_DIR/scripts/prompt.sh '#{pane_id}' '%%'\""

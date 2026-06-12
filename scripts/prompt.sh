#!/usr/bin/env bash
# Queries claude for a shell command and types it into the target pane
# WITHOUT executing it. Press Enter to run, edit it, or Ctrl-C to discard.
#
# Refinement: if the previously generated command is still sitting unexecuted
# at the prompt when you invoke this again, it is treated as a rejection.
# The line is cleared and claude is re-queried with the prior request, the
# rejected command, and your new instruction as context.

set -u

PANE_ID="$1"
shift
INPUT="$*"

get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1")"
  echo "${value:-$2}"
}

get_pane_option() {
  tmux show-option -pqvt "$PANE_ID" "$1" 2>/dev/null
}

set_pane_option() {
  tmux set-option -pt "$PANE_ID" "$1" "$2" 2>/dev/null
}

CLAUDE_BIN="$(get_tmux_option "@claude_bin" "claude")"
AUTO_RUN="$(get_tmux_option "@genie_auto_run" "off")"
PROMPT_KEY="$(get_tmux_option "@genie_key" "C-g")"

[ -z "$INPUT" ] && exit 0

LAST_INPUT="$(get_pane_option @genie_last_input)"
LAST_CMD="$(get_pane_option @genie_last_cmd)"

# Rejection detection: is the last generated command still on the prompt line?
REFINE=0
if [ -n "$LAST_CMD" ]; then
  CURRENT_LINE="$(tmux capture-pane -p -t "$PANE_ID" \
    | sed -e '/^[[:space:]]*$/d' | tail -n 1)"
  case "$CURRENT_LINE" in
    *"$LAST_CMD"*) REFINE=1 ;;
  esac
fi

if [ "$REFINE" = 1 ]; then
  # Clear the rejected command from the prompt line.
  tmux send-keys -t "$PANE_ID" C-u
  # Long finite duration: persists while claude works, replaced by the next
  # message. Do NOT use -d 0 here: it blocks queued commands until keypress.
  tmux display-message -d 30000 "claude: refining..."
  PROMPT="You translate natural-language requests into a single shell command \
(POSIX/bash, for the user's local machine). Output ONLY the raw command. \
No explanation, no markdown, no code fences, no quotes around it, no newlines. \
If the request cannot be done in one command, chain with && or ;.
Earlier request: $LAST_INPUT
You proposed this command: $LAST_CMD
The user rejected it with this feedback / additional requirement: $INPUT
Output ONLY the corrected command."
  COMBINED_INPUT="$LAST_INPUT (then: $INPUT)"
else
  tmux display-message -d 30000 "claude: thinking..."
  PROMPT="You translate natural-language requests into a single shell command \
(POSIX/bash, for the user's local machine). Output ONLY the raw command. \
No explanation, no markdown, no code fences, no quotes around it, no newlines. \
If the request cannot be done in one command, chain with && or ;. \
Request: $INPUT"
  COMBINED_INPUT="$INPUT"
fi

CMD="$("$CLAUDE_BIN" -p "$PROMPT" 2>/dev/null)"

# Sanitize: drop code-fence lines, collapse newlines, trim whitespace.
CMD="$(printf '%s\n' "$CMD" \
  | sed -e '/^```/d' \
  | tr '\n' ' ' \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$CMD" ]; then
  tmux display-message "claude: no command returned (is '$CLAUDE_BIN' on PATH?)"
  exit 0
fi

# Remember this round so the next invocation can detect a rejection.
set_pane_option @genie_last_input "$COMBINED_INPUT"
set_pane_option @genie_last_cmd "$CMD"

if [ "$AUTO_RUN" = "on" ]; then
  tmux send-keys -t "$PANE_ID" -l "$CMD"
  tmux send-keys -t "$PANE_ID" Enter
  tmux display-message -d 2000 "claude: executed"
else
  # Type the command FIRST, then show the message. A message displayed
  # before send-keys can delay the keystrokes (especially with -d 0).
  tmux send-keys -t "$PANE_ID" -l "$CMD"
  tmux display-message -d 5000 "claude: press Enter to run or $PROMPT_KEY to refine."
fi

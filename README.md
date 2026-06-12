# tmux-genie

Make a wish at your terminal. Press a key, describe what you want in plain
English, and the shell command materializes at your prompt — **typed but not
executed**. Press Enter to grant the wish, edit it first, or reject it and
refine.

Powered by the [Claude Code CLI](https://docs.claude.com/en/docs/claude-code),
but works with any CLI that accepts `prompt -p "..."` and prints a response.

## Usage

1. Press `prefix + Ctrl-g`
2. Type a request at the `claude>` prompt:
   `find files over 100MB owned by uid 1000`
3. The generated command appears at your shell prompt
4. Press `Enter` to run it, `Ctrl-C` to discard, or `prefix + Ctrl-g` to rub the lamp again to refine

### Refining a rejected command

Not quite right? Just invoke the prompt again while the command is still
sitting unexecuted at your prompt. That counts as a rejection: the line is
cleared, and your new request is sent along with the original request and
the rejected command as context.

```
prefix C-g  ->  "list big files"            ->  du -ah . | sort -rh | head -20
prefix C-g  ->  "only ones owned by me"     ->  find . -user $(whoami) -size +100M ...
```

Refinements chain — each round keeps the full history for that pane. Every
pane has its own independent refinement state.

## Install

### With TPM

```tmux
set -g @plugin 'jchamblee99/tmux-genie'
```

Then `prefix + I` to install.

### Manually

```sh
git clone https://github.com/jchamblee99/tmux-genie ~/.tmux/plugins/tmux-genie
```

And in `.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-genie/genie.tmux
```

## Options

```tmux
# Key binding (default: C-g)
set -g @genie_key 'C-g'

# Bind without the tmux prefix -- a single keystroke summons the genie
# (default: off). The key is then intercepted globally, so pick one your
# apps don't need; pair with `bind C-g send-keys C-g` as a pass-through.
set -g @genie_no_prefix 'on'

# Path to the claude binary (default: claude, resolved via PATH)
set -g @claude_bin '/usr/local/bin/claude'

# Execute immediately without review (default: off). You are braver than I am.
set -g @genie_auto_run 'off'
```

## Requirements

- tmux 3.0+ (3.2+ for popup mode)
- `claude` (or your configured CLI) on PATH

## Known limitations

- In the default status-line mode, tmux's `command-prompt` substitution
  means a single quote (`'`) in your request can break argument parsing.
  Phrase requests without apostrophes, or enable popup mode, which reads
  input directly and has no such restriction.
- Rejection detection works by checking whether the last generated command
  is still visible on your prompt line. If you heavily edit a suggestion
  and then invoke the genie again, it may be treated as a fresh request.

## Troubleshooting

**Binding does nothing / `returned 127`** — the scripts lost their
executable bit or picked up CRLF line endings in transit:

```sh
cd ~/.tmux/plugins/tmux-genie
chmod +x genie.tmux scripts/*.sh
sed -i 's/\r$//' genie.tmux scripts/*.sh
```

**No command appears** — run the script by hand to see the real error:

```sh
~/.tmux/plugins/tmux-genie/scripts/prompt.sh '%0' 'echo test'
```
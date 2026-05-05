# oh-my-claude-duo

A two-line Claude Code status line, forked from [oh-my-claude](https://github.com/ssenart/oh-my-claude) by Stéphane Senart.

## What's different

The upstream oh-my-claude renders a single-line status bar. This fork adds a second line for Pro usage data, and exposes granular env vars to the oh-my-posh template so each metric can be styled independently.

**Line 1:** Path · Git · Context window bar + percentage + tokens remaining · Model

**Line 2:** 5h usage bar · 7d usage bar · Reset countdowns

Color thresholds:
- Context window: green < 75%, amber 75–89%, red ≥ 90%
- Pro usage: green < 80%, red ≥ 80% (independent per metric)

## Installation

Clone directly into the oh-my-claude-duo scripts directory:

```bash
git clone https://github.com/alexj/oh-my-claude-duo.git ~/.claude/oh-my-claude-duo
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/oh-my-claude-duo/statusline.sh",
    "padding": 0
  }
}
```

The `claude-statusline.omp.json` theme file is managed separately in dotfiles and symlinked into place — see the [dotfiles repo](https://github.com/alexj/dotfiles).

### Dependencies

- [oh-my-posh](https://ohmyposh.dev)
- `jq`
- `ccusage` (via `npx` or installed globally)

## Updating

```bash
cd ~/.claude/oh-my-claude-duo
git pull
```

## Staying current with upstream

This fork tracks [ssenart/oh-my-claude](https://github.com/ssenart/oh-my-claude) as `upstream`. When upstream releases updates:

```bash
git fetch upstream
git rebase upstream/main
git push origin main --force-with-lease
```

The personal changes in this fork all live in `statusline.sh`, so rebasing is usually straightforward.

## License

MIT. See [LICENSE](LICENSE). Original work by Stéphane Senart; fork by Alex Jones.

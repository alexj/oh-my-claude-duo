# oh-my-claude-duo

A two-line Claude Code status line, forked from the excellent [oh-my-claude](https://github.com/ssenart/oh-my-claude) by Stéphane Senart.

## What's different

The upstream oh-my-claude renders a single-line status bar. This fork adds a second line for Pro usage data, and exposes granular env vars to the oh-my-posh template so each metric can be styled independently.

**Line 1:** Path · Git · Context window bar + percentage + tokens remaining · Model

**Line 2:** 5h usage bar · 7d usage bar · Reset countdowns

Color thresholds:
- Context window: green < 75%, amber 75–89%, red ≥ 90%
- Pro usage: green < 80%, red ≥ 80% (independent per metric)

## Status Line Display

### Duo layout (default)

**Line 1**

| Segment | Color | Description | Example |
|---------|-------|-------------|---------|
| **Path** | Orange | Current directory | `oh-my-claude-duo` |
| **Git** | Yellow* | Branch and status | `main` |
| **Context** | Teal | Usage bar + percentage + tokens remaining | `████░░ 24.7% 150k left` |
| **Model** | Blue | Current AI model | `Sonnet 4.6` |

**Line 2**

| Segment | Color | Description | Example |
|---------|-------|-------------|---------|
| **5h Usage** | Green/Red† | 5-hour Pro usage bar + percentage | `▪▪▪▪▪▪▪░░░░░░░░░░░░░ 35%` |
| **7d Usage** | Green/Red† | 7-day Pro usage bar + percentage | `▪▪░░░░░░░░░░░░░░░░░░ 10%` |
| **Reset** | — | Time until 5h and 7d limits reset | `5h:2h1min 7d:Thu09:59` |

*Git segment color changes dynamically based on repository status (clean, dirty, ahead, behind, diverged)

†Pro usage bars are green below 80%, red at 80%+

### Single layout (opt-in)

| Segment | Color | Description | Example |
|---------|-------|-------------|---------|
| **Path** | Orange | Current directory | `oh-my-claude-duo` |
| **Git** | Yellow* | Branch and status | `main` |
| **Context** | Teal | Window usage percentage | `24.7%` |
| **Code** | Cyan | Session tokens | `# 14.3M` |
| **Pro** | Pink | 5h/7d usage percentages | `5h:90% 7d:27%` |
| **Reset** | Purple | Time until limits reset | `5h:2h1min 7d:Thu09:59` |
| **Model** | Blue | Current AI model | `Sonnet 4.6` |

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
    "command": "bash ~/.claude/oh-my-claude-duo/src/statusline.sh",
    "padding": 0
  }
}
```

### Alternative: local install script

If you've cloned the repo locally for development:

```bash
cd oh-my-claude-duo
bash local-install.sh
```

### Dependencies

- [oh-my-posh](https://ohmyposh.dev)
- `jq`
- `ccusage` (via `npx` or installed globally)

## Layout options

The default is the two-line layout. To use the single-line layout instead, add this to `~/.claude/settings.json`:

```json
{
  "env": {
    "OH_MY_CLAUDE_LAYOUT": "single"
  }
}
```

Remove it (or set the value to `"duo"`) to return to the two-line layout.

## Customization

- **Colors**: Edit `~/.claude/oh-my-claude-duo/src/claude-statusline-duo.omp.json` → change `background` values
- **Icons**: Edit the same file → change `template` values
- **Segment order**: Rearrange the `segments` array in the `.omp.json` file
- **Single layout**: Edit `claude-statusline-single.omp.json` instead

Color thresholds (amber/red breakpoints for context, green/red for Pro usage) are defined in `statusline.sh`.

## Common tasks

### Update usage data manually

```bash
bash ~/.claude/oh-my-claude-duo/src/update-usage.sh
```

### View the current usage cache

```bash
cat ~/.claude/oh-my-claude-duo/.usage_cache | jq .
```

### Test the code usage fetcher

```bash
bash ~/.claude/oh-my-claude-duo/src/fetch-code-usage.sh --debug
```

### Test the Pro usage fetcher

```bash
bash ~/.claude/oh-my-claude-duo/src/fetch-pro-usage.sh --debug
```

### Change how often usage updates

Edit `~/.claude/oh-my-claude-duo/src/statusline.sh` and change:

```bash
cache_timeout=60  # seconds (default: 60)
```

### Check the version

```bash
bash ~/.claude/oh-my-claude-duo/src/statusline.sh --version
```

## How it works

1. **Claude Code** calls `statusline.sh` on every prompt refresh
2. **statusline.sh**:
   - Extracts data (model, directory, context window, git status) from the JSON piped in by Claude Code
   - Reads the usage cache (JSON, instant — no blocking)
   - If the cache is older than 60s, triggers `update-usage.sh` in the background
   - Exports env vars for oh-my-posh
   - Selects the duo or single `.omp.json` config based on `OH_MY_CLAUDE_LAYOUT`
   - Hands off to oh-my-posh for rendering
3. **oh-my-posh** renders the colored powerline segments
4. **update-usage.sh** (background, every 60s):
   - Calls `fetch-code-usage.sh` for session token count
   - Calls `fetch-pro-usage.sh` for Pro usage percentages and reset times
   - Writes a JSON cache file with timestamps

## Performance

- **Status line render**: ~50ms
- **Usage update**: ~2–5s (runs in background, never blocks the prompt)
- **Cache TTL**: 60 seconds

### Optimization

For faster usage updates, install ccusage globally instead of running it via npx:

```bash
npm install -g ccusage
```

## Troubleshooting

### Usage not updating?

```bash
# Test ccusage directly
npx ccusage blocks --active --json

# Check the cache
cat ~/.claude/oh-my-claude-duo/.usage_cache | jq .

# Force a manual update
bash ~/.claude/oh-my-claude-duo/src/update-usage.sh
```

### Git status not showing?

The git segment only appears when you're inside a git repository. Navigate to one and it will appear.

### Status line not appearing?

Verify your settings.json contains the right command:

```bash
cat ~/.claude/settings.json
```

It should include:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/oh-my-claude-duo/src/statusline.sh",
    "padding": 0
  }
}
```

### Wrong layout appearing?

Check whether `OH_MY_CLAUDE_LAYOUT` is set in your environment or `~/.claude/settings.json`. Unset it or set it to `"duo"` to get the two-line layout.

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

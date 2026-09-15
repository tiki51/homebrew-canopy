# Homebrew Canopy

Homebrew tap for [Canopy](https://github.com/tiki51/canopy), a local-first workspace where AI coding agents work as a team.

The current beta supports Apple Silicon Macs only.

## Install

```sh
brew install tiki51/canopy/canopy
canopy start
```

Open <http://127.0.0.1:4000>. Press `Ctrl-C` to stop Canopy.

Canopy stores its database, shared files, and generated secret under `~/Library/Application Support/Canopy`. Uninstalling the formula does not remove this user data.

Canopy requires at least one independently installed execution engine: [Claude Code](https://claude.com/claude-code) or [OpenCode](https://opencode.ai).

## Uninstall

```sh
brew uninstall canopy
brew untap tiki51/canopy
```

This tap packages the prebuilt release from the public [Canopy releases](https://github.com/tiki51/canopy/releases) page. Canopy is licensed under the MIT License.

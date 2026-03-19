#!/bin/bash

# Install claude-react-typescript plugin
# Copies agents, skills, and commands to ~/.claude/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing claude-react-typescript..."

# Create directories if needed
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills/react-typescript-patterns"
mkdir -p "$CLAUDE_DIR/commands"

# Copy files
cp "$SCRIPT_DIR/agents/react-typescript-reviewer.md" "$CLAUDE_DIR/agents/"
cp -r "$SCRIPT_DIR/skills/react-typescript-patterns/" "$CLAUDE_DIR/skills/react-typescript-patterns/"
cp "$SCRIPT_DIR/commands/react-review.md" "$CLAUDE_DIR/commands/"

echo ""
echo "Installed:"
echo "  Agent:   ~/.claude/agents/react-typescript-reviewer.md"
echo "  Skill:   ~/.claude/skills/react-typescript-patterns/SKILL.md"
echo "  Command: ~/.claude/commands/react-review.md"
echo ""
echo "Usage:"
echo "  /react-review    — Run a React/TypeScript code review"
echo "  The reviewer agent will also be available for subagent delegation."
echo ""
echo "Done!"

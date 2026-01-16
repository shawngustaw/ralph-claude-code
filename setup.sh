#!/bin/bash

# Ralph Project Setup Script
# Creates a new project with Ralph files in .ralph/ subdirectory
set -e

PROJECT_NAME=${1:-"my-project"}
RALPH_PROJECT_DIR=".ralph"

echo "🚀 Setting up Ralph project: $PROJECT_NAME"

# Create project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create .ralph structure (all Ralph files go here)
mkdir -p "$RALPH_PROJECT_DIR"/{specs/stdlib,logs,docs/generated}

# Copy templates to .ralph/
cp ../templates/PROMPT.md "$RALPH_PROJECT_DIR/"
cp ../templates/fix_plan.md "$RALPH_PROJECT_DIR/@fix_plan.md"
cp ../templates/AGENT.md "$RALPH_PROJECT_DIR/@AGENT.md"
cp -r ../templates/specs/* "$RALPH_PROJECT_DIR/specs/" 2>/dev/null || true

# Initialize git
git init
echo "# $PROJECT_NAME" > README.md
git add .
git commit -m "Initial Ralph project setup"

echo "✅ Project $PROJECT_NAME created!"
echo "Next steps:"
echo "  1. Edit $RALPH_PROJECT_DIR/PROMPT.md with your project requirements"
echo "  2. Update $RALPH_PROJECT_DIR/specs/ with your project specifications"  
echo "  3. Run: ../ralph_loop.sh"
echo "  4. Monitor: ../ralph_monitor.sh"
echo ""
echo "Ralph files are in: $(pwd)/$RALPH_PROJECT_DIR/"
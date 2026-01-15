#!/usr/bin/env bats
# Integration tests for Ralph existing project initialization (ralph_init.sh)
# Tests in-place initialization, git handling, file conflict detection, and --import flag

load '../helpers/test_helper'
load '../helpers/fixtures'

# Store the path to ralph_init.sh from the project root
INIT_SCRIPT=""
RALPH_HOME=""

setup() {
    # Create unique temporary test directory
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    
    # Store ralph_init.sh path
    INIT_SCRIPT="${BATS_TEST_DIRNAME}/../../ralph_init.sh"
    
    # Create mock RALPH_HOME with templates
    RALPH_HOME="$(mktemp -d)"
    export RALPH_HOME
    
    # Set git author info via environment variables
    export GIT_AUTHOR_NAME="Test User"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Test User"
    export GIT_COMMITTER_EMAIL="test@example.com"
    
    # Create mock templates directory
    mkdir -p "$RALPH_HOME/templates/specs"
    
    # Create mock template files
    cat > "$RALPH_HOME/templates/PROMPT.md" << 'EOF'
# Ralph Development Instructions

## Context
You are Ralph, an autonomous AI development agent.

## Current Objectives
1. Follow @fix_plan.md for current priorities
2. Implement using best practices
3. Run tests after each implementation
EOF

    cat > "$RALPH_HOME/templates/fix_plan.md" << 'EOF'
# Ralph Fix Plan

## High Priority
- [ ] Initial setup task

## Medium Priority
- [ ] Secondary task

## Notes
- Focus on MVP functionality first
EOF

    cat > "$RALPH_HOME/templates/AGENT.md" << 'EOF'
# Agent Build Instructions

## Project Setup
```bash
npm install
```

## Running Tests
```bash
npm test
```
EOF

    # Create a sample spec file
    cat > "$RALPH_HOME/templates/specs/sample_spec.md" << 'EOF'
# Sample Specification
This is a sample spec file for testing.
EOF
}

teardown() {
    # Clean up test directories
    if [[ -n "$TEST_DIR" ]] && [[ -d "$TEST_DIR" ]]; then
        cd /
        rm -rf "$TEST_DIR"
    fi
    if [[ -n "$RALPH_HOME" ]] && [[ -d "$RALPH_HOME" ]]; then
        rm -rf "$RALPH_HOME"
    fi
}

# =============================================================================
# Test: Basic Initialization
# =============================================================================

@test "ralph-init creates PROMPT.md in current directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "PROMPT.md"
}

@test "ralph-init creates @fix_plan.md in current directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "@fix_plan.md"
}

@test "ralph-init creates @AGENT.md in current directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "@AGENT.md"
}

@test "ralph-init does not create a subdirectory" {
    local original_dir="$(pwd)"
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    # PROMPT.md should be in current directory, not a subdirectory
    assert_file_exists "PROMPT.md"
    # No project subdirectory should be created
    [[ "$(pwd)" == "$original_dir" ]]
}

# =============================================================================
# Test: Directory Structure Creation
# =============================================================================

@test "ralph-init creates specs directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "specs"
}

@test "ralph-init creates specs/stdlib directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "specs/stdlib"
}

@test "ralph-init creates src directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "src"
}

@test "ralph-init creates examples directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "examples"
}

@test "ralph-init creates logs directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "logs"
}

@test "ralph-init creates docs/generated directory" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists "docs/generated"
}

# =============================================================================
# Test: Git Repository Handling
# =============================================================================

@test "ralph-init skips git init in existing git repository" {
    # Create existing git repo
    git init
    echo "# Existing Project" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Get the original commit count
    local original_commits=$(git rev-list --count HEAD)
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    # Should not have created additional commits
    local current_commits=$(git rev-list --count HEAD)
    [[ "$current_commits" == "$original_commits" ]]
}

@test "ralph-init logs message when git repo exists" {
    git init
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"Existing git repository detected"* ]]
}

@test "ralph-init initializes git when no .git exists" {
    # Ensure no .git directory
    [[ ! -d ".git" ]]
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_dir_exists ".git"
}

@test "ralph-init with --no-git skips git initialization" {
    [[ ! -d ".git" ]]
    
    run bash "$INIT_SCRIPT" --no-git
    
    assert_success
    [[ ! -d ".git" ]]
}

# =============================================================================
# Test: File Conflict Detection
# =============================================================================

@test "ralph-init warns about existing PROMPT.md without --force" {
    echo "# Existing prompt" > PROMPT.md
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"File already exists: PROMPT.md"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "ralph-init preserves existing PROMPT.md without --force" {
    echo "# My custom prompt" > PROMPT.md
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    # Content should be preserved
    run cat PROMPT.md
    [[ "$output" == "# My custom prompt" ]]
}

@test "ralph-init with --force overwrites existing PROMPT.md" {
    echo "# My custom prompt" > PROMPT.md
    
    run bash "$INIT_SCRIPT" --force
    
    assert_success
    # Content should be from template, not original
    run cat PROMPT.md
    [[ "$output" == *"Ralph Development Instructions"* ]]
}

@test "ralph-init with --force overwrites existing @fix_plan.md" {
    echo "# My custom fix plan" > "@fix_plan.md"
    
    run bash "$INIT_SCRIPT" --force
    
    assert_success
    run cat "@fix_plan.md"
    [[ "$output" == *"Ralph Fix Plan"* ]]
}

# =============================================================================
# Test: Dry Run Mode
# =============================================================================

@test "ralph-init --dry-run does not create files" {
    run bash "$INIT_SCRIPT" --dry-run
    
    assert_success
    assert_file_not_exists "PROMPT.md"
    assert_file_not_exists "@fix_plan.md"
    assert_file_not_exists "@AGENT.md"
}

@test "ralph-init --dry-run does not create directories" {
    run bash "$INIT_SCRIPT" --dry-run
    
    assert_success
    [[ ! -d "specs" ]]
    [[ ! -d "logs" ]]
}

@test "ralph-init --dry-run does not initialize git" {
    run bash "$INIT_SCRIPT" --dry-run
    
    assert_success
    [[ ! -d ".git" ]]
}

@test "ralph-init --dry-run shows what would be created" {
    run bash "$INIT_SCRIPT" --dry-run
    
    assert_success
    [[ "$output" == *"Would create"* ]] || [[ "$output" == *"DRY-RUN"* ]]
}

@test "ralph-init --dry-run message indicates no changes made" {
    run bash "$INIT_SCRIPT" --dry-run
    
    assert_success
    [[ "$output" == *"no changes"* ]] || [[ "$output" == *"Dry run"* ]]
}

# =============================================================================
# Test: Non-Destructive Directory Creation
# =============================================================================

@test "ralph-init does not overwrite existing specs directory" {
    mkdir -p specs
    echo "# Existing spec" > specs/existing.md
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "specs/existing.md"
    run cat specs/existing.md
    [[ "$output" == "# Existing spec" ]]
}

@test "ralph-init does not overwrite existing src directory contents" {
    mkdir -p src
    echo "console.log('hello');" > src/index.js
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "src/index.js"
}

@test "ralph-init does not overwrite existing logs directory contents" {
    mkdir -p logs
    echo "Previous log entry" > logs/previous.log
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "logs/previous.log"
}

# =============================================================================
# Test: Help and Usage
# =============================================================================

@test "ralph-init --help shows usage information" {
    run bash "$INIT_SCRIPT" --help
    
    assert_success
    [[ "$output" == *"Usage:"* ]]
}

@test "ralph-init --help shows --force option" {
    run bash "$INIT_SCRIPT" --help
    
    assert_success
    [[ "$output" == *"--force"* ]]
}

@test "ralph-init --help shows --dry-run option" {
    run bash "$INIT_SCRIPT" --help
    
    assert_success
    [[ "$output" == *"--dry-run"* ]]
}

@test "ralph-init --help shows --import option" {
    run bash "$INIT_SCRIPT" --help
    
    assert_success
    [[ "$output" == *"--import"* ]]
}

@test "ralph-init --help shows --no-git option" {
    run bash "$INIT_SCRIPT" --help
    
    assert_success
    [[ "$output" == *"--no-git"* ]]
}

@test "ralph-init -h is equivalent to --help" {
    run bash "$INIT_SCRIPT" -h
    
    assert_success
    [[ "$output" == *"Usage:"* ]]
}

# =============================================================================
# Test: Error Handling
# =============================================================================

@test "ralph-init fails gracefully when RALPH_HOME templates missing" {
    rm -rf "$RALPH_HOME/templates"
    
    run bash "$INIT_SCRIPT"
    
    assert_failure
    [[ "$output" == *"templates not found"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "ralph-init reports error for unknown option" {
    run bash "$INIT_SCRIPT" --invalid-option
    
    assert_failure
    [[ "$output" == *"Unknown option"* ]]
}

@test "ralph-init --import fails when file not found" {
    run bash "$INIT_SCRIPT" --import nonexistent.md
    
    assert_failure
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "ralph-init --import requires file argument" {
    run bash "$INIT_SCRIPT" --import
    
    assert_failure
}

# =============================================================================
# Test: Import Flag (without actual Claude invocation)
# =============================================================================

@test "ralph-init --import creates Ralph structure before import" {
    # Create a mock PRD file
    echo "# My Requirements" > requirements.md
    
    # Note: This test just verifies the structure is created
    # Actual Claude conversion would need to be mocked
    run bash "$INIT_SCRIPT" --import requirements.md 2>&1 || true
    
    # Even if import fails (no Claude), directories should be created
    assert_dir_exists "specs"
    assert_dir_exists "logs"
}

@test "ralph-init -i is shorthand for --import" {
    run bash "$INIT_SCRIPT" -i 2>&1
    
    # Should fail with "requires file argument" not "unknown option"
    [[ "$output" == *"requires"* ]] || [[ "$output" == *"file"* ]]
}

# =============================================================================
# Test: Output Messages
# =============================================================================

@test "ralph-init shows initialization message" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"Initializing Ralph"* ]]
}

@test "ralph-init shows success message on completion" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"initialized"* ]] || [[ "$output" == *"SUCCESS"* ]]
}

@test "ralph-init shows next steps after completion" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"Next steps"* ]]
}

@test "ralph-init shows ralph --monitor in next steps" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    [[ "$output" == *"ralph --monitor"* ]]
}

# =============================================================================
# Test: Template Content Verification
# =============================================================================

@test "ralph-init copies PROMPT.md with correct content" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    run cat PROMPT.md
    [[ "$output" == *"Ralph Development Instructions"* ]]
}

@test "ralph-init copies @fix_plan.md with correct content" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    run cat "@fix_plan.md"
    [[ "$output" == *"Ralph Fix Plan"* ]]
}

@test "ralph-init copies @AGENT.md with correct content" {
    run bash "$INIT_SCRIPT"
    
    assert_success
    run cat "@AGENT.md"
    [[ "$output" == *"Agent Build Instructions"* ]]
}

# =============================================================================
# Test: Flag Combinations
# =============================================================================

@test "ralph-init --force --dry-run shows force actions without applying" {
    echo "# Existing" > PROMPT.md
    
    run bash "$INIT_SCRIPT" --force --dry-run
    
    assert_success
    # File should still have original content
    run cat PROMPT.md
    [[ "$output" == "# Existing" ]]
}

@test "ralph-init --no-git --force works together" {
    echo "# Existing" > PROMPT.md
    
    run bash "$INIT_SCRIPT" --no-git --force
    
    assert_success
    [[ ! -d ".git" ]]
    run cat PROMPT.md
    [[ "$output" == *"Ralph Development Instructions"* ]]
}

@test "ralph-init -f is shorthand for --force" {
    echo "# Existing" > PROMPT.md
    
    run bash "$INIT_SCRIPT" -f
    
    assert_success
    run cat PROMPT.md
    [[ "$output" == *"Ralph Development Instructions"* ]]
}

# =============================================================================
# Test: Working Directory Behavior
# =============================================================================

@test "ralph-init works in nested directory structure" {
    mkdir -p deep/nested/project
    cd deep/nested/project
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "PROMPT.md"
}

@test "ralph-init works with spaces in directory name" {
    mkdir -p "project with spaces"
    cd "project with spaces"
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "PROMPT.md"
}

@test "ralph-init works in directory with existing files" {
    # Create various existing files
    echo "package.json" > package.json
    echo "index.js" > index.js
    mkdir -p node_modules
    
    run bash "$INIT_SCRIPT"
    
    assert_success
    assert_file_exists "PROMPT.md"
    assert_file_exists "package.json"
    assert_file_exists "index.js"
}

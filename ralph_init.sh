#!/bin/bash

# Ralph Init - Initialize Ralph in an existing project directory
# Version: 1.0.0 - In-place initialization for existing projects
set -e

# Configuration
RALPH_HOME="${RALPH_HOME:-$HOME/.ralph}"

# CLI flags
FORCE=false
DRY_RUN=false
NO_GIT=false
IMPORT_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local color=""

    case $level in
        "INFO")  color=$BLUE ;;
        "WARN")  color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "DRY_RUN") color=$YELLOW ;;
    esac

    if [[ "$DRY_RUN" == "true" && "$level" != "DRY_RUN" && "$level" != "ERROR" ]]; then
        echo -e "${YELLOW}[DRY-RUN] ${color}[$level] $message${NC}"
    else
        echo -e "${color}[$(date '+%H:%M:%S')] [$level] $message${NC}"
    fi
}

show_help() {
    cat << HELPEOF
Ralph Init - Initialize Ralph in an Existing Project

Usage: ralph-init [OPTIONS]

Initialize Ralph files in the current directory without creating a subdirectory.
Designed for adding Ralph to existing projects.

Options:
    -h, --help              Show this help message
    -f, --force             Overwrite existing Ralph files
    -i, --import <file>     Import and convert a PRD/spec file in-place
    --no-git                Skip git initialization even if no .git exists
    --dry-run               Show what would be created without making changes

Examples:
    # Initialize Ralph in current directory
    cd my-existing-project
    ralph-init

    # Initialize with force overwrite
    ralph-init --force

    # Initialize and import a PRD
    ralph-init --import requirements.md

    # Preview what would be created
    ralph-init --dry-run

Differences from ralph-setup:
    - ralph-setup: Creates a NEW subdirectory with Ralph structure
    - ralph-init:  Initializes Ralph IN the current directory (existing project)

Created Files:
    PROMPT.md           Ralph development instructions
    @fix_plan.md        Prioritized task list
    @AGENT.md           Build and run instructions

Created Directories:
    specs/stdlib/       Project specifications
    src/                Source code (if not exists)
    examples/           Usage examples
    logs/               Ralph execution logs
    docs/generated/     Auto-generated documentation

HELPEOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -i|--import)
                if [[ -z "$2" || "$2" == -* ]]; then
                    log "ERROR" "--import requires a file argument"
                    exit 1
                fi
                IMPORT_FILE="$2"
                shift 2
                ;;
            --no-git)
                NO_GIT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Check if Ralph is installed (templates available)
check_ralph_installed() {
    if [[ ! -d "$RALPH_HOME/templates" ]]; then
        log "ERROR" "Ralph templates not found at $RALPH_HOME/templates"
        log "ERROR" "Please run the Ralph installer first: ./install.sh"
        exit 1
    fi
}

# Create a directory if it doesn't exist
create_directory() {
    local dir=$1
    
    if [[ -d "$dir" ]]; then
        log "INFO" "Directory already exists: $dir"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY_RUN" "Would create directory: $dir"
        else
            mkdir -p "$dir"
            log "SUCCESS" "Created directory: $dir"
        fi
    fi
}

# Copy a template file with conflict detection
copy_template() {
    local template_name=$1
    local dest_name=$2
    
    local source_path="$RALPH_HOME/templates/$template_name"
    
    # Check if source template exists
    if [[ ! -f "$source_path" ]]; then
        log "WARN" "Template not found: $source_path"
        return 1
    fi
    
    # Check for existing file
    if [[ -f "$dest_name" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log "DRY_RUN" "Would overwrite (--force): $dest_name"
            else
                cp "$source_path" "$dest_name"
                log "SUCCESS" "Overwrote file (--force): $dest_name"
            fi
        else
            log "WARN" "File already exists: $dest_name (use --force to overwrite)"
            return 0
        fi
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY_RUN" "Would create file: $dest_name"
        else
            cp "$source_path" "$dest_name"
            log "SUCCESS" "Created file: $dest_name"
        fi
    fi
}

# Initialize git repository if needed
init_git() {
    if [[ "$NO_GIT" == "true" ]]; then
        log "INFO" "Skipping git initialization (--no-git flag)"
        return 0
    fi
    
    if [[ -d ".git" ]]; then
        log "INFO" "Existing git repository detected, skipping git init"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY_RUN" "Would initialize git repository"
        else
            git init
            log "SUCCESS" "Initialized git repository"
        fi
    fi
}

# Create Ralph directory structure
create_directories() {
    log "INFO" "Creating Ralph directory structure..."
    
    # Core directories
    create_directory "specs/stdlib"
    create_directory "src"
    create_directory "examples"
    create_directory "logs"
    create_directory "docs/generated"
}

# Copy Ralph template files
copy_templates() {
    log "INFO" "Copying Ralph template files..."
    
    # Core Ralph files
    copy_template "PROMPT.md" "PROMPT.md"
    copy_template "fix_plan.md" "@fix_plan.md"
    copy_template "AGENT.md" "@AGENT.md"
    
    # Copy specs templates if they exist and specs dir is empty
    if [[ -d "$RALPH_HOME/templates/specs" ]]; then
        local specs_empty=true
        if [[ -d "specs" ]] && [[ -n "$(ls -A specs 2>/dev/null)" ]]; then
            specs_empty=false
        fi
        
        if [[ "$specs_empty" == "true" || "$FORCE" == "true" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log "DRY_RUN" "Would copy specs templates to specs/"
            else
                cp -r "$RALPH_HOME/templates/specs/"* specs/ 2>/dev/null || true
                log "INFO" "Copied specs templates"
            fi
        else
            log "INFO" "specs/ directory not empty, skipping template copy"
        fi
    fi
}

# Run PRD import if specified
run_import() {
    if [[ -z "$IMPORT_FILE" ]]; then
        return 0
    fi
    
    if [[ ! -f "$IMPORT_FILE" ]]; then
        log "ERROR" "Import file not found: $IMPORT_FILE"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY_RUN" "Would import and convert PRD: $IMPORT_FILE"
        return 0
    fi
    
    log "INFO" "Importing PRD: $IMPORT_FILE"
    
    # Check if ralph-import supports --in-place flag
    if ralph-import --help 2>&1 | grep -q "\-\-in-place"; then
        ralph-import --in-place "$IMPORT_FILE"
    else
        # Fallback: run the import conversion directly in current directory
        log "INFO" "Running PRD conversion in current directory..."
        run_inline_conversion "$IMPORT_FILE"
    fi
}

# Inline PRD conversion (when ralph-import doesn't support --in-place yet)
run_inline_conversion() {
    local source_file=$1
    local CLAUDE_CODE_CMD="claude"
    
    # Check if Claude Code CLI is available
    if ! command -v "$CLAUDE_CODE_CMD" &> /dev/null; then
        if command -v npx &> /dev/null; then
            CLAUDE_CODE_CMD="npx @anthropic/claude-code"
        else
            log "ERROR" "Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
            exit 1
        fi
    fi
    
    local conversion_prompt_file=".ralph_init_conversion_prompt.md"
    local conversion_output_file=".ralph_init_conversion_output.json"
    
    # Create conversion prompt
    cat > "$conversion_prompt_file" << 'PROMPTEOF'
# PRD to Ralph Conversion Task

You are tasked with converting a Product Requirements Document (PRD) or specification into Ralph for Claude Code format.

## Input Analysis
Analyze the provided specification file and extract:
- Project goals and objectives
- Core features and requirements
- Technical constraints and preferences
- Priority levels and phases
- Success criteria

## Required Outputs

Update or create these files in the current directory:

### 1. PROMPT.md
Transform the PRD into Ralph development instructions with project-specific context.

### 2. @fix_plan.md
Convert requirements into a prioritized task list with clear, implementable tasks.

### 3. specs/requirements.md
Create detailed technical specifications preserving all technical details from the original PRD.

## Instructions
1. Read and analyze the attached specification file
2. Update the three files above with content derived from the PRD
3. Ensure all requirements are captured and properly prioritized
4. Make the PROMPT.md actionable for autonomous development
5. Structure @fix_plan.md with clear, implementable tasks

PROMPTEOF

    # Append source PRD content
    echo "" >> "$conversion_prompt_file"
    echo "---" >> "$conversion_prompt_file"
    echo "" >> "$conversion_prompt_file"
    echo "## Source PRD File: $(basename "$source_file")" >> "$conversion_prompt_file"
    echo "" >> "$conversion_prompt_file"
    cat "$source_file" >> "$conversion_prompt_file"
    
    log "INFO" "Running Claude Code to convert PRD..."
    
    # Run conversion
    if $CLAUDE_CODE_CMD < "$conversion_prompt_file" > "$conversion_output_file" 2>&1; then
        log "SUCCESS" "PRD conversion completed"
    else
        log "WARN" "PRD conversion may have encountered issues, please review the generated files"
    fi
    
    # Clean up temp files
    rm -f "$conversion_prompt_file" "$conversion_output_file"
}

# Show summary of actions
show_summary() {
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Dry run complete - no changes were made"
        echo ""
        echo "To apply these changes, run without --dry-run:"
        echo "  ralph-init"
    else
        log "SUCCESS" "🎉 Ralph initialized in current directory!"
        echo ""
        echo "Next steps:"
        echo "  1. Edit PROMPT.md with your project requirements"
        echo "  2. Update @fix_plan.md with your task priorities"
        echo "  3. Add specifications to specs/"
        echo "  4. Run: ralph --monitor"
        echo ""
        echo "Project initialized in: $(pwd)"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo "🚀 Initializing Ralph in existing project..."
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Running in dry-run mode - no changes will be made"
        echo ""
    fi
    
    check_ralph_installed
    init_git
    create_directories
    copy_templates
    run_import
    show_summary
}

# Run main
main "$@"

#!/bin/bash
set -euo pipefail

# Configuration
PROJECTS_DIR="${PROJECTS_DIR:-/opt/docker-projects}"
ORDER_FILE="$PROJECTS_DIR/.startup-order"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_USAGE=1
readonly EXIT_MISSING_DEPENDENCY=2
readonly EXIT_INVALID_CONFIG=3

# Logging functions
log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Validate dependencies
validate_dependencies() {
    if ! command -v docker &>/dev/null; then
        log_error "docker command not found"
        exit "$EXIT_MISSING_DEPENDENCY"
    fi

    if ! docker compose version &>/dev/null; then
        log_error "docker compose not available"
        exit "$EXIT_MISSING_DEPENDENCY"
    fi
}

# Validate projects directory
validate_projects_dir() {
    if [[ ! -d "$PROJECTS_DIR" ]]; then
        log_error "Projects directory does not exist: $PROJECTS_DIR"
        exit "$EXIT_INVALID_CONFIG"
    fi

    if [[ ! -r "$PROJECTS_DIR" ]]; then
        log_error "Projects directory is not readable: $PROJECTS_DIR"
        exit "$EXIT_INVALID_CONFIG"
    fi
}

# Read projects from order file into array
declare -a ORDERED_PROJECTS=()
load_startup_order() {
    if [[ ! -f "$ORDER_FILE" ]]; then
        return 0
    fi

    if [[ ! -r "$ORDER_FILE" ]]; then
        log_warn "Startup order file is not readable: $ORDER_FILE"
        return 0
    fi

    while IFS= read -r project_name || [[ -n "$project_name" ]]; do
        # Skip empty lines and comments
        [[ -z "$project_name" || "$project_name" =~ ^[[:space:]]*# ]] && continue
        # Remove leading/trailing whitespace and add to array
        project_name="${project_name// /}"
        project_name="${project_name#"${project_name%%[![:space:]]*}"}"
        project_name="${project_name%"${project_name##*[![:space:]]}"}"
        ORDERED_PROJECTS+=("$project_name")
    done < "$ORDER_FILE"
}

should_exclude() {
    local dir_name="$1"

    # If no order file exists, include all projects
    if [[ ${#ORDERED_PROJECTS[@]} -eq 0 ]]; then
        return 1
    fi

    # If order file exists, only include projects listed in it
    local project
    for project in "${ORDERED_PROJECTS[@]}"; do
        if [[ "$dir_name" == "$project" ]]; then
            return 1
        fi
    done
    return 0
}

has_compose_file() {
    local project_path="$1"
    [[ -f "$project_path/docker-compose.yml" ]] || \
    [[ -f "$project_path/docker-compose.yaml" ]] || \
    [[ -f "$project_path/compose.yml" ]] || \
    [[ -f "$project_path/compose.yaml" ]]
}

start_project() {
    local project_path="$1"
    local project_name
    project_name="$(basename "$project_path")"

    if should_exclude "$project_name"; then
        log_info "Skipping excluded project: $project_name"
        return 1
    fi

    if ! has_compose_file "$project_path"; then
        log_info "Skipping $project_name (no compose file found)"
        return 1
    fi

    log_info "Starting project: $project_name"

    if (cd "$project_path" && docker compose up -d); then
        log_info "Successfully started: $project_name"

        # Check if there's a wait time specified
        if [[ -f "$project_path/.startup-wait" ]]; then
            local wait_time
            wait_time="$(cat "$project_path/.startup-wait")"

            # Validate wait_time is a positive integer
            if [[ "$wait_time" =~ ^[0-9]+$ ]]; then
                log_info "Waiting ${wait_time}s for $project_name to stabilize..."
                sleep "$wait_time"
            else
                log_warn "Invalid wait time in $project_path/.startup-wait: $wait_time (must be a positive integer)"
            fi
        fi

        return 0
    else
        log_error "Failed to start: $project_name"
        return 1
    fi
}

stop_project() {
    local project_path="$1"
    local project_name
    project_name="$(basename "$project_path")"

    if should_exclude "$project_name"; then
        return 1
    fi

    if ! has_compose_file "$project_path"; then
        return 1
    fi

    log_info "Stopping project: $project_name"

    if (cd "$project_path" && docker compose down); then
        log_info "Successfully stopped: $project_name"
        return 0
    else
        log_error "Failed to stop: $project_name"
        return 1
    fi
}

# Main execution
main() {
    local action="${1:-}"

    if [[ -z "$action" ]]; then
        log_error "Usage: $0 {start|stop}"
        exit "$EXIT_INVALID_USAGE"
    fi

    validate_dependencies
    validate_projects_dir
    load_startup_order

    case "$action" in
        start)
            log_info "Scanning for Docker Compose projects in: $PROJECTS_DIR"
            if [[ ${#ORDERED_PROJECTS[@]} -gt 0 ]]; then
                log_info "Using startup order from: $ORDER_FILE (${#ORDERED_PROJECTS[@]} projects)"
            else
                log_info "No startup order file found. Starting all projects alphabetically."
            fi
            echo ""

            if [[ -f "$ORDER_FILE" ]]; then
                local project_name project_path
                for project_name in "${ORDERED_PROJECTS[@]}"; do
                    project_path="$PROJECTS_DIR/$project_name"

                    if [[ -d "$project_path" ]]; then
                        start_project "$project_path" || true
                    else
                        log_warn "Project directory not found: $project_name"
                    fi

                    echo ""
                done
            else
                local project_path
                for project_path in "$PROJECTS_DIR"/*; do
                    if [[ -d "$project_path" ]]; then
                        start_project "$project_path" || true
                        echo ""
                    fi
                done
            fi
            ;;

        stop)
            log_info "Stopping Docker Compose projects in: $PROJECTS_DIR"
            if [[ ${#ORDERED_PROJECTS[@]} -gt 0 ]]; then
                log_info "Using reverse startup order from: $ORDER_FILE (${#ORDERED_PROJECTS[@]} projects)"
            else
                log_info "Stopping all projects"
            fi
            echo ""

            if [[ -f "$ORDER_FILE" ]]; then
                local i project_name project_path
                for ((i=${#ORDERED_PROJECTS[@]}-1; i>=0; i--)); do
                    project_name="${ORDERED_PROJECTS[i]}"
                    project_path="$PROJECTS_DIR/$project_name"

                    if [[ -d "$project_path" ]]; then
                        stop_project "$project_path" || true
                        echo ""
                    fi
                done
            else
                local project_path
                for project_path in "$PROJECTS_DIR"/*; do
                    if [[ -d "$project_path" ]]; then
                        stop_project "$project_path" || true
                        echo ""
                    fi
                done
            fi
            ;;

        *)
            log_error "Invalid action: $action"
            log_error "Usage: $0 {start|stop}"
            exit "$EXIT_INVALID_USAGE"
            ;;
    esac

    exit "$EXIT_SUCCESS"
}

main "$@"

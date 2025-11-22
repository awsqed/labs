#!/bin/bash

# Configuration
PROJECTS_DIR="${PROJECTS_DIR:-/opt/docker-projects}"

# Startup order file (optional)
ORDER_FILE="$PROJECTS_DIR/.startup-order"

# Read projects from order file into array
declare -a ORDERED_PROJECTS=()
if [[ -f "$ORDER_FILE" ]]; then
    while IFS= read -r project_name || [[ -n "$project_name" ]]; do
        # Skip empty lines and comments
        [[ -z "$project_name" || "$project_name" =~ ^[[:space:]]*# ]] && continue
        # Remove leading/trailing whitespace and add to array
        project_name=$(echo "$project_name" | xargs)
        ORDERED_PROJECTS+=("$project_name")
    done < "$ORDER_FILE"
fi

should_exclude() {
    local dir_name="$1"

    # If no order file exists, include all projects
    [[ ${#ORDERED_PROJECTS[@]} -eq 0 ]] && return 1

    # If order file exists, only include projects listed in it
    for project in "${ORDERED_PROJECTS[@]}"; do
        if [[ "$dir_name" == "$project" ]]; then
            return 1  # Don't exclude (it's in the list)
        fi
    done
    return 0  # Exclude (not in the list)
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
    local project_name=$(basename "$project_path")

    if should_exclude "$project_name"; then
        echo "⊘ Skipping excluded project: $project_name"
        return 1
    fi

    if ! has_compose_file "$project_path"; then
        echo "⊘ Skipping $project_name (no compose file found)"
        return 1
    fi

    echo "▶ Starting project: $project_name"
    cd "$project_path" && docker compose up -d

    if [[ $? -eq 0 ]]; then
        echo "✓ Successfully started: $project_name"

        # Check if there's a wait time specified
        if [[ -f "$project_path/.startup-wait" ]]; then
            wait_time=$(cat "$project_path/.startup-wait")
            echo "  ⏱ Waiting ${wait_time}s for $project_name to stabilize..."
            sleep "$wait_time"
        fi

        return 0
    else
        echo "✗ Failed to start: $project_name"
        return 1
    fi
}

stop_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")

    if should_exclude "$project_name"; then
        return 1
    fi

    if ! has_compose_file "$project_path"; then
        return 1
    fi

    echo "■ Stopping project: $project_name"
    cd "$project_path" && docker compose down

    if [[ $? -eq 0 ]]; then
        echo "✓ Successfully stopped: $project_name"
        return 0
    else
        echo "✗ Failed to stop: $project_name"
        return 1
    fi
}

case "$1" in
    start)
        echo "Scanning for Docker Compose projects in: $PROJECTS_DIR"
        if [[ ${#ORDERED_PROJECTS[@]} -gt 0 ]]; then
            echo "Using startup order from: $ORDER_FILE (${#ORDERED_PROJECTS[@]} projects)"
        else
            echo "No startup order file found. Starting all projects alphabetically."
        fi
        echo ""

        # Check if order file exists
        if [[ -f "$ORDER_FILE" ]]; then
            for project_name in "${ORDERED_PROJECTS[@]}"; do
                project_path="$PROJECTS_DIR/$project_name"

                if [[ -d "$project_path" ]]; then
                    start_project "$project_path"
                else
                    echo "⚠ Warning: Project '$project_name' not found"
                fi

                echo ""
            done
        else
            # Start all projects alphabetically
            for project_path in "$PROJECTS_DIR"/*; do
                if [[ -d "$project_path" ]]; then
                    start_project "$project_path"
                    echo ""
                fi
            done
        fi
        ;;

    stop)
        echo "Stopping Docker Compose projects in: $PROJECTS_DIR"
        if [[ ${#ORDERED_PROJECTS[@]} -gt 0 ]]; then
            echo "Using reverse startup order from: $ORDER_FILE (${#ORDERED_PROJECTS[@]} projects)"
        else
            echo "Stopping all projects"
        fi
        echo ""

        # Stop in reverse order if order file exists
        if [[ -f "$ORDER_FILE" ]]; then
            # Iterate through array in reverse
            for ((i=${#ORDERED_PROJECTS[@]}-1; i>=0; i--)); do
                project_name="${ORDERED_PROJECTS[i]}"
                project_path="$PROJECTS_DIR/$project_name"

                if [[ -d "$project_path" ]]; then
                    stop_project "$project_path"
                    echo ""
                fi
            done
        else
            # Stop all projects
            for project_path in "$PROJECTS_DIR"/*; do
                if [[ -d "$project_path" ]]; then
                    stop_project "$project_path"
                    echo ""
                fi
            done
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

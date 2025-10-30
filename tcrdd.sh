#!/usr/bin/env bash
# TCRDD - Test Commit Revert Driven Development
# Copyright (c) 2025 Youssef MEDAGHRI ALAOUI
# Licensed under the MIT License. See LICENSE file in the project root for details.

alias gbc='git-bet collapse'
alias gbp='git-bet pass'
alias gbf='git-bet fail'
alias gbt='git-bet timer'

GITBET_COLLAPSE_DEFAULT_LOG_COUNT=50

function execute(){

    case "$3" in
      -h | --help)
        $2
        ;;
      *)
        $1 "${@:3}"
        ;;
    esac
}

function git-bet() {
    # === HELP ===
    function func_help() {        
        echo "Help :"
        echo "------"
        echo "git-bet pass <command...> : Bet that the command passes"
        echo "git-bet fail <command...> : Bet that the command fails"
        echo "git-bet timer <minutes> <command...> : Run the command automatically every N minutes in background"
        echo "git-bet timer 0 : Stop the background timer"
        echo "git-bet collapse <n?>: Displays the last n (or 50) lines of git log and asks the user how many recent commits to squash and automatically performs an interactive rebase."
        echo
    }

    # === EXECUTE TEST COMMAND ===
    function run_test() {
        local mode="$1"
        shift

        local test_command=("$@")

        echo "🎲 Running: ${test_command[*]}"

        if "${test_command[@]}"; then
            if [ "$mode" = "pass" ]; then
                echo "✅ Tests passed — committing..."
                git add -A
                git commit -m "TCR auto-commit"
            else
                echo "⚠️ Expected failure, but tests passed — reverting code..."
                git reset --hard
                git clean -fd
            fi
        else
            if [ "$mode" = "pass" ]; then
                echo "💥 Tests failed unexpectedly — reverting code..."
                git reset --hard
                git clean -fd
            else
                echo "✅ Tests failed as expected — no action taken."
            fi
        fi

        # Update last run timestamp
        date +%s >"$LAST_RUN_FILE"
    }

    # === MAIN FUNCTION ===
    function func_runnable() {

        if ! command -v git >/dev/null 2>&1; then
            echo "❌ Error: 'git' command not found."
            return 1
        fi 

        if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "❌ Error: Not inside a Git repository."
            return 1
        fi

        # === CONFIGURATION ===
        STATE_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.git/git-bet-state"
        LAST_RUN_FILE="$STATE_DIR/last_run.txt"
        TIMER_PID_FILE="$STATE_DIR/timer.pid"
        TIMER_TAIL_FILE="$STATE_DIR/tail.pid"
        TIMER_LOG="$STATE_DIR/timer.log"

        mkdir -p "$STATE_DIR"

        if [ $# -lt 1 ]; then
            echo "❌ Error: missing parameter."
            func_help
            return 1
        fi

        local mode="$1"
        shift

        # === GIT COLLAPSE ===
        if [ "$mode" = "collapse" ]; then

            local show_count=${1:-$GITBET_COLLAPSE_DEFAULT_LOG_COUNT}

            git --no-pager log --oneline -n "$show_count"
            echo
            # Ask how many commits to collapse
            echo "How many recent commits do you want to collapse? "
            read count
            if ! [[ "$count" =~ ^[0-9]+$ ]]; then
                echo "❌ Invalid number: $count"
                return 1
            fi

            # Ask for the new combined commit message
            echo "New commit message: "
            read new_message
            if [ -z "$new_message" ]; then
                echo "❌ Commit message cannot be empty."
                return 1
            fi

            # Confirm action
            echo "⚙️ Collapsing last $count commits into one..."

            # Do a soft reset and re-commit
            git reset --soft HEAD~"$count" || {
                echo "❌ Reset failed. Check your branch state."
                return 1
            }

            git commit -m "$new_message" && echo "✅ Successfully collapsed $count commits."
            return 0

        fi

        # === TIMER HANDLER ===
        if [ "$mode" = "timer" ]; then
            local minutes="$1"
            shift
            if [ -z "$minutes" ]; then
                echo "❌ Missing time parameter. Example: git-bet timer 3 ./gradlew test"
                return 1
            fi

            # Stop timer if minutes=0
            if [ "$minutes" -eq 0 ]; then
                if [ -f "$TIMER_PID_FILE" ]; then
                    kill "$(cat "$TIMER_PID_FILE")" 2>/dev/null
                    rm -f "$TIMER_PID_FILE"

                    if [ -f "$TIMER_TAIL_FILE" ]; then
                        kill "$(cat "$TIMER_TAIL_FILE")" 2>/dev/null
                        rm -f "$TIMER_TAIL_FILE"
                    fi

                    echo "🕓 Timer and log tail removed."
                else
                    echo "ℹ️ No timer was running."
                fi                
                        
                return 0
            fi

            local test_command=("$@")
            if [ ${#test_command[@]} -eq 0 ]; then
                echo "❌ Missing command. Example: git-bet timer 3 ./gradlew test"
                return 1
            fi

            echo "⏱️ Timer configured for $minutes minute(s) in background."
            echo "Logs will be written to $TIMER_LOG"

            # Clear previous log
            : >"$TIMER_LOG"

            # ===== Background timer =====
            (
                while true; do
                    now=$(date +%s)
                    if [ -f "$LAST_RUN_FILE" ]; then
                        last_run=$(cat "$LAST_RUN_FILE")
                    else
                        last_run=$now  # Wait full interval on first run
                    fi

                    elapsed=$((now - last_run))
                    interval_seconds=$((minutes * 60))

                    if [ "$elapsed" -ge "$interval_seconds" ]; then
                        if git diff --quiet && git diff --cached --quiet; then
                            echo "⏰ No changes detected; skipping auto-run at $(date)" >> "$TIMER_LOG"
                        else
                            echo "⏰ Auto-running tests at $(date)..." >> "$TIMER_LOG"
                            run_test pass "${test_command[@]}" >>"$TIMER_LOG" 2>&1 < /dev/null
                        fi                        
                    fi

                    sleep "$interval_seconds"
                done
            ) &
            echo $! >"$TIMER_PID_FILE"
            echo "Background timer PID: $(cat "$TIMER_PID_FILE")"

            # ===== Tail log in background =====
            tail -f "$TIMER_LOG" &
            TAIL_PID=$!
            echo $TAIL_PID > "$STATE_DIR/$TIMER_TAIL_FILE"
            return 0
        fi

        # === PASS/FAIL HANDLER ===
        if [ "$mode" != "pass" ] && [ "$mode" != "fail" ]; then
            echo "❌ Error: First parameter must be 'pass', 'fail', or 'timer' or 'collapse' !"
            func_help
            return 1
        fi

        local test_command=("$@")
        if [ ${#test_command[@]} -eq 0 ]; then
            echo "❌ Execution command is missing (example: ./gradlew test)"
            func_help
            return 1
        fi

        run_test "$mode" "${test_command[@]}"
    }

    execute func_runnable func_help "$@"
}
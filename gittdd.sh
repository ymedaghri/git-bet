#!/usr/bin/env bash
# GitTdd - Test Commit Revert Driven Development
# Copyright (c) 2025 Youssef MEDAGHRI ALAOUI
# Licensed under the MIT License. See LICENSE file in the project root for details.

alias collapse='git-tdd collapse'
alias state='git-tdd state'
alias configure='git-tdd configure'
alias red='git-tdd red'
alias green='git-tdd green'
alias refactor='git-tdd refactor'

GITTDD_COLLAPSE_DEFAULT_LOG_COUNT=50

function git-tdd() {
    local REPO_ROOT
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ Not inside a git repository." >&2
        return 1
    }

    local STATE_FILE="$REPO_ROOT/.git/tdd-state"
    local CONFIG_FILE="$REPO_ROOT/.git/tdd-config"
    local PHASE="NOT STARTED"

    # --- helpers ---------------------------------------------------------------
    get_phase() {
        if [ -f "$STATE_FILE" ]; then
            grep '^phase=' "$STATE_FILE" 2>/dev/null | cut -d= -f2
        else
            echo "NOT STARTED"
        fi
    }

    set_phase() {
        echo "phase=$1" >"$STATE_FILE"        
    }

    revert_changes() {
        echo "🔄 Reverting changes..."
        git reset --hard >/dev/null
        git clean -fd >/dev/null
    }

    run_tests() {
        local i cmdline=""
        for i in "$@"; do
            cmdline="${cmdline}${i} "
        done
        printf '🧪 Running tests: %s\n' "${cmdline% }"
        "$@"
    }

    # --- main logic ------------------------------------------------------------
    # Capture all args, extract subcommand once, keep remaining args in user_cmd
    if [ $# -eq 0 ]; then
        echo "Usage: {configure|red|green|refactor|state} ..."
        return 1
    fi

    local subcmd="$1"
    shift || true
    local -a user_cmd=()
    if [ $# -gt 0 ]; then
        user_cmd=("$@")
    fi

    case "$subcmd" in
        configure)
            if [ ${#user_cmd[@]} -eq 0 ]; then
                echo "Usage: configure <test_command...>"
                return 1
            fi

            # Determine first token robustly (bash/zsh differences)
            local first_cmd
            first_cmd="${user_cmd[0]}"
            if [ -z "$first_cmd" ]; then
                first_cmd="${user_cmd[1]}"
            fi

            if [ -z "$first_cmd" ]; then
                echo "⚠️  Warning: empty command provided."
            elif command -v "$first_cmd" >/dev/null 2>&1 || [ -x "$first_cmd" ]; then
                : # ok
            else
                echo "⚠️  Warning: '$first_cmd' not found in PATH and not executable."
            fi

            {
                local a
                for a in "${user_cmd[@]}"; do
                    printf '%s\n' "$a"
                done
            } >"$CONFIG_FILE"

            echo "🧩 Test command configured: ${user_cmd[*]}"
            return 0
            ;;

        state)
            echo "📍 Current phase: $(get_phase)"
            if [ -f "$CONFIG_FILE" ]; then
                printf '🧩 Test command (configured): '
                
                {
                    local line first=1
                    while IFS= read -r line; do
                        if [ "$first" -eq 1 ]; then
                            printf '%s' "$line"
                            first=0
                        else
                            printf ' %s' "$line"
                        fi
                    done <"$CONFIG_FILE"
                    printf '\n'
                }
            else
                echo "🧩 Test command: <none>"
            fi
            return 0
            ;;

        red|green|refactor)
            
            local -a test_cmd=()
            if [ ${#user_cmd[@]} -gt 0 ]; then
                test_cmd=("${user_cmd[@]}")
            else
                if [ ! -f "$CONFIG_FILE" ]; then
                    echo "⚠️  No test command configured."
                    echo "   Use: configure <test_command...>"
                    return 1
                fi
                local cfg_line
                while IFS= read -r cfg_line; do
                    test_cmd+=("$cfg_line")
                done <"$CONFIG_FILE"
            fi

            PHASE="$(get_phase)"

            case "$subcmd" in
                red)
                    if [ "$PHASE" = "RED" ]; then
                        echo "🚫 You are in RED phase, you can only go RED after GREEN or REFACTOR ! Reverting and going back to NOT STARTED Phase ..."
                        revert_changes
                        set_phase "NOT STARTED"                        
                        return 1
                    fi

                    echo "🔴 Trying RED phase..."
                    if run_tests "${test_cmd[@]}"; then
                        echo "🤨 Expected failure but tests passed ! Reverting and going back to NOT STARTED Phase ..."
                        revert_changes
                        set_phase "NOT STARTED"
                    else
                        set_phase "RED"
                        echo "💪 Tests Fails as expected !"
                        echo "🔴 RED Phase confirmed, Make the failing test pass and go GREEN !"
                    fi
                    ;;

                green)
                    if [ "$PHASE" != "RED" ]; then
                        echo "🚫 You are in $PHASE phase, you can only go GREEN after RED ! Reverting and going back to NOT STARTED Phase ..."
                        revert_changes
                        set_phase "NOT STARTED"                        
                        return 1
                    fi

                    echo "🟢 Trying GREEN phase..."
                    if run_tests "${test_cmd[@]}"; then
                        echo "✅ Tests passed — committing code automatically."
                        git add -A >/dev/null 2>&1
                        git commit -m "GREEN: passed tests" >/dev/null 2>&1 || true
                        set_phase "GREEN"
                        echo "🟢 GREEN Phase confirmed, You can either REFACTOR or go RED !"
                    else
                        echo "💥 Tests are failing ! Reverting and staying in RED Phase ..."
                        revert_changes
                        set_phase "RED"
                    fi
                    ;;

                refactor)
                    if [ "$PHASE" != "GREEN" ]; then
                        echo "🚫 You are in $PHASE phase, can only REFACTOR when in GREEN Phase ! Reverting and going back to NOT STARTED Phase ..."
                        revert_changes
                        set_phase "NOT STARTED"
                        return 1
                    fi

                    echo "🔵 Refactoring..."
                    if run_tests "${test_cmd[@]}"; then
                        echo "♻️  Refactor successful — committing ! You stay in the GREEN Phase and can still refactor if needed."
                        git add -A >/dev/null 2>&1
                        git commit -m "REFACTOR: cleanup" >/dev/null 2>&1 || true
                    else
                        echo "💥 Refactor broke tests ! Reverting and going back to NOT STARTED Phase ..."
                        revert_changes
                        set_phase "NOT STARTED"
                    fi
                    ;;
            esac
            ;;
        collapse)
        
            local show_count=${1:-$GITTDD_COLLAPSE_DEFAULT_LOG_COUNT}

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
        
        ;;
        *)
            echo "Usage:"
            echo "  configure <test_command...>   # set test command"
            echo "  red                           # run failing test (RED phase)"
            echo "  green                         # make it pass (GREEN phase)"
            echo "  refactor                      # clean up safely"
            echo "  state                         # show current phase & command"
            echo "  collapse                      # Displays the last n (or 50) lines of git log and asks the user how many recent commits to squash and automatically performs an interactive rebase."
            ;;
    esac
}
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <playbook> [ansible-options]"
    echo ""
    echo "Runs a playbook against all configured app inventories."
    echo ""
    echo "Available playbooks:"
    echo "  setup    - Deploy backup scripts to server"
    echo "  backup   - Execute backup on all apps"
    echo "  report   - Generate backup report for all apps"
    echo "  restore  - Restore from backup (requires extra vars)"
    echo "  test     - Test backup configuration"
    echo ""
    echo "Examples:"
    echo "  $0 backup --ask-vault-pass"
    echo "  $0 report --ask-vault-pass"
    echo "  $0 setup --ask-vault-pass"
    echo ""
    echo "Note: --ask-vault-pass is required if vault files are encrypted"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

PLAYBOOK="$1"
shift

PLAYBOOK_FILE="${PROJECT_DIR}/playbooks/${PLAYBOOK}.yml"

if [[ ! -f "$PLAYBOOK_FILE" ]]; then
    echo "ERROR: Playbook not found: ${PLAYBOOK_FILE}"
    echo ""
    usage
fi

INVENTORIES_DIR="${PROJECT_DIR}/inventories"

if [[ ! -d "$INVENTORIES_DIR" ]]; then
    echo "ERROR: No inventories directory found"
    exit 1
fi

# Find all inventories (directories containing hosts.yml)
INVENTORIES=()
for dir in "$INVENTORIES_DIR"/*/; do
    if [[ -f "${dir}hosts.yml" ]]; then
        INVENTORIES+=("$dir")
    fi
done

if [[ ${#INVENTORIES[@]} -eq 0 ]]; then
    echo "ERROR: No inventories found in ${INVENTORIES_DIR}"
    echo "Each inventory must contain a hosts.yml file"
    exit 1
fi

echo "============================================"
echo "Running ${PLAYBOOK} on ${#INVENTORIES[@]} inventories"
echo "============================================"
echo ""

FAILED=()
SUCCESS=()

for inventory in "${INVENTORIES[@]}"; do
    app_name=$(basename "$inventory")
    echo ">>> Running ${PLAYBOOK} on: ${app_name}"
    echo ""

    if ansible-playbook "$PLAYBOOK_FILE" -i "$inventory" "$@"; then
        SUCCESS+=("$app_name")
    else
        FAILED+=("$app_name")
        echo ""
        echo "WARNING: ${PLAYBOOK} failed for ${app_name}"
    fi

    echo ""
    echo "--------------------------------------------"
    echo ""
done

echo "============================================"
echo "Summary"
echo "============================================"
echo "Successful: ${#SUCCESS[@]}"
for app in "${SUCCESS[@]}"; do
    echo "  - $app"
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "Failed: ${#FAILED[@]}"
    for app in "${FAILED[@]}"; do
        echo "  - $app"
    done
    exit 1
fi

echo ""
echo "All inventories completed successfully"

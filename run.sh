#!/bin/bash

# run.sh - Multi-tenant run script for Flutter
#
# Usage:
#   ./run.sh --tenant <tenant_id> [additional flutter run flags]
#   ./run.sh -t <tenant_id> [additional flutter run flags]
#
# Examples:
#   ./run.sh --tenant lulu -d chrome
#   ./run.sh -t carrefour --release
#   ./run.sh (runs using the default qless theme)

# Default values
TENANT=""
REMAINING_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)
      if [[ -n "$2" && "$2" != -* ]]; then
        TENANT="$2"
        shift 2
      else
        echo "Error: --tenant requires a non-empty argument."
        exit 1
      fi
      ;;
    -t)
      if [[ -n "$2" && "$2" != -* ]]; then
        TENANT="$2"
        shift 2
      else
        echo "Error: -t requires a non-empty argument."
        exit 1
      fi
      ;;
    *)
      REMAINING_ARGS+=("$1")
      shift
      ;;
  esac
done

# Resolve absolute directory of the script to execute fetch_tenant_config.dart
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the fetch script
if [ -n "$TENANT" ]; then
  dart run "$SCRIPT_DIR/scripts/fetch_tenant_config.dart" --tenant "$TENANT"
else
  dart run "$SCRIPT_DIR/scripts/fetch_tenant_config.dart"
fi

# Check if the fetch was successful
if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch tenant configuration."
  exit 1
fi

echo -e "\nRunning: flutter run -d chrome --web-browser-flag \"--disable-web-security\" ${REMAINING_ARGS[@]}"
flutter run -d chrome --web-browser-flag "--disable-web-security" "${REMAINING_ARGS[@]}"

#!/bin/bash

# build.sh - Multi-tenant build script for Flutter
#
# Usage:
#   ./build.sh --tenant <tenant_id> <flutter build subcommand> [additional flutter flags]
#   ./build.sh -t <tenant_id> <flutter build subcommand> [additional flutter flags]
#
# Examples:
#   ./build.sh --tenant lulu apk --release
#   ./build.sh -t carrefour web
#   ./build.sh appbundle (builds using the default qless theme)
#   ./build.sh --tenant lulu (updates the theme config only for local run/development)

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

# Run the actual flutter build command if build subcommand was provided
if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
  echo -e "\nRunning: flutter build ${REMAINING_ARGS[@]}"
  flutter build "${REMAINING_ARGS[@]}"
else
  echo -e "\nNo flutter build subcommand provided. Updated theme config only."
fi

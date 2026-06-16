#!/bin/bash

# 1. Define the web server port
PORT=8080

# 2. Automatically detect the Codespace environment
if [ -n "$CODESPACE_NAME" ]; then
    # Construct the unique public URL for your Codespace
    FINAL_URL="https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    
    echo "======================================================================="
    echo "🚀 GITHUB CODESPACE DETECTED"
    echo "🎯 Flutter web server is starting on port $PORT..."
    echo "======================================================================="
    echo ""
    echo "💡 BECAUSE CHROMA URL IS HARDCODED, FOLLOW THESE TWO STEPS:"
    echo ""
    echo "👉 STEP 1: Copy this command and run it in your LOCAL Windows PowerShell:"
    echo "-----------------------------------------------------------------------"
    printf "\033[1;33m& \"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe\" --disable-web-security --user-data-dir=\"C:\\tmp\\chrome_dev\"\033[0m\n"
    echo "-----------------------------------------------------------------------"
    echo ""
    echo "👉 STEP 2: Paste this exact app URL into that new Chrome window:"
    echo "-----------------------------------------------------------------------"
    printf "   \033[1;36m${FINAL_URL}\033[0m\n"
    echo "======================================================================="
    echo ""
else
    # Fallback for local machine deployment
    FINAL_URL="http://localhost:${PORT}"
    echo "========================================================"
    echo "💻 LOCAL ENVIRONMENT DETECTED"
    echo "🔗 Open link: ${FINAL_URL}"
    echo "========================================================"
fi

# 3. Spin up the Flutter web server headlessly
flutter run -d web-server --web-hostname 0.0.0.0 --web-port $PORT
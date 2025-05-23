#!/bin/bash
# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Tests directory
TESTS_DIR="tests"

# Check if the tests directory exists
if [[ ! -d "$TESTS_DIR" ]]; then
    echo "The directory $TESTS_DIR does not exist. Please create it and add your .exp files."
    exit 1
fi

# Create a temporary directory for logs
LOG_DIR=$(mktemp -d /tmp/test_logs.XXXXXX)

# Report file
REPORT_FILE="${LOG_DIR}/report.txt"

# Print header for the report
echo -e "Test Report\n" > "$REPORT_FILE"
echo -e "===========\n" >> "$REPORT_FILE"

# Go to the tests directory
cd "$TESTS_DIR"

# Find all .exp files in the tests directory
EXP_FILES=$(find "." -type f -name "*.exp")

# Check if there are any .exp files
if [[ -z "$EXP_FILES" ]]; then
    echo "No .exp files found in $TESTS_DIR."
    exit 1
fi

# Run each .exp file and capture outputs
for exp_file in $EXP_FILES; do
    echo -e "\nRunning $exp_file..."

    # Capture the output and error
    output_file="${LOG_DIR}/$(basename "$exp_file").out"
    error_file="${LOG_DIR}/$(basename "$exp_file").err"

    expect "$exp_file" >"$output_file" 2>"$error_file"
    result=$?

    if [[ $result -ne 0 ]]; then
        echo -e "Test ${RED}$exp_file${NC} failed with exit code $result."
        echo -e "Test $exp_file: ${RED}FAILED${NC}" >> "$REPORT_FILE"
        echo -e "\nOutput:" >> "$REPORT_FILE"
        cat "$output_file" >> "$REPORT_FILE"
        echo -e "\nError Output:" >> "$REPORT_FILE"
        cat "$error_file" >> "$REPORT_FILE"
        echo -e "\n" >> "$REPORT_FILE"
    else
        echo -e "\n"
        echo -e "************************************"
        echo -e "Test ${GREEN}$exp_file${NC} passed."
        echo -e "************************************"
        echo -e "\n"
        echo -e "Test $exp_file: ${GREEN}PASSED${NC}" >> "$REPORT_FILE"
        echo -e "\n" >> "$REPORT_FILE"
    fi
done

echo -e "Detailed logs are available in $LOG_DIR"

# Summary report
cat "$REPORT_FILE"

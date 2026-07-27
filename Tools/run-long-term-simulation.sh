#!/bin/bash

set -euo pipefail

SEEDS="1...30"
YEARS="10"
BUSINESS_TYPES="general,sports,camper,imported,outdoor,commercial,welfare,mobileBusiness"
DESTINATION="${SIM_DESTINATION:-}"
OUTPUT_DIR=""

usage() {
    echo "Usage: $0 [--seeds 1...30|1,2,3] [--years 1...10] [--business-types general,sports,camper,imported,outdoor,commercial,welfare,mobileBusiness] [--destination DEST] [--output DIR]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --seeds)
            SEEDS="$2"
            shift 2
            ;;
        --years)
            YEARS="$2"
            shift 2
            ;;
        --business-types)
            BUSINESS_TYPES="$2"
            shift 2
            ;;
        --destination)
            DESTINATION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! "$YEARS" =~ ^[0-9]+$ ]] || (( YEARS < 1 || YEARS > 10 )); then
    echo "--years must be an integer from 1 through 10" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVICE_ID=""
if [[ -z "$DESTINATION" ]]; then
    DEVICE_ID="$(xcrun simctl list devices available \
        | sed -n 's/.*iPhone 16 (\([0-9A-F-]*\)) (.*/\1/p' \
        | head -n 1)"
    if [[ -z "$DEVICE_ID" ]]; then
        DEVICE_ID="$(xcrun simctl list devices available \
            | sed -n 's/.*iPhone[^()]*(\([0-9A-F-]*\)) (.*/\1/p' \
            | head -n 1)"
    fi
    if [[ -z "$DEVICE_ID" ]]; then
        echo "No available iPhone Simulator was found. Pass --destination explicitly." >&2
        exit 1
    fi
    DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
elif [[ "$DESTINATION" =~ id=([^,]+) ]]; then
    DEVICE_ID="${BASH_REMATCH[1]}"
else
    echo "A custom --destination must contain an explicit Simulator id." >&2
    exit 2
fi
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$PROJECT_DIR/build/simulation-results/$(date -u +%Y%m%dT%H%M%SZ)"
elif [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$PROJECT_DIR/$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"
RESULT_BUNDLE="$OUTPUT_DIR/TestResults.xcresult"
ATTACHMENTS_DIR="$OUTPUT_DIR/attachments"
LOG_FILE="$OUTPUT_DIR/xcodebuild.log"
DERIVED_DATA_ARGS=()
if [[ -n "${SIM_DERIVED_DATA_PATH:-}" ]]; then
    if [[ "$SIM_DERIVED_DATA_PATH" = /* ]]; then
        DERIVED_DATA_ARGS=(-derivedDataPath "$SIM_DERIVED_DATA_PATH")
    else
        DERIVED_DATA_ARGS=(-derivedDataPath "$PROJECT_DIR/$SIM_DERIVED_DATA_PATH")
    fi
fi

echo "Dedicated business-type simulation"
echo "  seeds: $SEEDS"
echo "  years: $YEARS"
echo "  business types: $BUSINESS_TYPES"
echo "  output: $OUTPUT_DIR"

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl spawn "$DEVICE_ID" launchctl setenv RUN_LONG_TERM_SIMULATION 1
xcrun simctl spawn "$DEVICE_ID" launchctl setenv SIMULATION_SEEDS "$SEEDS"
xcrun simctl spawn "$DEVICE_ID" launchctl setenv SIMULATION_YEARS "$YEARS"
xcrun simctl spawn "$DEVICE_ID" launchctl setenv SIMULATION_BUSINESS_TYPES "$BUSINESS_TYPES"
xcrun simctl spawn "$DEVICE_ID" launchctl setenv SWIFT_DETERMINISTIC_HASHING 1

cleanup_environment() {
    xcrun simctl spawn "$DEVICE_ID" launchctl unsetenv RUN_LONG_TERM_SIMULATION >/dev/null 2>&1 || true
    xcrun simctl spawn "$DEVICE_ID" launchctl unsetenv SIMULATION_SEEDS >/dev/null 2>&1 || true
    xcrun simctl spawn "$DEVICE_ID" launchctl unsetenv SIMULATION_YEARS >/dev/null 2>&1 || true
    xcrun simctl spawn "$DEVICE_ID" launchctl unsetenv SIMULATION_BUSINESS_TYPES >/dev/null 2>&1 || true
    xcrun simctl spawn "$DEVICE_ID" launchctl unsetenv SWIFT_DETERMINISTIC_HASHING >/dev/null 2>&1 || true
}
trap cleanup_environment EXIT

(
    cd "$PROJECT_DIR"
    xcodebuild test \
        -project UsedCarCity.xcodeproj \
        -scheme UsedCarCity \
        -destination "$DESTINATION" \
        -only-testing:UsedCarCityTests/LongTermSimulationTests/testGenerateTenYearBusinessTypeReport \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled NO \
        "${DERIVED_DATA_ARGS[@]}" \
        -resultBundlePath "$RESULT_BUNDLE" \
        CODE_SIGNING_ALLOWED=NO
) 2>&1 | tee "$LOG_FILE"

xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACHMENTS_DIR"

for expected in business-type-report.json business-type-report.md; do
    extension="${expected##*.}"
    source_file="$(find "$ATTACHMENTS_DIR" -type f -name "*.$extension" ! -name manifest.json -print -quit)"
    if [[ -z "$source_file" ]]; then
        echo "Missing exported attachment: $expected" >&2
        echo "See $ATTACHMENTS_DIR/manifest.json" >&2
        exit 1
    fi
    cp "$source_file" "$OUTPUT_DIR/$expected"
done

echo "Reports generated:"
echo "  $OUTPUT_DIR/business-type-report.md"
echo "  $OUTPUT_DIR/business-type-report.json"

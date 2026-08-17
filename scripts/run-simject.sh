#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SIMJECT_DIR="/opt/simject"
readonly TWEAK_NAME="Textyle"
readonly RUNTIME_IDENTIFIER="${TEXTYLE_SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-2}"
readonly TEST_HOST_BUNDLE_IDENTIFIER="com.apple.reminders"
readonly PREFERENCE_PROBE_BUNDLE_IDENTIFIER="com.apple.MobileSMS"

print_command() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    print_command "$@"
    "$@"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

assert_log_contains() {
    local output="$1"
    local expected="$2"
    local failure="$3"
    [[ "$output" == *"$expected"* ]] || fail "$failure"
}

assert_log_omits() {
    local output="$1"
    local unexpected="$2"
    local failure="$3"
    [[ "$output" != *"$unexpected"* ]] || fail "$failure"
}

[[ -d "$SIMJECT_DIR" ]] || fail "$SIMJECT_DIR is missing; configure simject first"
[[ -f "$SIMJECT_DIR/simject.dylib" ]] || fail "simject.dylib is missing"
[[ -f "$SIMJECT_DIR/simject.plist" ]] || fail "simject.plist is missing"
command -v resim >/dev/null || fail "resim is not available"
command -v jq >/dev/null || fail "jq is required"

case "$(uname -m)" in
    arm64)
        simulator_target="simulator:clang::12.0"
        simulator_arch="arm64"
        ;;
    x86_64)
        simulator_target="simulator:clang::7.0"
        simulator_arch="x86_64"
        ;;
    *)
        fail "unsupported Mac architecture: $(uname -m)"
        ;;
esac

devices_json="$(xcrun simctl list devices available -j)"
requested_udid="${TEXTYLE_SIMULATOR_UDID:-}"
selected="$(jq -r \
    --arg runtime "$RUNTIME_IDENTIFIER" \
    --arg requested "$requested_udid" '
        (.devices[$runtime] // []) as $devices |
        if $requested != "" then
            [$devices[] | select(.udid == $requested)]
        else
            ([$devices[] | select(.state == "Booted" and
                                  (.deviceTypeIdentifier | contains(".iPhone-")))] +
             [$devices[] | select(.name == "iPhone 17 Pro")] +
             [$devices[] | select(.deviceTypeIdentifier | contains(".iPhone-"))])
        end |
        .[0] | select(. != null) | [.name, .udid] | @tsv
    ' <<<"$devices_json")"
[[ -n "$selected" ]] || fail "no iPhone is available for $RUNTIME_IDENTIFIER"

IFS=$'\t' read -r simulator_name simulator_udid <<<"$selected"
printf 'CoreSimulator: %s (%s), runtime=%s\n' \
    "$simulator_name" "$simulator_udid" "$RUNTIME_IDENTIFIER"
printf 'Protected loader files: %s, %s\n' \
    "$SIMJECT_DIR/simject.dylib" "$SIMJECT_DIR/simject.plist"

cd "$REPO_ROOT"
run make clean \
    TARGET="$simulator_target" \
    ARCHS="$simulator_arch" \
    TEXTYLE_SIMJECT=1
run make Textyle.all.tweak.variables \
    TARGET="$simulator_target" \
    ARCHS="$simulator_arch" \
    TEXTYLE_SIMJECT=1

artifact="$REPO_ROOT/.theos/obj/iphone_simulator/$TWEAK_NAME.dylib"
if [[ ! -f "$artifact" ]]; then
    artifact="$REPO_ROOT/.theos/obj/iphone_simulator/debug/$TWEAK_NAME.dylib"
fi
[[ -f "$artifact" ]] || fail "simulator artifact was not produced: $artifact"
file_output="$(file "$artifact")"
build_output="$(xcrun vtool -show-build "$artifact")"
printf '%s\n%s\n' "$file_output" "$build_output"
[[ "$file_output" == *"$simulator_arch"* ]] || fail "artifact lacks $simulator_arch"
[[ "$build_output" == *"platform IOSSIMULATOR"* ]] ||
    fail "artifact is not an iOS Simulator Mach-O"

styles_source="$REPO_ROOT/layout/Library/Application Support/Textyle/styles.plist"
prefs_source="$REPO_ROOT/Simulator/com.ryannair05.textyle.plist"
icon_2x_source="$REPO_ROOT/preferences/Resources/menuIcon@2x.png"
icon_3x_source="$REPO_ROOT/preferences/Resources/menuIcon@3x.png"
for source in "$styles_source" "$prefs_source" "$icon_2x_source" "$icon_3x_source"; do
    [[ -f "$source" ]] || fail "required simulator resource is missing: $source"
done

# Only Textyle-owned files are replaced. The simject loader and other tweaks are preserved.
run install -m 755 "$artifact" "$SIMJECT_DIR/Textyle.dylib"
run install -m 644 "$REPO_ROOT/Textyle.plist" "$SIMJECT_DIR/Textyle.plist"
run install -m 644 "$styles_source" "$SIMJECT_DIR/Textyle.styles.plist"
run install -m 644 "$styles_source" "$SIMJECT_DIR/Textyle.user-styles.plist"
run install -m 644 "$prefs_source" "$SIMJECT_DIR/com.ryannair05.textyle.plist"
# Prevent a prior verification run from changing this run's baseline style set.
rm -f "$SIMJECT_DIR/Textyle.enabled-styles.plist"
run install -m 644 "$icon_2x_source" "$SIMJECT_DIR/Textyle.menuIcon@2x.png"
run install -m 644 "$icon_3x_source" "$SIMJECT_DIR/Textyle.menuIcon@3x.png"
run codesign -f -s - "$SIMJECT_DIR/Textyle.dylib"

run open -a Simulator
state="$(xcrun simctl list devices -j | jq -r \
    --arg udid "$simulator_udid" \
    '.devices[][] | select(.udid == $udid) | .state')"
if [[ "$state" != "Booted" ]]; then
    run xcrun simctl boot "$simulator_udid"
fi
run xcrun simctl bootstatus "$simulator_udid" -b

log_start="$(date '+%Y-%m-%d %H:%M:%S')"
springboard_pid_before="$(xcrun simctl spawn "$simulator_udid" launchctl print \
    user/501/com.apple.SpringBoard 2>/dev/null |
    awk '$1 == "pid" && $2 == "=" { print $3; exit }')"
run resim -i "$simulator_udid"

springboard_pid_after=""
for _ in $(seq 1 30); do
    springboard_pid_after="$(xcrun simctl spawn "$simulator_udid" launchctl print \
        user/501/com.apple.SpringBoard 2>/dev/null |
        awk '$1 == "pid" && $2 == "=" { print $3; exit }' || true)"
    if [[ -n "$springboard_pid_after" &&
          "$springboard_pid_after" != "$springboard_pid_before" ]]; then
        break
    fi
    sleep 1
done
[[ -n "$springboard_pid_after" &&
   "$springboard_pid_after" != "$springboard_pid_before" ]] ||
    fail "SpringBoard did not restart after resim"
printf 'SpringBoard restarted: %s -> %s\n' \
    "$springboard_pid_before" "$springboard_pid_after"

# resim is asynchronous on current CoreSimulator releases. Reassert and verify the
# loader variables after the restarted launchd hierarchy is stable.
run xcrun simctl spawn "$simulator_udid" launchctl setenv \
    DYLD_INSERT_LIBRARIES "$SIMJECT_DIR/simject.dylib"
run xcrun simctl spawn "$simulator_udid" launchctl setenv \
    __XPC_DYLD_INSERT_LIBRARIES "$SIMJECT_DIR/simject.dylib"
injected_loader="$(xcrun simctl spawn "$simulator_udid" launchctl getenv \
    DYLD_INSERT_LIBRARIES)"
[[ "$injected_loader" == "$SIMJECT_DIR/simject.dylib" ]] ||
    fail "simject loader was not installed in the CoreSimulator launch environment"

print_command xcrun simctl terminate "$simulator_udid" "$TEST_HOST_BUNDLE_IDENTIFIER"
xcrun simctl terminate "$simulator_udid" "$TEST_HOST_BUNDLE_IDENTIFIER" \
    2>/dev/null || true
run xcrun simctl launch "$simulator_udid" "$TEST_HOST_BUNDLE_IDENTIFIER"

log_output=""
for _ in $(seq 1 30); do
    log_output="$(xcrun simctl spawn "$simulator_udid" log show \
        --start "$log_start" \
        --style compact \
        --predicate 'eventMessage CONTAINS[c] "Textyle][Simject" AND process == "Reminders"' \
        2>/dev/null || true)"
    if [[ "$log_output" == *"[SelfTest] PASS"* &&
          "$log_output" == *"[SelfTest] edit-menu tint PASS"* &&
          "$log_output" == *"appended styles menu process=Reminders"* &&
          "$log_output" == *"title=Textyle image={18, 18}"* &&
          "$log_output" == *"keyboard input hook installed process=Reminders"* &&
          "$log_output" == *"modern dock hooks installed process=Reminders"* &&
          "$log_output" == *"dock configured process=Reminders owns=YES active=NO item="*" action=com.ryannair05.textyle.keyboard-dock image=YES"* ]]; then
        break
    fi
    sleep 1
done

printf '\nTextyle simulator verification:\n%s\n' "$log_output"
[[ "$log_output" == *"loaded process="*"bundle=com.apple.reminders"* ]] ||
    fail "Textyle did not load into the Reminders test host through simject"
[[ "$log_output" == *"modern edit-menu hooks installed process="* ]] ||
    fail "modern edit-menu hooks were not initialized in the test host"
[[ "$log_output" == *"[SelfTest] PASS"* ]] ||
    fail "the injected UIKit self-test did not pass"
[[ "$log_output" == *"[SelfTest] edit-menu tint PASS"* ]] ||
    fail "the edit-menu tint contract did not pass"
[[ "$log_output" == *"appended styles menu process=Reminders"* ]] ||
    fail "the modern menu preparation hook did not append the Textyle submenu"
[[ "$log_output" == *"title=Textyle image={18, 18}"* ]] ||
    fail "the Textyle submenu did not use the normalized title and 18-point icon"
[[ "$log_output" == *"keyboard input hook installed process=Reminders"* ]] ||
    fail "the keyboard input hook was not initialized in the UIKit client"
[[ "$log_output" == *"modern dock hooks installed process=Reminders"* ]] ||
    fail "the native custom-action dock hook was not initialized in the UIKit client"
[[ "$log_output" == *"dock configured process=Reminders owns=YES active=NO item="*" action=com.ryannair05.textyle.keyboard-dock image=YES"* ]] ||
    fail "UIKit did not install Textyle's native custom dock action"

screenshot_path="${TEXTYLE_SIMULATOR_SCREENSHOT:-/tmp/textyle-simject-verification.png}"
rm -f "$screenshot_path"
run xcrun simctl io "$simulator_udid" screenshot "$screenshot_path"

if [[ "$RUNTIME_IDENTIFIER" == *".iOS-26-"* ]]; then
    expected_selector_effect="UIGlassEffect"
else
    expected_selector_effect="UIBlurEffect"
fi

for _ in $(seq 1 20); do
    log_output="$(xcrun simctl spawn "$simulator_udid" log show \
        --start "$log_start" \
        --style compact \
        --predicate 'eventMessage CONTAINS[c] "Textyle][Simject" AND process == "Reminders"' \
        2>/dev/null || true)"
    if [[ "$log_output" == *"[SelfTest] style selector PASS effect=$expected_selector_effect"* &&
          "$log_output" == *"[SelfTest] selection update PASS"* &&
          "$log_output" == *"style selector animation PASS source="* &&
          "$log_output" == *"[SelfTest] live typing PASS process=Reminders manager=UIKBInputDelegateManager started-inactive=YES active=YES"* ]]; then
        break
    fi
    sleep 1
done

printf '\nTextyle style-selector verification:\n%s\n' "$log_output"
[[ "$log_output" == *"[SelfTest] style selector PASS effect=$expected_selector_effect"* ]] ||
    fail "the style selector did not pass with $expected_selector_effect"
[[ "$log_output" == *"[SelfTest] selection update PASS"* ]] ||
    fail "changing the selected style scrolled the selector"
[[ "$log_output" == *"style selector animation PASS source="* ]] ||
    fail "the style selector source-anchored animation did not complete"
[[ "$log_output" == *"[SelfTest] live typing PASS process=Reminders manager=UIKBInputDelegateManager started-inactive=YES active=YES"* ]] ||
    fail "the active UIKit input manager did not transform live typing"

springboard_log="$(xcrun simctl spawn "$simulator_udid" log show \
    --start "$log_start" \
    --style compact \
    --predicate 'eventMessage CONTAINS[c] "Textyle][Simject][CrossProcess" AND process == "SpringBoard"' \
    2>/dev/null || true)"
printf '\nTextyle cross-process verification:\n%s\n' "$springboard_log"
assert_log_contains "$log_output" \
    "[CrossProcess] sender process=Reminders live=YES" \
    "the Reminders cross-process state sender did not run while live typing was active"
assert_log_contains "$springboard_log" \
    "[CrossProcess] style received process=SpringBoard" \
    "SpringBoard did not receive the selected style from Reminders"
assert_log_contains "$springboard_log" \
    "[CrossProcess] dock received process=SpringBoard uses-textyle=NO live=NO" \
    "SpringBoard did not receive the dictation dock mode without inheriting live typing"
assert_log_contains "$springboard_log" \
    "[CrossProcess] dock received process=SpringBoard uses-textyle=YES live=NO" \
    "SpringBoard did not receive the restored Textyle dock mode"

selector_screenshot_path="${TEXTYLE_SELECTOR_SCREENSHOT:-/tmp/textyle-simject-style-selector.png}"
rm -f "$selector_screenshot_path"
sleep 1
run xcrun simctl io "$simulator_udid" screenshot "$selector_screenshot_path"

installed_preferences="$SIMJECT_DIR/com.ryannair05.textyle.plist"

launch_preference_probe() {
    local expected="$1"
    local probe_start
    local probe_log=""

    # Keep consecutive launches out of the same log-show second.
    sleep 1
    probe_start="$(date '+%Y-%m-%d %H:%M:%S')"
    xcrun simctl terminate "$simulator_udid" "$PREFERENCE_PROBE_BUNDLE_IDENTIFIER" \
        2>/dev/null || true
    run xcrun simctl launch "$simulator_udid" "$PREFERENCE_PROBE_BUNDLE_IDENTIFIER"

    for _ in $(seq 1 20); do
        probe_log="$(xcrun simctl spawn "$simulator_udid" log show \
            --start "$probe_start" \
            --style compact \
            --predicate 'eventMessage CONTAINS[c] "Textyle][Simject"' \
            2>/dev/null || true)"
        if [[ "$probe_log" == *"$expected"* ]]; then
            break
        fi
        sleep 1
    done

    printf '\nPreference probe (%s):\n%s\n' "$expected" "$probe_log"
    assert_log_contains "$probe_log" "$expected" \
        "preference probe did not report: $expected"
    PREFERENCE_PROBE_LOG="$probe_log"
}

printf '\nRunning preference matrix…\n'

# Master enable switch.
install -m 644 "$prefs_source" "$installed_preferences"
plutil -replace Enabled -bool false "$installed_preferences"
launch_preference_probe "[Preferences] process=MobileSMS enabled=NO"
assert_log_omits "$PREFERENCE_PROBE_LOG" \
    "modern edit-menu hooks installed process=MobileSMS" \
    "disabled Textyle still installed application hooks"

# Per-application exclusion list written by AltList.
install -m 644 "$prefs_source" "$installed_preferences"
plutil -insert enabledApps -json '["com.apple.MobileSMS"]' "$installed_preferences"
launch_preference_probe "[Preferences] process=MobileSMS excluded=YES"
assert_log_omits "$PREFERENCE_PROBE_LOG" \
    "modern edit-menu hooks installed process=MobileSMS" \
    "an excluded application still installed Textyle hooks"

# Toggle, tint, icon visibility, label, active style, and dock ownership off-paths.
install -m 644 "$prefs_source" "$installed_preferences"
plutil -replace ToggleMenu -bool false "$installed_preferences"
plutil -replace TintMenu -bool false "$installed_preferences"
plutil -replace MenuIcon -bool false "$installed_preferences"
plutil -replace TintIcon -bool true "$installed_preferences"
plutil -replace MenuLabel -string PreferenceProbeNone "$installed_preferences"
plutil -replace ActiveStyle -string italic "$installed_preferences"
plutil -replace DockUsesTextyle -bool false "$installed_preferences"
launch_preference_probe "toggle=NO tint-menu=NO menu-image=none menu-label=PreferenceProbeNone requested-style=italic effective-style=italic dock-textyle=NO live=NO"
assert_log_contains "$PREFERENCE_PROBE_LOG" \
    "runtime process=MobileSMS menu-title=PreferenceProbeNone image=none rendering=none" \
    "the no-icon menu preference was not applied at runtime"
assert_log_contains "$PREFERENCE_PROBE_LOG" \
    "modern edit-menu hooks installed process=MobileSMS" \
    "disabling the keyboard toggle incorrectly disabled the edit menu"
assert_log_omits "$PREFERENCE_PROBE_LOG" \
    "modern dock hooks installed process=MobileSMS" \
    "the disabled keyboard toggle still installed dock hooks"
assert_log_omits "$PREFERENCE_PROBE_LOG" \
    "keyboard input hook installed process=MobileSMS" \
    "the disabled keyboard toggle still installed input hooks"
assert_log_omits "$PREFERENCE_PROBE_LOG" \
    "modern edit-menu tint hooks installed process=MobileSMS" \
    "the disabled tint preference still installed tint hooks"

# Tinted icon and custom-label on-paths.
install -m 644 "$prefs_source" "$installed_preferences"
plutil -replace TintIcon -bool true "$installed_preferences"
plutil -replace MenuLabel -string PreferenceProbeTinted "$installed_preferences"
plutil -replace ActiveStyle -string italic "$installed_preferences"
launch_preference_probe "toggle=YES tint-menu=YES menu-image=tinted menu-label=PreferenceProbeTinted requested-style=italic effective-style=italic dock-textyle=YES live=NO"
assert_log_contains "$PREFERENCE_PROBE_LOG" \
    "runtime process=MobileSMS menu-title=PreferenceProbeTinted image={18, 18} rendering=original" \
    "the tinted menu icon preference was not applied at runtime"
assert_log_contains "$PREFERENCE_PROBE_LOG" \
    "modern dock hooks installed process=MobileSMS" \
    "the enabled keyboard toggle did not install dock hooks"
assert_log_contains "$PREFERENCE_PROBE_LOG" \
    "keyboard input hook installed process=MobileSMS" \
    "the enabled keyboard toggle did not install input hooks"
if [[ "$RUNTIME_IDENTIFIER" != *".iOS-26-"* ]]; then
    assert_log_contains "$PREFERENCE_PROBE_LOG" \
        "modern edit-menu tint hooks installed process=MobileSMS" \
        "the enabled tint preference did not install iOS 18 tint hooks"
fi

# Per-style enable switches must affect the effective style set.
install -m 644 "$prefs_source" "$installed_preferences"
plutil -create xml1 "$SIMJECT_DIR/Textyle.enabled-styles.plist"
plutil -insert bold -bool false "$SIMJECT_DIR/Textyle.enabled-styles.plist"
launch_preference_probe "requested-style=bold effective-style=italic"

# Leave the shared simject installation in its normal baseline state.
install -m 644 "$prefs_source" "$installed_preferences"
rm -f "$SIMJECT_DIR/Textyle.enabled-styles.plist"

printf '\nSimject verification passed.\n'
printf 'Simulator: %s (%s)\n' "$simulator_name" "$simulator_udid"
printf 'Installed: %s\n' "$SIMJECT_DIR/Textyle.dylib"
printf 'Edit-menu screenshot: %s\n' "$screenshot_path"
printf 'Style-selector screenshot: %s\n' "$selector_screenshot_path"

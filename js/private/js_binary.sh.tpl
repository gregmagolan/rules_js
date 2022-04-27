#!/usr/bin/env bash

# shellcheck disable=SC1090
{
{rlocation_function}
}

set -o pipefail -o errexit -o nounset

{env}

LOG_PREFIX="aspect_rules_js[js_binary]"

# ==============================================================================
# Initialize RUNFILES environment variable
# ==============================================================================

# It helps to determine if we are running on a Windows environment (excludes WSL as it acts like Unix)
function is_windows {
    case "$(uname -s)" in
        CYGWIN*)    local IS_WINDOWS=1 ;;
        MINGW*)     local IS_WINDOWS=1 ;;
        MSYS_NT*)   local IS_WINDOWS=1 ;;
        *)          local IS_WINDOWS=0 ;;
    esac

    echo $IS_WINDOWS
    return
}

# It helps to normalizes paths when running on Windows.
#
# Example:
# C:/Users/XUser/_bazel_XUser/7q7kkv32/execroot/A/b/C -> /c/users/xuser/_bazel_xuser/7q7kkv32/execroot/a/b/c
function normalize_windows_path {
    # Apply the followings paths transformations to normalize paths on Windows
    # -process driver letter
    # -convert path separator
    # -lowercase everything
    sed -e 's#^\(.\):#/\L\1#' -e 's#\\#/#g' -e 's/[A-Z]/\L&/g' <<< "$1"
    return
}

# Find our runfiles as ${PWD}/${RUNFILES_DIR} is not always correct.
# We need this to launch node with the correct entry point.
#
# Call this program X. X was generated by a genrule and may be invoked
# in many ways:
#   1a) directly by a user, with $0 in the output tree
#   1b) via 'bazel run' (similar to case 1a)
#   2) directly by a user, with $0 in X's runfiles
#   3) by another program Y which has a data dependency on X, with $0 in Y's
#      runfiles
#   4a) via 'bazel test'
#   4b) case 3 in the context of a test
#   5a) by a genrule cmd, with $0 in the output tree
#   6a) case 3 in the context of a genrule
#
# For case 1, $0 will be a regular file, and the runfiles will be
# at $0.runfiles.
# For case 2 or 3, $0 will be a symlink to the file seen in case 1.
# For case 4, $TEST_SRCDIR should already be set to the runfiles by
# blaze.
# Case 5a is handled like case 1.
# Case 6a is handled like case 3.
if [ "${RUNFILES_MANIFEST_ONLY:-}" ]; then
    # Windows only has a manifest file instead of symlinks.
    if [ "$(is_windows)" -eq "1" ]; then
        # If Windows normalizing the path and case insensitive removing the `/MANIFEST` part of the path
        NORMALIZED_RUNFILES_MANIFEST_FILE_PATH=$(normalize_windows_path "$RUNFILES_MANIFEST_FILE")
        # shellcheck disable=SC2001
        RUNFILES=$(sed 's|\/MANIFEST$||i' <<< "$NORMALIZED_RUNFILES_MANIFEST_FILE_PATH")
    else
        RUNFILES=${RUNFILES_MANIFEST_FILE%/MANIFEST}
    fi
elif [ "${TEST_SRCDIR:-}" ]; then
    # Case 4, bazel has identified runfiles for us.
    RUNFILES="$TEST_SRCDIR"
else
    case "$0" in
    /*) self="$0" ;;
    *) self="$PWD/$0" ;;
    esac
    while true; do
        if [ -e "$self.runfiles" ]; then
            RUNFILES="$self.runfiles"
            break
        fi

        if [[ "$self" == *.runfiles/* ]]; then
            RUNFILES="${self%%.runfiles/*}.runfiles"
            # don't break; this is a last resort for case 6b
        fi

        if [ ! -L "$self" ]; then
            break;
        fi

        readlink="$(readlink "$self")"
        if [[ "$readlink" == /* ]]; then
            self="$readlink"
        else
            # resolve relative symlink
            self="${self%%/*}/$readlink"
        fi
    done

    if [ -z "$RUNFILES" ]; then
        printf "\nERROR: %s: RUNFILES environment variable is not set\n" "$LOG_PREFIX" >&2
        exit 1
    fi
fi
export RUNFILES

# ==============================================================================
# Prepare to run main program
# ==============================================================================

if [[ "$PWD" == *"/bazel-out/"* ]]; then
    # We in runfiles
    node="$PWD/{node}"
    entry_point="$PWD/{entry_point}"
else
    # We are in execroot or in some other context all together such as a nodejs_image or a manually
    # run js_binary.
    node="$RUNFILES/{workspace_name}/{node}"
    entry_point="$RUNFILES/{workspace_name}/{entry_point}"
    if [ -z "${BAZEL_BINDIR:-}" ]; then
        printf "\nERROR: %s: BAZEL_BINDIR must be set in environment when not running out of runfiles so js_binary can run out of the output tree on build actions\n" "$LOG_PREFIX" >&2
        exit 1
    fi
    cd "$BAZEL_BINDIR"
fi

if [ ! -f "$node" ]; then
    printf "\nERROR: %s: the node binary '%s' not found in runfiles\n" "$LOG_PREFIX" "$node" >&2
    exit 1
fi
if [ ! -x "$node" ]; then
    printf "\nERROR: %s: the node binary '%s' is not executable\n" "$LOG_PREFIX" "$node" >&2
    exit 1
fi
if [ ! -f "$entry_point" ]; then
    printf "\nERROR: %s: the entry_point '%s' not found in runfiles\n" "$LOG_PREFIX" "$entry_point" >&2
    exit 1
fi

if [ "${JS_BINARY__CHDIR:-}" ]; then
    cd "$JS_BINARY__CHDIR"
fi

if [ "${JS_BINARY__CAPTURE_STDOUT:-}" ]; then
    STDOUT_CAPTURE="$JS_BINARY__CAPTURE_STDOUT"
fi

if [ "${JS_BINARY__CAPTURE_STDERR:-}" ]; then
    STDERR_CAPTURE="$JS_BINARY__CAPTURE_STDERR"
fi

if [ "${JS_BINARY__SILENT_ON_SUCCESS:-}" ]; then
  if [ -z "${STDOUT_CAPTURE:-}" ]; then
    STDOUT_CAPTURE_IS_NOT_AN_OUTPUT=true
    STDOUT_CAPTURE=$(mktemp)
  fi
  if [ -z "${STDERR_CAPTURE:-}" ]; then
    STDERR_CAPTURE_IS_NOT_AN_OUTPUT=true
    STDERR_CAPTURE=$(mktemp)
  fi
fi

# Bash does not forward termination signals to any child process when
# running in docker so need to manually trap and forward the signals
_term() {
  kill -TERM "${child}" 2>/dev/null
}

_int() {
  kill -INT "${child}" 2>/dev/null
}

_exit() {
  EXIT_CODE=$?

  if [ "$EXIT_CODE" != 0 ]; then
    if [[ ${STDOUT_CAPTURE_IS_NOT_AN_OUTPUT:-} == true ]]; then
      cat "$STDOUT_CAPTURE"
      rm "$STDOUT_CAPTURE"
    fi
    if [[ ${STDERR_CAPTURE_IS_NOT_AN_OUTPUT:-} == true ]]; then
      cat "$STDERR_CAPTURE"
      rm "$STDERR_CAPTURE"
    fi
  fi

  exit $EXIT_CODE
}

NODE_OPTIONS=()
{node_options}

ARGS=()
ALL_ARGS=("$@")
for ARG in ${ALL_ARGS[@]+"${ALL_ARGS[@]}"}; do
  case "$ARG" in
    # Let users pass through arguments to node itself
    --node_options=*) NODE_OPTIONS+=( "${ARG#--node_options=}" ) ;;
    # Remaining argv is collected to pass to the program
    *) ARGS+=( "$ARG" )
  esac
done

# Put bazel managed node on the path
PATH="$(dirname "$node"):$PATH"
export PATH

# ==============================================================================
# Run the main program
# ==============================================================================

if [ "${JS_BINARY__VERBOSE:-}" ]; then
    echo "${LOG_PREFIX}: running:" "$node" ${NODE_OPTIONS[@]+"${NODE_OPTIONS[@]}"} -- "$entry_point" ${ARGS[@]+"${ARGS[@]}"} >&2
fi

set +e

if [ "${STDOUT_CAPTURE:-}" ] && [ "${STDERR_CAPTURE:-}" ]; then
    "$node" ${NODE_OPTIONS[@]+"${NODE_OPTIONS[@]}"} -- "$entry_point" ${ARGS[@]+"${ARGS[@]}"} <&0 >"$STDOUT_CAPTURE" 2>"$STDERR_CAPTURE" &
elif [ "${STDOUT_CAPTURE:-}" ]; then
    "$node" ${NODE_OPTIONS[@]+"${NODE_OPTIONS[@]}"} -- "$entry_point" ${ARGS[@]+"${ARGS[@]}"} <&0 >"$STDOUT_CAPTURE" &
elif [ "${STDERR_CAPTURE:-}" ]; then
    "$node" ${NODE_OPTIONS[@]+"${NODE_OPTIONS[@]}"} -- "$entry_point" ${ARGS[@]+"${ARGS[@]}"} <&0 2>"$STDERR_CAPTURE" &
else
    "$node" ${NODE_OPTIONS[@]+"${NODE_OPTIONS[@]}"} -- "$entry_point" ${ARGS[@]+"${ARGS[@]}"} <&0 &
fi

# ==============================================================================
# Wait for program to finish
# ==============================================================================

readonly child=$!
trap _term SIGTERM
trap _int SIGINT
trap _exit EXIT
wait "$child"
# Remove trap after first signal has been receieved and wait for child to exit
# (first wait returns immediatel if SIGTERM is received while waiting). Second
# wait is a no-op if child has already terminated.
trap - SIGTERM SIGINT
wait "$child"

RESULT="$?"
set -e

# ==============================================================================
# Mop up after main program
# ==============================================================================

if [ "${JS_BINARY__EXPECTED_EXIT_CODE:-}" ]; then
    if [ "$RESULT" != "$JS_BINARY__EXPECTED_EXIT_CODE" ]; then
        printf "\nERROR: %s: expected exit code to be '%s', but got '%s'\n" "$LOG_PREFIX" "$JS_BINARY__EXPECTED_EXIT_CODE" "$RESULT" >&2
        if [ $RESULT -eq 0 ]; then
            # This exit code is handled specially by Bazel:
            # https://github.com/bazelbuild/bazel/blob/486206012a664ecb20bdb196a681efc9a9825049/src/main/java/com/google/devtools/build/lib/util/ExitCode.java#L44
            readonly BAZEL_EXIT_TESTS_FAILED=3;
            exit $BAZEL_EXIT_TESTS_FAILED
        fi
        exit $RESULT
    else
        exit 0
    fi
fi

if [ $RESULT -eq 0 ]; then
    # TODO: add optional coverage support
    echo -n
fi

if [ "${JS_BINARY__CAPTURE_EXIT_CODE:-}" ]; then
    # Exit zero if the exit code was captured
    echo -n "$RESULT" > "$JS_BINARY__CAPTURE_EXIT_CODE"
    exit 0
else
    exit $RESULT
fi

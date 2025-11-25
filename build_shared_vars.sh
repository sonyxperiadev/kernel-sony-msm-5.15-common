# -------------------------------------------------------------------------
# Function: find_repo_root
# -------------------------------------------------------------------------
# Description:
# This function searches for the root of a repository by looking for the
# presence of a `.repo` directory. It starts in the current working
# directory and moves upwards through the directory tree, stopping when
# the root is found or a maximum depth of 10 is reached.

# Usage:
#   find_repo_root

# Returns:
#   - Prints the directory path where `.repo` is found (repository root).
#   - Exits with status code 1 if `.repo` is not found within the allowed
#     depth.

# Parameters:
#   None

# Example:
#   repo_root=$(find_repo_root)
#   echo "Repository root is: $repo_root"
# -------------------------------------------------------------------------
find_repo_root() {
    local max_depth=10
    while ! [ -e "$PWD/.repo" ] ; do
        [ $max_depth -eq 0 ] && return 1
        cd ..
        max_depth=$((max_depth-1))
    done
    echo "$PWD"
}

# -------------------------------------------------------------------------
# Function: log_pipeline
# -------------------------------------------------------------------------
# Description:
# This function logs the output of a pipeline to a log file.
# It optionally strips ANSI escape codes from the output (like terminal
# colors). If the `verbose_output` variable is set, it will also display
# the output on the screen while logging it.

# Usage:
#   log_pipeline [destination]

# Returns:
#   - Writes the output of a pipeline (with optional ANSI escape code
#     removal) to the specified destination file or the default
#     `$KERNEL_TMP_PLATFORM/build.log`.

# Parameters:
#   - destination: Optional argument specifying the log file destination.

# Example:
#   make | log_pipeline /path/to/logfile.log
# -------------------------------------------------------------------------
log_pipeline() {
    # Use the argument or fallback to the default log path
    local dest="${1:-$KERNEL_TMP_PLATFORM/build.log}"
    local strip_ansi='s/\x1B\[[0-9;]*[mK]//g'

    # Remove ANSI escape codes
    if [ -n "${verbose_output:-}" ]; then
        tee >(sed -E "$strip_ansi" >>"$dest")
    else
        sed -E "$strip_ansi" >>"$dest"
    fi
}

# -------------------------------------------------------------------------
# Function: usage
# -------------------------------------------------------------------------
# Description:
# This function displays the usage information for the script. It provides
# a summary of available command-line options and their descriptions.
# It's typically invoked when the user requests help (`-h` option) or when
# incorrect arguments are passed.

# Usage:
#   usage

# Returns:
#   - Prints the usage information to standard output and exits the script
#     with status code 0.

# Parameters:
#   None

# Example:
#   ./build-kernels-clang.sh -h  # Will display the usage information.
# -------------------------------------------------------------------------
usage() {
    cat <<EOF
Build kernel for supported devices
Usage: ${0##*/} [-k -h -p <platform> -v -O <directory>]

Options:
  -k              keep kernel tmp after build
  -h              show help message and exit
  -p <platform>   only build the kernel for <platform>
  -v              enable verbose output
  -O <directory>  build kernel in <directory>
EOF
}

arguments=khp:vO:
while getopts $arguments argument ; do
    case $argument in
        k) keep_kernel_tmp=true ;;
        p) only_build_for=$OPTARG;;
        v) verbose_output=true ;;
        O) build_directory=$OPTARG;;
        h) usage; exit 0;;
        ?) usage; exit 1;;
    esac
done

if [ -z "${ANDROID_BUILD_TOP:-}" ]; then
    ANDROID_ROOT=$(find_repo_root)
    ANDROID_ROOT=$(realpath "$ANDROID_ROOT")
    echo "ANDROID_BUILD_TOP not set, guessing root at $ANDROID_ROOT"
else
    ANDROID_ROOT="$ANDROID_BUILD_TOP"
fi

PLATFORMS="nagara yodo"

# Mkdtimg tool
MKDTIMG=$ANDROID_ROOT/out/host/linux-x86/bin/mkdtimg

KERNEL_TOP=$ANDROID_ROOT/kernel/sony/msm-5.15
# $KERNEL_TMP sub dir per script
c=${0##*-}
KERNEL_TMP=${build_directory:-$ANDROID_ROOT/out/kernel-5.15/${c%%.sh}}

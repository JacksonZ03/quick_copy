#!/bin/bash

# Get the terminal window ID
TERMINAL_WINDOW_ID=$(osascript -e 'tell application "Terminal" to id of front window')

set -e # Exit if anything fails

# Change working directory to the directory where the script is located
cd "$(dirname "$0")"

# Define source and destination directories
SOURCE_DIR="/Volumes/Untitled/PRIVATE/M4ROOT/CLIP" # Replace with the actual source directory
DEST_DIR="$(pwd)"  # Use the current directory as the destination

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

# Function to compute MD5 hash of a file
get_file_hash() {
    local file=$1
    dd if="$file" bs=1M count=1 2>/dev/null | md5 -q  # For macOS
    # dd if="$file" bs=1M count=1 2>/dev/null | md5sum | awk '{ print $1 }'  # For Linux
}

# Function to check if a file is a video using ffprobe
is_video_file() {
    local file=$1
    extension="${file##*.}"; # Get the extension
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]'); # Convert the extension to lowercase
    if [[ "$extension" == "mp4" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a hash exists in the destination hashes file
hash_exists_in_dest() {
    local hash=$1
    grep -q "^$hash " "$DEST_HASHES_FILE"
}

# Function to get the file size
get_file_size() {
    stat -f%z "$1"
}

# Function to check if a file with the same size exists in the destination directory
size_exists_in_dest() {
    local src_size="$1"
    for dest_file in "$DEST_DIR"/*; do
        if [[ -f "$dest_file" ]]; then
            dest_size=$(get_file_size "$dest_file")
            if [[ "$src_size" -eq "$dest_size" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Create a temporary file to store destination file hashes
DEST_HASHES_FILE=$(mktemp)

# Populate the temporary file with hashes of the destination files
for dest_file in "$DEST_DIR"/*; do
    if is_video_file "$dest_file"; then
        hash=$(get_file_hash "$dest_file")
        echo "$hash $dest_file" >> "$DEST_HASHES_FILE"
    fi
done

# Filter the files
filtered_files=()
for src_file in "$SOURCE_DIR"/*; do
    if is_video_file "$src_file"; then
        # Check if a file of the same size is already in the destination directory
        src_size=$(get_file_size "$src_file")
        if ! size_exists_in_dest "$src_size"; then
            filtered_files+=("$src_file")
            continue
        fi

        # Check if a matching hash is already in the destination directory
        src_hash=$(get_file_hash "$src_file")
        if ! hash_exists_in_dest "$src_hash"; then
            filtered_files+=("$src_file")
        fi
    fi
done

# Check if there are any filtered files to copy
if [ ${#filtered_files[@]} -eq 0 ]; then
    echo "No new video files to copy."
    rm "$DEST_HASHES_FILE"

    # Close the Terminal after pressing Enter
    echo "Press Enter to exit."
    read -r
    osascript -e "tell application \"Terminal\" to close (every window whose id is $TERMINAL_WINDOW_ID)" & exit 0
fi

# Prompt the user to copy all filtered files
echo "The following files are available to copy:"
for file in "${filtered_files[@]}"; do
    echo "$(basename "$file")"
done

read -p "Do you want to copy all the files? (y(yes)/n(no)/e(exit)): " user_response
if [[ "$user_response" == "e" ]]; then
    echo "Exiting."
    rm "$DEST_HASHES_FILE"
    osascript -e "tell application \"Terminal\" to close (every window whose id is $TERMINAL_WINDOW_ID)" & exit 0
elif [[ "$user_response" == "y" ]]; then # Copy all
    files_to_copy=("${filtered_files[@]}")
else
    files_to_copy=()
    for src_file in "${filtered_files[@]}"; do # Prompt the user to copy each filtered file
        read -p "Do you want to copy $(basename "$src_file")? (y(yes)/a(yes to all)/n(no)/i(ignore the rest)/e (exit)): " user_response
        case "$user_response" in
            y)
                files_to_copy+=("$src_file")
                ;;
            a)
                files_to_copy+=("${filtered_files[@]}")
                break
                ;;
            n)
                ;;
            i)
                break
                ;;
            e)
                echo "Exiting."
                rm "$DEST_HASHES_FILE"
                osascript -e "tell application \"Terminal\" to close (every window whose id is $TERMINAL_WINDOW_ID)" & exit 0
                ;;
            *)
                echo "Invalid option. Skipping this file." # TODO: Make this ask the user again rather than skipping
                ;;
        esac
    done
fi

# Confirm the list of files to copy
echo "You have chosen to copy the following files:"
for file in "${files_to_copy[@]}"; do
    echo "$(basename "$file")"
done

read -p "Do you want to proceed with copying these files? (y/n): " final_confirmation
if [[ "$final_confirmation" == "y" ]]; then
    for src_file in "${files_to_copy[@]}"; do
        echo "Copying $src_file to $DEST_DIR"
        pv "$src_file" > "$DEST_DIR/${src_file##*/}"
    done
else
    echo "Copying aborted."
fi

# Clean up temporary file
rm "$DEST_HASHES_FILE"

# Indicate script completion and wait for user to press Enter to exit
echo "Script completed. Press Enter to exit."
read -r

# Close the Terminal after pressing Enter
osascript -e "tell application \"Terminal\" to close (every window whose id is $TERMINAL_WINDOW_ID)" & exit 0

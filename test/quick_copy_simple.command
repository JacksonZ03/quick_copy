#!/bin/bash

set -e # Exit if anything fails

# Get the terminal window ID
TERMINAL_WINDOW_ID=$(osascript -e 'tell application "Terminal" to id of front window')

# Change working directory to the directory where the script is located
cd "$(dirname "$0")"

# Define source and destination directories
SOURCE_DIR="/Volumes/Untitled/PRIVATE/M4ROOT/CLIP"
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

# Loop through all files in the source directory and process video files
for src_file in "$SOURCE_DIR"/*; do
    if is_video_file "$src_file"; then
        # Check if a file of the same size is already in the destination directory
        src_size=$(get_file_size "$src_file")
        if ! size_exists_in_dest "$src_size"; then
            echo "Copying $src_file to $DEST_DIR"
            pv "$src_file" > "$DEST_DIR/${src_file##*/}"
            continue  # Move on to the next file after copying
        fi

        # Check if a matching hash is already in the destination directory
        src_hash=$(get_file_hash "$src_file")
        if ! hash_exists_in_dest "$src_hash"; then
            echo "Copying $src_file to $DEST_DIR"
            pv "$src_file" > "$DEST_DIR/${src_file##*/}"
        else
            echo "Skipping $src_file (matching hash found in destination)"
        fi
    else
        echo "Skipping non-video file: $src_file"
    fi
done

# Clean up temporary file
rm "$DEST_HASHES_FILE"

# Indicate script completion and wait for user to press Enter to exit
echo "Script completed. Press Enter to exit."
read -r

# Close the Terminal after pressing Enter
osascript -e "tell application \"Terminal\" to close (every window whose id is $TERMINAL_WINDOW_ID)" & exit 0

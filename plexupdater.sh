#!/bin/bash

# Ensure script is not run with sudo
if [ "$(id -u)" -eq 0 ]; then
    echo "This script should not be run with sudo. Please run it as a normal user."
    exit 1
fi

echo "This script looks in a subfolder from here called Downloads and if it finds a"
echo "Plexmediaserver deb file newer than the version that is installed, it will install it."
echo

# Define the folder to search
DOWNLOADS_FOLDER="./Downloads"

# Ensure the Downloads folder exists
if [ ! -d "$DOWNLOADS_FOLDER" ]; then
    echo "Error: The folder $DOWNLOADS_FOLDER does not exist."
    exit 1
fi

# Find files matching the prefix "plexmediaserver_"
files=( $(find "$DOWNLOADS_FOLDER" -type f -name "plexmediaserver_*.deb") )

# Check if any files were found
if [ ${#files[@]} -eq 0 ]; then
    echo "No files found matching the pattern 'plexmediaserver_*.deb'."
    exit 0
fi

# Extract version numbers and map to filenames
declare -A version_map

for file in "${files[@]}"; do
    # Extract the version part of the filename
    base_name=$(basename "$file")
    version=$(echo "$base_name" | sed -n 's/^plexmediaserver_\([0-9.]\+\)-[a-z0-9]\+_amd64.deb$/\1/p')

    if [ -n "$version" ]; then
        version_map["$version"]="$file"
    fi
done

if [ ${#version_map[@]} -eq 0 ]; then
    echo "No valid Plex Media Server versioned files found."
    exit 0
fi

# Sort versions to find the latest
latest_version=$(printf '%s\n' "${!version_map[@]}" | sort -V | tail -n 1)
latest_file="${version_map[$latest_version]}"

# Check current installed version of Plex Media Server
current_version=$(dpkg --list | grep plexmediaserver | awk '{print $3}' | cut -d- -f1)

if [ -n "$current_version" ]; then
    echo "Currently installed version: $current_version"
else
    echo "No version of Plex Media Server is currently installed."
fi

# Compare the versions
if [ "$current_version" == "$latest_version" ]; then
    echo "No upgrade is available. The latest version ($latest_version) is already installed."
    exit 0
fi

# Show the latest version to the user and prompt for confirmation
echo "Latest version detected: $latest_version"
read -p "Do you want to install this version? (yes/no): " user_input

if [[ "$user_input" != "yes" ]]; then
    echo "Installation aborted by the user."
    exit 0
fi

# Remove older versions
echo "Cleaning up older versions..."
for version in "${!version_map[@]}"; do
    if [ "$version" != "$latest_version" ]; then
        echo "Deleting older version: ${version_map[$version]}"
        rm -f "${version_map[$version]}"
    fi
done

# Install the latest version with sudo
echo "Installing the latest version: $latest_file"
sudo dpkg -i "$latest_file"
install_status=$?

if [ $install_status -eq 0 ]; then
    echo "Installation of $latest_file completed successfully."
else
    echo "Installation of $latest_file failed. Please check the logs for details."
    exit $install_status
fi

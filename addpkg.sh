#!/usr/bin/env bash

# Directory where packages are stored
PACKAGES_DIR="$(dirname "$(readlink -f "$0")")/packages"

# Helper function to prompt user with fzf or fallback to select
choose_option() {
    local prompt="$1"
    shift
    local options=("$@")
    if command -v fzf &> /dev/null; then
        printf "%s\n" "${options[@]}" | fzf --prompt="$prompt > " --height=15 --layout=reverse --border
    else
        echo "$prompt:" >&2
        local opt
        select opt in "${options[@]}"; do
            if [ -n "$opt" ]; then
                echo "$opt"
                break
            fi
        done
    fi
}

# 1. Get all .list files
files=($(find "$PACKAGES_DIR" -maxdepth 1 -name "*.list" -exec basename {} .list \;))
if [ ${#files[@]} -eq 0 ]; then
    echo "No .list files found in $PACKAGES_DIR"
    exit 1
fi

selected_file=$(choose_option "Select a package list file" "${files[@]}")
if [ -z "$selected_file" ]; then
    echo "No file selected."
    exit 1
fi

FILE_PATH="$PACKAGES_DIR/${selected_file}.list"

# 2. Extract category headers from the chosen file
mapfile -t categories < <(grep -E '^#\s*\[.*\]' "$FILE_PATH")

selected_cat=$(choose_option "Select a category" "${categories[@]}" "[Create New Category]")
if [ -z "$selected_cat" ]; then
    echo "No category selected."
    exit 1
fi

if [ "$selected_cat" = "[Create New Category]" ]; then
    read -p "Enter new category name: " new_cat
    if [ -z "$new_cat" ]; then
        echo "Category name cannot be empty."
        exit 1
    fi
    selected_cat="# [$new_cat]"
    # Append new category to the end of the file
    echo -e "\n$selected_cat" >> "$FILE_PATH"
fi

# 3. Get the package name
read -p "Enter package name to add: " pkg_name
if [ -z "$pkg_name" ]; then
    echo "Package name cannot be empty."
    exit 1
fi

# 4. Insert the package name right under the selected category header
tmp_file=$(mktemp)
awk -v cat="$selected_cat" -v pkg="$pkg_name" '
{
    print $0
    if ($0 == cat) {
        print pkg
    }
}
' "$FILE_PATH" > "$tmp_file" && mv "$tmp_file" "$FILE_PATH"

echo "Successfully added '$pkg_name' to '$selected_cat' in ${selected_file}.list!"

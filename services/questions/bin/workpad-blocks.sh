#!/bin/bash

# Prompt the user for structured input
read -p "Name of Block: " name_of_block
read -p "Purpose of Block: " purpose_of_block
read -p "Elements of the Block: " elements_of_the_block
read -p "Functionality of the Block: " functionality_of_the_block
read -p "Performance of the Block: " performance_of_the_block
read -p "Block Dependencies: " block_dependencies

# Build the entry using a heredoc
entry=$(cat <<ENTRY
$(date +"%Y-%m-%d %I:%M %p") New BLOCK for Workpads
Name of Block: $name_of_block
Purpose of Block: $purpose_of_block
Elements of the Block: $elements_of_the_block
Functionality of the Block: $functionality_of_the_block
Performance of the Block: $performance_of_the_block
Block Dependencies: $block_dependencies
ENTRY
)

# Optional: Show the entry before saving
echo
echo "Entry preview:"
echo "$entry"

read -p "Submit? [y/N] " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "$entry" | jrnl "wp-blocks"
    echo "✅ Entry saved."
else
    echo "❌ Entry canceled."
fi

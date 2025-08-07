#!/bin/bash

# Prompt the user for structured input
read -p "Name of Function: " name_of_function
read -p "Purpose of Function: " purpose_of_function
read -p "Technical Elements: " technical_elements
read -p "Comparable Functionality: " comparable_functionality
read -p "Technical Dependencies: " technical_dependencies
read -p "Supporting Research: " supporting_research
read -p "Function Uniqueness: " function_uniqueness
read -p "Overlap of Functions: " overlap_of_functions
read -p "Customer Value: " customer_value
read -p "Company Story: " company_story

# Build the entry using a heredoc
entry=$(cat <<ENTRY
Babb @Functions
Name of Function: $name_of_function
Purpose of Function: $purpose_of_function
Technical Elements: $technical_elements
Comparable Functionality: $comparable_functionality
Technical Dependencies: $technical_dependencies
Supporting Research: $supporting_research
Function Uniqueness: $function_uniqueness
Overlap of Functions: $overlap_of_functions
Customer Value: $customer_value
Company Story: $company_story
ENTRY
)

# Optional: Show the entry before saving
echo
echo "Entry preview:"
echo "$entry"

read -p "Submit? [y/N] " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    jrnl '"$journal"' "$entry"
    echo "✅ Entry saved."
else
    echo "❌ Entry canceled."
fi

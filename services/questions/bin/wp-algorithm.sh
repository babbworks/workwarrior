#!/bin/bash

# Prompt the user for structured input
read -p "Algorithm Name: " algorithm_name
read -p "Context for Usage: " context_for_usage
read -p "Purpose / Goal: " purpose_/_goal
read -p "Inputs: " inputs
read -p "Outputs: " outputs
read -p "Functional Requirements: " functional_requirements
read -p "Description of Algorithm: " description_of_algorithm
read -p "Data Structures Used: " data_structures_used
read -p "Dependencies: " dependencies
read -p "Constraints & Assumptions: " constraints_&_assumptions
read -p "Error Handling: " error_handling
read -p "Testing Plan: " testing_plan
read -p "Implementation Language: " implementation_language
read -p "Scalability Considerations: " scalability_considerations
read -p "Future Enhancements: " future_enhancements
read -p "References: " references

# Build the entry using a heredoc
entry=$(cat <<ENTRY
$(date +"%Y-%m-%d %I:%M %p") Algorithm for Workpads
Algorithm Name: $algorithm_name
Context for Usage: $context_for_usage
Purpose / Goal: $purpose_/_goal
Inputs: $inputs
Outputs: $outputs
Functional Requirements: $functional_requirements
Description of Algorithm: $description_of_algorithm
Data Structures Used: $data_structures_used
Dependencies: $dependencies
Constraints & Assumptions: $constraints_&_assumptions
Error Handling: $error_handling
Testing Plan: $testing_plan
Implementation Language: $implementation_language
Scalability Considerations: $scalability_considerations
Future Enhancements: $future_enhancements
References: $references
ENTRY
)

# Optional: Show the entry before saving
echo
echo "Entry preview:"
echo "$entry"

read -p "Submit? [y/N] " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "$entry" | jrnl "wp-algo"
    echo "✅ Entry saved."
else
    echo "❌ Entry canceled."
fi

#!/bin/bash

# Define your questions
questions=(
    "Name for New Inquiry"
    "What did I accomplish today?"
    "What challenges did I face?"
    "What am I grateful for?"
    "What are my goals for tomorrow?"
)

# Initialize the journal entry
entry=""

# Loop through the questions
for question in "${questions[@]}"; do
    echo "$question"
    read -r response
    entry+="$question\n$response\n\n"
done

# Add the entry to jrnl
echo -e "$entry" | jrnl mg

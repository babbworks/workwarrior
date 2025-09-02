function q() {
  # Check if Workwarrior profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please activate one with 'p-<profile-name>'." >&2
    return 1
  fi

  local questions_dir="$WORKWARRIOR_BASE/services/questions"
  local templates_dir="$questions_dir/templates"
  local handlers_dir="$questions_dir/handlers"
  local lib_dir="$questions_dir/lib"
  
  # Create directory structure if it doesn't exist
  if [[ ! -d "$questions_dir" ]]; then
    mkdir -p "$templates_dir"/{task,journal,time,todo,ledger,custom}
    mkdir -p "$handlers_dir"
    mkdir -p "$lib_dir"
    mkdir -p "$questions_dir/config"
  fi

  # No arguments - show main menu
  if [[ $# -eq 0 ]]; then
    echo "Questions Manager Service"
    echo "========================"
    echo "Available services:"
    echo "  task     - Task management questions"
    echo "  journal  - Journal entry questions"
    echo "  time     - Time tracking questions"
    echo "  todo     - Todo list questions"
    echo "  ledger   - Financial/ledger questions"
    echo ""
    echo "Usage:"
    echo "  q <service>           - List templates for service"
    echo "  q <service> <template> - Use existing template"
    echo "  q new                 - Create new custom template"
    echo "  q new <service>       - Create new template for service"
    echo "  q list                - List all templates"
    echo "  q edit <template>     - Edit existing template"
    echo "  q delete <template>   - Delete template"
    return 0
  fi

  local command="$1"
  
  case "$command" in
    "new")
      if [[ $# -eq 1 ]]; then
        # Create custom template
        _q_create_template "custom"
      else
        # Create template for specific service
        local service="$2"
        if [[ "$service" =~ ^(task|journal|time|todo|ledger)$ ]]; then
          _q_create_template "$service"
        else
          echo "Error: Invalid service '$service'. Valid services: task, journal, time, todo, ledger" >&2
          return 1
        fi
      fi
      ;;
    "list")
      _q_list_all_templates
      ;;
    "edit")
      if [[ $# -lt 2 ]]; then
        echo "Error: Please specify a template to edit." >&2
        return 1
      fi
      _q_edit_template "$2"
      ;;
    "delete")
      if [[ $# -lt 2 ]]; then
        echo "Error: Please specify a template to delete." >&2
        return 1
      fi
      _q_delete_template "$2"
      ;;
    "task"|"journal"|"time"|"todo"|"ledger")
      if [[ $# -eq 1 ]]; then
        # List templates for this service
        _q_list_service_templates "$command"
      else
        # Use specific template
        _q_use_template "$command" "$2"
      fi
      ;;
    *)
      echo "Error: Unknown command '$command'" >&2
      echo "Run 'q' for help."
      return 1
      ;;
  esac
}

# Helper function to create a new template
_q_create_template() {
  local service="$1"
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates"
  
  echo "Creating new template for service: $service"
  echo "=========================================="
  
  # Get template name
  read -p "Template filename (without .json): " template_name
  if [[ -z "$template_name" ]]; then
    echo "Error: Template name cannot be empty." >&2
    return 1
  fi
  
  # Get display name (optional)
  read -p "Display name (press Enter for '$template_name'): " display_name
  if [[ -z "$display_name" ]]; then
    display_name="$template_name"
  fi
  
  # Get description
  read -p "Description: " description
  
  # Collect questions
  echo ""
  echo "Enter questions (press Enter with empty input to finish):"
  local questions=()
  local question_num=1
  
  while true; do
    read -p "Question $question_num: " question_text
    if [[ -z "$question_text" ]]; then
      break
    fi
    questions+=("$question_text")
    ((question_num++))
  done
  
  if [[ ${#questions[@]} -eq 0 ]]; then
    echo "Error: At least one question is required." >&2
    return 1
  fi
  
  # Create template file
  local template_file="$templates_dir/$service/${template_name}.json"
  _q_write_template_file "$template_file" "$display_name" "$description" "$service" "${questions[@]}"
  
  echo "Template created: $template_file"
  echo "Use with: q $service $template_name"
}

# Helper function to write template JSON file
_q_write_template_file() {
  local template_file="$1"
  local display_name="$2"
  local description="$3"
  local service="$4"
  shift 4
  local questions=("$@")
  
  cat > "$template_file" << EOF
{
  "name": "$display_name",
  "description": "$description",
  "service": "$service",
  "questions": [
EOF
  
  for i in "${!questions[@]}"; do
    local comma=""
    if [[ $i -lt $((${#questions[@]} - 1)) ]]; then
      comma=","
    fi
    cat >> "$template_file" << EOF
    {
      "id": "q$((i+1))",
      "text": "${questions[i]}",
      "type": "text",
      "required": true
    }$comma
EOF
  done
  
  cat >> "$template_file" << EOF
  ],
  "output_format": {
    "title": "$display_name - {date}",
    "description": "Generated from template",
    "tags": ["$service", "template"]
  }
}
EOF
}

# Helper function to list templates for a service
_q_list_service_templates() {
  local service="$1"
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates/$service"
  
  echo "Templates for $service:"
  echo "======================"
  
  if [[ ! -d "$templates_dir" ]]; then
    echo "No templates found for $service"
    return 0
  fi
  
  local found_templates=0
  for template_file in "$templates_dir"/*.json; do
    if [[ -f "$template_file" ]]; then
      local template_name=$(basename "$template_file" .json)
      echo "  $template_name"
      found_templates=1
    fi
  done
  
  if [[ $found_templates -eq 0 ]]; then
    echo "No templates found for $service"
  fi
}

# Helper function to list all templates
_q_list_all_templates() {
  local templates_dir="$WORKWARRIOR_BASE/services/questions/templates"
  
  echo "All Templates:"
  echo "=============="
  
  for service in task journal time todo ledger custom; do
    local service_dir="$templates_dir/$service"
    if [[ -d "$service_dir" ]]; then
      local has_templates=0
      for template_file in "$service_dir"/*.json; do
        if [[ -f "$template_file" ]]; then
          if [[ $has_templates -eq 0 ]]; then
            echo "$service:"
            has_templates=1
          fi
          local template_name=$(basename "$template_file" .json)
          echo "  $template_name"
        fi
      done
    fi
  done
}

# Helper function to use a template
_q_use_template() {
  local service="$1"
  local template_name="$2"
  local template_file="$WORKWARRIOR_BASE/services/questions/templates/$service/${template_name}.json"
  
  if [[ ! -f "$template_file" ]]; then
    echo "Error: Template '$template_name' not found for service '$service'" >&2
    return 1
  fi
  
  # Check if python3 is available for JSON parsing
  if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required for JSON parsing" >&2
    return 1
  fi
  
  # Parse template and prompt for answers
  local answers_file=$(mktemp)
  if _q_prompt_questions "$template_file" "$answers_file"; then
    # Process answers and call appropriate handler
    _q_process_answers "$service" "$template_file" "$answers_file"
    local result=$?
    rm -f "$answers_file"
    return $result
  else
    rm -f "$answers_file"
    return 1
  fi
}

# Helper function to prompt for questions from template
_q_prompt_questions() {
  local template_file="$1"
  local answers_file="$2"
  
  # Extract template info using python3
  local template_info=$(python3 -c "
import json, sys
try:
    with open('$template_file', 'r') as f:
        template = json.load(f)
    print(template['name'])
    print(template['description'])
    print(len(template['questions']))
    for i, q in enumerate(template['questions']):
        print(f\"{i}|{q['id']}|{q['text']}|{q.get('required', True)}\")
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")
  
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to parse template JSON" >&2
    return 1
  fi
  
  # Parse template info
  local lines=($template_info)
  local template_name="${lines[0]}"
  local template_desc="${lines[1]}"
  local question_count="${lines[2]}"
  
  echo "Template: $template_name"
  echo "Description: $template_desc"
  echo "=========================================="
  echo ""
  
  # Initialize answers file
  echo "{" > "$answers_file"
  echo "  \"template\": \"$template_file\"," >> "$answers_file"
  echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$answers_file"
  echo "  \"answers\": {" >> "$answers_file"
  
  local answer_count=0
  
  # Process each question
  for ((i=3; i<$((question_count+3)); i++)); do
    local question_line="${lines[i]}"
    IFS='|' read -r q_index q_id q_text q_required <<< "$question_line"
    
    # Prompt for answer
    local answer=""
    while true; do
      read -p "$q_text: " answer
      
      # Check if required field is empty
      if [[ "$q_required" == "True" && -z "$answer" ]]; then
        echo "This field is required. Please provide an answer."
        continue
      fi
      
      break
    done
    
    # Add comma if not first answer
    if [[ $answer_count -gt 0 ]]; then
      echo "," >> "$answers_file"
    fi
    
    # Escape quotes in answer for JSON
    local escaped_answer=$(echo "$answer" | sed 's/"/\\"/g')
    echo -n "    \"$q_id\": \"$escaped_answer\"" >> "$answers_file"
    
    ((answer_count++))
  done
  
  # Close answers JSON
  echo "" >> "$answers_file"
  echo "  }" >> "$answers_file"
  echo "}" >> "$answers_file"
  
  echo ""
  echo "Answers collected successfully."
  return 0
}

# Helper function to process answers and call service handler
_q_process_answers() {
  local service="$1"
  local template_file="$2"
  local answers_file="$3"
  local handlers_dir="$WORKWARRIOR_BASE/services/questions/handlers"
  local handler_script="$handlers_dir/${service}_handler.sh"
  
  echo "Processing answers for service: $service"
  
  # Check if handler exists
  if [[ ! -f "$handler_script" ]]; then
    echo "Warning: Handler script not found: $handler_script"
    echo "Creating basic handler template..."
    _q_create_handler_template "$service" "$handler_script"
  fi
  
  # Make handler executable
  chmod +x "$handler_script"
  
  # Call the handler with template and answers
  if "$handler_script" "$template_file" "$answers_file"; then
    echo "✓ Successfully processed answers with $service handler"
    return 0
  else
    echo "✗ Error processing answers with $service handler" >&2
    return 1
  fi
}

# Helper function to create a basic handler template
_q_create_handler_template() {
  local service="$1"
  local handler_script="$2"
  
  cat > "$handler_script" << 'EOF'
#!/bin/bash
# Auto-generated handler template for SERVICE_NAME service

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

echo "Handler: SERVICE_NAME"
echo "Template: $template_file"
echo "Answers: $answers_file"
echo ""

# Extract answers using python3
python3 -c "
import json
with open('$answers_file', 'r') as f:
    data = json.load(f)
    
print('Collected Answers:')
print('==================')
for key, value in data['answers'].items():
    print(f'{key}: {value}')

print('')
print('TODO: Implement SERVICE_NAME-specific processing')
print('This handler should format the answers and integrate with SERVICE_NAME')
"

# TODO: Add SERVICE_NAME-specific integration here
# For example:
# - Format answers into task description
# - Create Workwarrior task with appropriate tags
# - Add to journal with proper formatting
# - etc.

echo "Handler completed successfully"
EOF

  # Replace SERVICE_NAME placeholder
  sed -i "s/SERVICE_NAME/$service/g" "$handler_script"
  
  echo "Created handler template: $handler_script"
  echo "You can customize this handler for $service-specific integration."
}

# Placeholder helper functions for future implementation
_q_edit_template() {
  local template_name="$1"
  echo "Edit template functionality not yet implemented: $template_name"
}

_q_delete_template() {
  local template_name="$1"
  echo "Delete template functionality not yet implemented: $template_name"
}

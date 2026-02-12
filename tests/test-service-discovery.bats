#!/usr/bin/env bats
# Property-Based Tests for Service Discovery Functions
# Feature: workwarrior-profiles-and-services
# Property 27: Profile-Specific Service Override
# Property 28: Service Discovery

setup() {
  # Set up test environment
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export SERVICES_DIR="$TEST_WW_BASE/services"
  
  # Create test directories
  mkdir -p "$PROFILES_DIR"
  mkdir -p "$SERVICES_DIR"
  
  # Source the library
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
}

teardown() {
  # Clean up test environment
  if [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
  
  # Unset environment variables
  unset WORKWARRIOR_BASE
}

# ============================================================================
# Helper Functions
# ============================================================================

# Generate random alphanumeric string
random_string() {
  local length="${1:-10}"
  LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Create a test service file
create_test_service() {
  local category="$1"
  local service_name="$2"
  local location="${3:-global}"  # global or profile
  
  local service_dir
  if [[ "$location" == "profile" ]]; then
    service_dir="$WORKWARRIOR_BASE/services/$category"
  else
    service_dir="$SERVICES_DIR/$category"
  fi
  
  mkdir -p "$service_dir"
  local service_path="$service_dir/$service_name"
  
  echo "#!/usr/bin/env bash" > "$service_path"
  echo "echo 'Test service: $service_name'" >> "$service_path"
  chmod +x "$service_path"
  
  echo "$service_path"
}

# ============================================================================
# Property 28: Service Discovery Tests
# ============================================================================

@test "Property 28: discover_services finds global services" {
  # Feature: workwarrior-profiles-and-services, Property 28: Service Discovery
  
  # Create test services in different categories
  local categories=("profile" "questions" "scripts" "export" "diagnostic")
  
  for category in "${categories[@]}"; do
    # Create 3 services per category
    create_test_service "$category" "service1.sh" "global"
    create_test_service "$category" "service2.sh" "global"
    create_test_service "$category" "service3.sh" "global"
    
    # Discover services
    local services
    services=$(discover_services "$category")
    
    # Verify all services are found
    [[ "$services" == *"service1.sh"* ]]
    [[ "$services" == *"service2.sh"* ]]
    [[ "$services" == *"service3.sh"* ]]
    
    # Verify services are sorted
    local sorted_services
    sorted_services=$(echo "$services" | sort)
    [[ "$services" == "$sorted_services" ]]
  done
}

@test "Property 28: discover_services finds executable scripts" {
  # Feature: workwarrior-profiles-and-services, Property 28: Service Discovery
  
  local category="scripts"
  mkdir -p "$SERVICES_DIR/$category"
  
  # Create executable script
  local exec_script="$SERVICES_DIR/$category/executable.sh"
  echo "#!/usr/bin/env bash" > "$exec_script"
  chmod +x "$exec_script"
  
  # Create non-executable script (should still be found if .sh extension)
  local nonexec_script="$SERVICES_DIR/$category/nonexec.sh"
  echo "#!/usr/bin/env bash" > "$nonexec_script"
  chmod -x "$nonexec_script"
  
  # Create non-script file (should not be found)
  local text_file="$SERVICES_DIR/$category/readme.txt"
  echo "This is a text file" > "$text_file"
  
  # Discover services
  local services
  services=$(discover_services "$category")
  
  # Verify executable script is found
  [[ "$services" == *"executable.sh"* ]]
  
  # Verify .sh file is found even if not executable
  [[ "$services" == *"nonexec.sh"* ]]
  
  # Verify non-script file is not found
  [[ "$services" != *"readme.txt"* ]]
}

@test "Property 28: discover_services handles empty categories" {
  # Feature: workwarrior-profiles-and-services, Property 28: Service Discovery
  
  local category="empty-category"
  mkdir -p "$SERVICES_DIR/$category"
  
  # Discover services in empty category
  local services
  services=$(discover_services "$category")
  
  # Should return empty (no error)
  [[ -z "$services" ]]
}

@test "Property 28: discover_services handles non-existent categories" {
  # Feature: workwarrior-profiles-and-services, Property 28: Service Discovery
  
  local category="nonexistent-category"
  
  # Discover services in non-existent category
  local services
  services=$(discover_services "$category")
  
  # Should return empty (no error)
  [[ -z "$services" ]]
}

@test "Property 28: discover_services with random service names" {
  # Feature: workwarrior-profiles-and-services, Property 28: Service Discovery
  
  local category="test-category"
  local service_names=()
  
  # Create 10 services with random names
  for i in {1..10}; do
    local service_name="service-$(random_string 8).sh"
    service_names+=( "$service_name" )
    create_test_service "$category" "$service_name" "global"
  done
  
  # Discover services
  local services
  services=$(discover_services "$category")
  
  # Verify all services are found
  for service_name in "${service_names[@]}"; do
    [[ "$services" == *"$service_name"* ]]
  done
  
  # Verify count matches
  local found_count
  found_count=$(echo "$services" | wc -l)
  [[ "$found_count" -eq 10 ]]
}

# ============================================================================
# Property 27: Profile-Specific Service Override Tests
# ============================================================================

@test "Property 27: Profile-specific service overrides global service" {
  # Feature: workwarrior-profiles-and-services, Property 27: Profile-Specific Service Override
  
  local profile_name="test-profile"
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create profile
  mkdir -p "$PROFILES_DIR/$profile_name"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_name"
  
  # Create global service
  local global_service
  global_service=$(create_test_service "$category" "$service_name" "global")
  echo "echo 'GLOBAL'" >> "$global_service"
  
  # Create profile-specific service with same name
  local profile_service
  profile_service=$(create_test_service "$category" "$service_name" "profile")
  echo "echo 'PROFILE'" >> "$profile_service"
  
  # Get service path - should return profile-specific version
  local service_path
  service_path=$(get_service_path "$category" "$service_name")
  
  # Verify it's the profile-specific version
  [[ "$service_path" == "$profile_service" ]]
  [[ "$service_path" != "$global_service" ]]
  
  # Verify content is from profile version
  local output
  output=$(bash "$service_path")
  [[ "$output" == *"PROFILE"* ]]
  [[ "$output" != *"GLOBAL"* ]]
}

@test "Property 27: discover_services prioritizes profile-specific services" {
  # Feature: workwarrior-profiles-and-services, Property 27: Profile-Specific Service Override
  
  local profile_name="test-profile"
  local category="scripts"
  
  # Create profile
  mkdir -p "$PROFILES_DIR/$profile_name"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_name"
  
  # Create global services
  create_test_service "$category" "service1.sh" "global"
  create_test_service "$category" "service2.sh" "global"
  create_test_service "$category" "service3.sh" "global"
  
  # Create profile-specific service with same name as service2
  create_test_service "$category" "service2.sh" "profile"
  
  # Create additional profile-specific service
  create_test_service "$category" "service4.sh" "profile"
  
  # Discover services
  local services
  services=$(discover_services "$category")
  
  # Should find all unique service names (no duplicates)
  local service_count
  service_count=$(echo "$services" | wc -l)
  [[ "$service_count" -eq 4 ]]
  
  # Verify all services are listed
  [[ "$services" == *"service1.sh"* ]]
  [[ "$services" == *"service2.sh"* ]]
  [[ "$services" == *"service3.sh"* ]]
  [[ "$services" == *"service4.sh"* ]]
}

@test "Property 27: No profile active uses only global services" {
  # Feature: workwarrior-profiles-and-services, Property 27: Profile-Specific Service Override
  
  local category="scripts"
  local service_name="test-service.sh"
  
  # Ensure no profile is active
  unset WORKWARRIOR_BASE
  
  # Create global service
  local global_service
  global_service=$(create_test_service "$category" "$service_name" "global")
  
  # Get service path
  local service_path
  service_path=$(get_service_path "$category" "$service_name")
  
  # Should return global service
  [[ "$service_path" == "$global_service" ]]
}

@test "Property 27: Multiple profiles have independent service overrides" {
  # Feature: workwarrior-profiles-and-services, Property 27: Profile-Specific Service Override
  
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create global service
  local global_service
  global_service=$(create_test_service "$category" "$service_name" "global")
  echo "echo 'GLOBAL'" >> "$global_service"
  
  # Create profile A
  local profile_a="profile-a"
  mkdir -p "$PROFILES_DIR/$profile_a"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_a"
  local service_a
  service_a=$(create_test_service "$category" "$service_name" "profile")
  echo "echo 'PROFILE_A'" >> "$service_a"
  
  # Get service path for profile A
  local path_a
  path_a=$(get_service_path "$category" "$service_name")
  [[ "$path_a" == "$service_a" ]]
  
  # Create profile B
  local profile_b="profile-b"
  mkdir -p "$PROFILES_DIR/$profile_b"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_b"
  local service_b
  service_b=$(create_test_service "$category" "$service_name" "profile")
  echo "echo 'PROFILE_B'" >> "$service_b"
  
  # Get service path for profile B
  local path_b
  path_b=$(get_service_path "$category" "$service_name")
  [[ "$path_b" == "$service_b" ]]
  
  # Verify they're different
  [[ "$path_a" != "$path_b" ]]
}

# ============================================================================
# get_service_path Tests
# ============================================================================

@test "get_service_path returns correct path for global service" {
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create global service
  local expected_path
  expected_path=$(create_test_service "$category" "$service_name" "global")
  
  # Get service path
  local actual_path
  actual_path=$(get_service_path "$category" "$service_name")
  
  # Verify path matches
  [[ "$actual_path" == "$expected_path" ]]
}

@test "get_service_path returns empty for non-existent service" {
  local category="scripts"
  local service_name="nonexistent.sh"

  # Try to get non-existent service
  # Use run to capture output and status without failing the test
  run get_service_path "$category" "$service_name"

  # Should return non-zero exit code and empty output
  [[ "$status" -ne 0 ]]
  [[ -z "$output" ]]
}

@test "get_service_path requires both category and service name" {
  # Test with missing category
  run get_service_path "" "service.sh"
  [[ "$status" -ne 0 ]]
  
  # Test with missing service name
  run get_service_path "scripts" ""
  [[ "$status" -ne 0 ]]
}

@test "get_service_path with random valid inputs" {
  # Create 10 random services and verify paths
  for i in {1..10}; do
    local category="cat-$(random_string 5)"
    local service_name="svc-$(random_string 8).sh"
    
    # Create service
    local expected_path
    expected_path=$(create_test_service "$category" "$service_name" "global")
    
    # Get service path
    local actual_path
    actual_path=$(get_service_path "$category" "$service_name")
    
    # Verify path matches
    [[ "$actual_path" == "$expected_path" ]]
  done
}

# ============================================================================
# service_exists Tests
# ============================================================================

@test "service_exists returns true for existing global service" {
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create global service
  create_test_service "$category" "$service_name" "global"
  
  # Check if service exists
  run service_exists "$category" "$service_name"
  [[ "$status" -eq 0 ]]
}

@test "service_exists returns false for non-existent service" {
  local category="scripts"
  local service_name="nonexistent.sh"
  
  # Check if service exists
  run service_exists "$category" "$service_name"
  [[ "$status" -ne 0 ]]
}

@test "service_exists returns true for profile-specific service" {
  local profile_name="test-profile"
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create profile
  mkdir -p "$PROFILES_DIR/$profile_name"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_name"
  
  # Create profile-specific service
  create_test_service "$category" "$service_name" "profile"
  
  # Check if service exists
  run service_exists "$category" "$service_name"
  [[ "$status" -eq 0 ]]
}

@test "service_exists prioritizes profile-specific over global" {
  local profile_name="test-profile"
  local category="scripts"
  local service_name="test-service.sh"
  
  # Create profile
  mkdir -p "$PROFILES_DIR/$profile_name"
  export WORKWARRIOR_BASE="$PROFILES_DIR/$profile_name"
  
  # Create both global and profile-specific service
  create_test_service "$category" "$service_name" "global"
  create_test_service "$category" "$service_name" "profile"
  
  # Check if service exists (should find profile version first)
  run service_exists "$category" "$service_name"
  [[ "$status" -eq 0 ]]
}

@test "service_exists with random valid inputs" {
  # Create and verify 10 random services
  for i in {1..10}; do
    local category="cat-$(random_string 5)"
    local service_name="svc-$(random_string 8).sh"
    
    # Service should not exist initially
    run service_exists "$category" "$service_name"
    [[ "$status" -ne 0 ]]
    
    # Create service
    create_test_service "$category" "$service_name" "global"
    
    # Service should now exist
    run service_exists "$category" "$service_name"
    [[ "$status" -eq 0 ]]
  done
}

@test "service_exists handles missing parameters" {
  # Test with missing category
  run service_exists "" "service.sh"
  [[ "$status" -ne 0 ]]
  
  # Test with missing service name
  run service_exists "scripts" ""
  [[ "$status" -ne 0 ]]
  
  # Test with both missing
  run service_exists "" ""
  [[ "$status" -ne 0 ]]
}

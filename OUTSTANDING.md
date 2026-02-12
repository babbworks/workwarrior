# Outstanding Features and Improvements

This document tracks features that are designed but not yet implemented, as well as improvements needed for the Workwarrior project.

## High Priority

### 1. Journal Management Commands
**Status:** Designed but not implemented  
**Spec Reference:** `.kiro/specs/workwarrior-profiles-and-services/requirements.md` - Requirements 8.16, 8.17  
**Design Reference:** `.kiro/specs/workwarrior-profiles-and-services/design.md` - Property 23

**Description:**  
Add dedicated commands for managing journals within profiles.

**Needed Commands:**
```bash
ww journal add <profile-name> <journal-name>     # Add new journal to profile
ww journal list <profile-name>                   # List all journals in profile
ww journal remove <profile-name> <journal-name>  # Remove journal from profile
ww journal rename <profile-name> <old> <new>     # Rename a journal
```

**Implementation Notes:**
- Should update jrnl.yaml configuration
- Should create journal file with welcome entry
- Should validate journal names (no duplicates)
- Should handle file paths properly
- Consider adding shell aliases for new journals

**Workaround:**
Users can use the journals configuration service:
- `j custom` - Quick access from j command
- `custom journals` - Direct custom command
- `ww custom journals` - Full ww command

This provides a guided interface for adding journals, though dedicated commands would be more streamlined.

---

### 2. Shell Configuration Migration Script
**Status:** Spec complete, not implemented  
**Spec Location:** `.kiro/specs/shell-config-migration/`

**Description:**  
Automated script to migrate shell configuration when Workwarrior is relocated (e.g., from `/mp/ww/` to `/mp/workwarrior/`).

**Features Needed:**
- Detect old Workwarrior path references in shell configs
- Create backups before modification
- Update all aliases and paths to new location
- Support bash, zsh, and other shells
- Rollback capability
- Idempotent operation

**Current Workaround:**
Manual editing of `.bashrc`, `.zshrc`, etc., or running `scripts/clean-bashrc.sh` and reinstalling.

---

## Medium Priority

### 3. Ledger Management Commands
**Status:** Partially implemented (creation only)

**Description:**  
Similar to journal management, add commands for managing multiple ledgers within a profile.

**Needed Commands:**
```bash
ww ledger add <profile-name> <ledger-name>       # Add new ledger to profile
ww ledger list <profile-name>                    # List all ledgers in profile
ww ledger remove <profile-name> <ledger-name>    # Remove ledger from profile
```

**Current State:**
- Default ledger created during profile creation
- No command to add additional ledgers
- Users must manually edit `ledgers.yaml`

---

### 4. Profile Export/Import
**Status:** Backup exists, but no import

**Description:**  
While `ww profile backup` creates archives, there's no corresponding import/restore command.

**Needed Commands:**
```bash
ww profile import <archive-file>                 # Import profile from backup
ww profile restore <profile-name> <archive-file> # Restore profile from backup
```

**Use Cases:**
- Migrate profiles between machines
- Restore from backup after data loss
- Share profile templates with team

---

### 5. Service Discovery and Help
**Status:** Services exist but no unified discovery

**Description:**  
Add commands to discover and get help for available services.

**Needed Commands:**
```bash
ww service list                                  # List all available services
ww service info <service-name>                   # Show service details
ww service help <service-name>                   # Show service usage
```

**Current State:**
- Services are in `services/` directory
- No programmatic way to list or discover them
- README files exist but not accessible via CLI

---

## Low Priority

### 6. Profile Templates
**Status:** Not designed

**Description:**  
Allow users to create profile templates for quick setup of common configurations.

**Potential Features:**
- Save current profile as template
- Create profile from template
- Share templates
- Template marketplace/repository

---

### 7. Dependency Version Management
**Status:** Basic check exists

**Description:**  
Track and manage versions of external dependencies (TaskWarrior, TimeWarrior, etc.).

**Potential Features:**
- Check for updates
- Warn about incompatible versions
- Suggest upgrade paths
- Version compatibility matrix

---

### 8. Profile Switching Optimization
**Status:** Works but could be faster

**Description:**  
Optimize profile switching for faster activation.

**Ideas:**
- Cache environment variables
- Lazy-load configurations
- Pre-compile shell functions
- Background profile validation

---

## Documentation Needs

### 9. User Guide
**Status:** Basic README exists

**Needed:**
- Comprehensive user guide
- Tutorial for beginners
- Advanced usage patterns
- Troubleshooting guide
- FAQ section

---

### 10. Service Development Guide
**Status:** Partial documentation in `services/README.md`

**Needed:**
- Step-by-step service creation tutorial
- Best practices guide
- Testing guidelines
- Example services with explanations
- API reference for shared utilities

---

## Testing Needs

### 11. Integration Tests
**Status:** Property tests designed, not all implemented

**Needed:**
- End-to-end workflow tests
- Multi-profile interaction tests
- Shell integration tests
- Service interaction tests

---

### 12. Automated Testing in CI/CD
**Status:** No CI/CD pipeline

**Needed:**
- GitHub Actions or similar
- Automated test runs on PR
- Multi-OS testing (Linux, macOS)
- Multi-shell testing (bash, zsh)

---

## Notes

- Items marked "Designed but not implemented" have complete specifications in `.kiro/specs/`
- Items marked "Not designed" need specification work before implementation
- Priority levels are suggestions and can be adjusted based on user needs
- This document should be updated as features are implemented or priorities change

---

**Last Updated:** 2024-02-11  
**Maintained By:** Workwarrior Development Team

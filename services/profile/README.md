# Service: profile

Profile services manage creation, configuration, and lifecycle tasks for Workwarrior profiles.

## Key Files

- `create-ww-profile.sh` - Profile creation workflow
- `manage-profiles.sh` - Profile management (list, info, delete, backup)
- `on-modify.timewarrior` - TaskWarrior hook for TimeWarrior integration

## Subdirectories

- `defaults/` - Default configuration templates
- `subservices/` - Specialized profile operations
- `taskrc/` - TaskWarrior configuration templates

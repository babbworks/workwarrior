# Projects Service

Cross-cutting project views that group resources across all four functions.

## Data Model

A project is defined in `config/projects.yaml` and links resources by convention:

- **Tasks**: TaskWarrior's `project:<name>` field
- **Journals**: entries prefixed with `[project:<name>]`
- **Ledgers**: account hierarchy `expenses:<project-name>:*` or similar
- **Times**: timew tags matching the project name

## Config Format

```yaml
projects:
  my-project:
    description: Project description
```

## Browser UI

The Projects panel shows all defined projects with their description and
usage hints for linking resources.

## CLI

Projects are managed via the browser UI or by editing `config/projects.yaml`
directly. Future: `ww project create/list/show/delete` commands.

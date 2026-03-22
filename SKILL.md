---
name: rdm
description: "Redmine CLI tool. Use when the user wants to interact with Redmine: list/create/update issues, log time, manage projects, search, check status, or any Redmine operation. Trigger on: 'rdm', 'redmine', 'issues', 'time log', 'create issue', 'show issue', 'list projects', etc."
---

# rdm — Claude Code Skill

This is a [Claude Code](https://claude.ai/code) skill for interacting with Redmine via the `rdm` CLI.

## When to use

- User asks to list, create, update, or delete Redmine issues
- User asks to log time or check time entries
- User asks about projects, versions, memberships, users, groups
- User mentions Redmine operations (search, status, queries)
- User says "rdm" or invokes `/rdm`

## Setup

Install the gem, then authenticate:

```bash
rdm login
```

If `~/.rdm/config.yml` doesn't exist, it will be created on first run.

## Command Reference

### Authentication & Status
```bash
rdm login                              # Interactive login (URL + API key)
rdm login --url URL --api-key KEY      # Non-interactive
rdm login --profile staging --url URL --api-key KEY  # Named profile
rdm status                             # Show connection info
rdm logout                             # Clear credentials
rdm me                                 # Current user info
```

### Issues
```bash
rdm issues list                                     # List open issues
rdm issues list --project-id ID --status open       # Filter by project/status
rdm issues list --assigned-to-id me --sort updated_on:desc
rdm issues show 123                                 # Show issue details
rdm issues show 123 --include journals,relations    # With history
rdm issues create --project-id ID --tracker-id N --subject "Title"
rdm issues update 123 --status-id 3 --notes "Done"
rdm issues delete 123 --confirm
rdm issues copy 123 --project-id other-project --link
rdm issues move 123 --project-id other-project
rdm issues journals 123                             # Issue history
rdm issues relations 123                            # Issue relations
rdm issues add-watcher --issue-id 123 --user-id 5
rdm issues add-relation --issue-id 123 --issue-to-id 456 --type blocks
```

### Projects
```bash
rdm projects list
rdm projects list --status active --include trackers,enabled_modules
rdm projects show myproject
rdm projects create --name "New Project" --identifier new-proj
rdm projects update myproject --description "Updated"
rdm projects delete myproject --confirm
```

### Time Entries
```bash
rdm time list --project-id ID --from 2025-01-01 --to 2025-01-31
rdm time list --user-id me
rdm time show 456
rdm log --hours 2 --activity-id 9 --issue-id 123 --comments "Work done"
rdm time update 456 --hours 3
rdm time delete 456
rdm time bulk-log --file entries.json
```

### Users
```bash
rdm users list
rdm users list --status 1 --name "john"
rdm users show 5 --include groups,memberships
rdm users show me
rdm users create --login jdoe --firstname John --lastname Doe --mail j@example.com
```

### Versions
```bash
rdm versions list --project-id myproject
rdm versions show 10
rdm versions create --project-id myproject --name "v2.0" --status open --due-date 2025-06-01
rdm versions update 10 --status closed
```

### Groups & Memberships
```bash
rdm groups list
rdm groups show 3 --include users
rdm groups create --name "Developers" --user-ids 1,2,3
rdm memberships list --project-id myproject
rdm memberships create --project-id myproject --user-id 5 --role-ids 3,4
```

### Queries & Custom Fields
```bash
rdm queries list --project-id myproject
rdm custom-fields list
```
Note: Create/update/delete for queries and custom fields require the Extended API Redmine plugin.

### Reference Data
```bash
rdm trackers
rdm statuses
rdm priorities
rdm activities
rdm roles
rdm search "keyword" --project-id myproject
```

### Common Options
```bash
--format json|table|csv    # Output format (default: table for TTY, json for pipe)
--profile NAME             # Use a specific config profile
--debug                    # Show HTTP request/response details
--limit N                  # Pagination limit
--offset N                 # Pagination offset
```

## Output Handling

- **Table format** (default in TTY): human-readable columns
- **JSON format** (default when piped): raw Redmine API response, pipe-friendly
- **CSV format**: for spreadsheet export

To always get JSON: `rdm issues list --format json`
To pipe and process: `rdm issues list --format json | jq '.[] | .id'`

## Environment Variables

Override config without login:
```bash
RDM_URL=https://redmine.example.com RDM_API_KEY=key rdm issues list
```

Available: `RDM_URL`, `RDM_API_KEY`, `RDM_PROFILE`, `RDM_CONFIG`, `RDM_FORMAT`, `RDM_TIMEOUT`, `RDM_DEBUG`

## Error Handling

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | General error (connection, server, timeout) |
| 2 | Authentication/authorization error |
| 3 | Resource not found |
| 4 | Validation error |

## Tips for Claude

- When the user asks to "check issue 123", run `rdm issues show 123`
- When the user asks to "log 2 hours on issue 123", run `rdm log --hours 2 --activity-id 9 --issue-id 123`
- For bulk operations, prefer `--format json` and parse with jq
- Use `rdm status` to verify connectivity before other commands
- Use `rdm me` to get the current user's ID for filtering
- Destructive commands (delete) always need `--confirm`
- If auth fails, suggest `rdm login`

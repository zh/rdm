# rdm — Redmine CLI

A fast, scriptable command-line interface for [Redmine](https://www.redmine.org/). Manage issues, projects, time entries, users, and more — without leaving your terminal.

## Features

- **48+ commands** covering issues, projects, time tracking, users, versions, memberships, groups, queries, custom fields, and reference data
- **Multiple output formats** — table (human-readable), JSON (pipe-friendly), CSV (spreadsheets)
- **Multi-profile support** — switch between Redmine instances with `--profile`
- **CI/CD ready** — non-interactive login, environment variable overrides, meaningful exit codes
- **Secure by default** — HTTPS enforced, credentials stored with restricted file permissions, API keys masked in all output

## Installation

### From source

```bash
git clone https://github.com/agileware/rdm.git
cd rdm
bundle install
```

### As a gem

```bash
gem build rdm.gemspec
gem install rdm-0.1.0.gem
```

### Requirements

- Ruby >= 3.1.0
- A Redmine instance with REST API enabled (Administration > Settings > API)

## Quick Start

```bash
# 1. Authenticate (interactive — prompts for URL and API key)
rdm login

# 2. Verify connection
rdm status

# 3. Start using it
rdm issues list
rdm issues show 42
rdm me
```

## Usage

### Authentication

```bash
# Interactive
rdm login

# Non-interactive
rdm login --url https://redmine.example.com --api-key YOUR_API_KEY

# CI/CD (read key from stdin to avoid shell history)
echo "$REDMINE_API_KEY" | rdm login --url https://redmine.example.com --api-key-stdin

# Environment variables (no login needed)
export RDM_URL=https://redmine.example.com
export RDM_API_KEY=your_key
rdm issues list
```

Find your API key at **My account** (`/my/account`) in Redmine.

### Multiple Profiles

```bash
rdm login --profile production --url https://prod.redmine.com --api-key KEY1
rdm login --profile staging    --url https://stg.redmine.com  --api-key KEY2

rdm issues list --profile staging
```

### Issues

```bash
rdm issues list                                        # All open issues
rdm issues list --project-id myproject --status open   # Filter by project
rdm issues list --assigned-to-id me --sort updated_on:desc
rdm issues show 123                                    # Issue details
rdm issues show 123 --include journals,relations       # With history

rdm issues create --project-id myproject --tracker-id 1 --subject "Fix the bug"
rdm issues update 123 --status-id 3 --notes "Fixed in abc123"
rdm issues delete 123 --confirm

rdm issues copy 123 --project-id other-project --link
rdm issues move 123 --project-id other-project
rdm issues journals 123                                # History/comments
rdm issues relations 123
rdm issues add-watcher --issue-id 123 --user-id 5
rdm issues add-relation --issue-id 123 --issue-to-id 456 --type blocks
```

### Projects

```bash
rdm projects list
rdm projects show myproject
rdm projects create --name "New Project" --identifier new-proj
rdm projects update myproject --description "Updated description"
rdm projects delete myproject --confirm
```

### Time Tracking

```bash
rdm time list --project-id myproject --from 2025-01-01 --to 2025-01-31
rdm time log --hours 2.5 --activity-id 9 --issue-id 123 --comments "Investigation"
rdm time update 456 --hours 3
rdm time delete 456

# Bulk import from JSON file
rdm time bulk-log --file entries.json
```

### Users

```bash
rdm users list
rdm users show me                     # Current user
rdm users show 5 --include groups,memberships
rdm users create --login jdoe --firstname John --lastname Doe --mail j@example.com
```

### Versions, Memberships & Groups

```bash
rdm versions list --project-id myproject
rdm versions create --project-id myproject --name "v2.0" --due-date 2025-06-01

rdm memberships list --project-id myproject
rdm memberships create --project-id myproject --user-id 5 --role-ids 3,4

rdm groups list
rdm groups create --name "Developers" --user-ids 1,2,3
```

### Queries & Custom Fields

> Requires the [Extended API](https://github.com/zh/redmine_extended_api) Redmine plugin for create/update/delete. List works without it.

```bash
rdm queries list --project-id myproject
rdm custom-fields list
```

### Reference Data

```bash
rdm trackers       # List trackers
rdm statuses       # List issue statuses
rdm priorities     # List priorities
rdm activities     # List time entry activities
rdm roles          # List roles
rdm search "bug"   # Full-text search
```

### Shortcuts

| Shortcut | Expands to |
|----------|------------|
| `rdm i list` | `rdm issues list` |
| `rdm p list` | `rdm projects list` |
| `rdm t list` | `rdm time list` |
| `rdm u list` | `rdm users list` |
| `rdm me` | `rdm users show me` |
| `rdm log` | `rdm time log` |

## Output Formats

Output format is auto-detected: **table** when running in a terminal, **JSON** when piped.

```bash
# Explicit format
rdm issues list --format json
rdm issues list --format table
rdm issues list --format csv

# Pipe JSON to jq
rdm issues list --format json | jq '.[].subject'
```

## Configuration

Config is stored at `~/.rdm/config.yml`:

```yaml
default_profile: default
profiles:
  default:
    url: https://redmine.example.com
    api_key: a1b2c3d4e5f6
    user_id: 5
    user_login: admin
    user_name: Admin User
settings:
  format: table
  timeout: 30
  page_size: 25
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `RDM_URL` | Redmine base URL |
| `RDM_API_KEY` | API key |
| `RDM_PROFILE` | Active profile name |
| `RDM_CONFIG` | Config file path (default: `~/.rdm/config.yml`) |
| `RDM_FORMAT` | Default output format |
| `RDM_TIMEOUT` | HTTP timeout in seconds |
| `RDM_DEBUG` | Enable debug output (`1`) |

Precedence: CLI flags > environment variables > config file > built-in defaults.

## Debug Mode

```bash
rdm issues list --debug
# or
RDM_DEBUG=1 rdm issues list
```

Shows HTTP requests and responses with credentials redacted.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (connection, timeout, server error) |
| 2 | Authentication or authorization error |
| 3 | Resource not found |
| 4 | Validation error |

## Security

- **HTTPS enforced** by default. Use `--allow-insecure-http` during login to override for local development.
- **Credentials** stored at `~/.rdm/config.yml` with `0600` permissions, directory with `0700`.
- **API keys masked** in all output, debug logs, and error messages.
- **Atomic config writes** — credentials are never partially written.
- **Destructive operations** (delete) require explicit `--confirm` flag.
- **No shell execution** — all operations are HTTP-only, no injection risk.

## Development

```bash
git clone https://github.com/agileware/rdm.git
cd rdm
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run the CLI locally
bundle exec bin/rdm help
```

## License

MIT

<!--
SPDX-FileCopyrightText: 2023-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# PostGIS Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Postgres with PostGIS extensions](https://github.com/postgis/docker-postgis) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

>[!NOTE]
> This role is based on [ansible-role-postgres](https://github.com/mother-of-all-self-hosting/ansible-role-postgres/tree/8d2f0e7ba8ae8680a37c78350f9d5d4f9f4dbe71) maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [`defaults/main.yml`](defaults/main.yml) for the full list of supported options.

💡 For an Ansible playbook which integrates this role and makes it easier to use, see the [Mother-of-All-Self-Hosting Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

## Features

- **multiple databases support**: this role manages one main database and root credentials, and optionally a list of additional managed databases with their own credentials (see `postgis_managed_databases`)

- **backward compatible**: even if a new Postgres version is available, the role will keep you on the Postgres version you had started with until you perform a major upgrade manually (see below)

<!--
TODO: support upgrading to a new major version

- **upgrading between major Postgres versions**: invoking the playbook with a `--tags=upgrade-postgis` performs a dump, data move (`data` -> `data-auto-upgrade-backup`), rebuild, and dump import
-->

- **importing existing Postgres database dumps**: you can import plain-text (`.sql`), gzipped (`sql.gz`), zstandard-compressed (`.sql.zst`) dumps with the `--tags=import-postgis` tag

- **import data from SQLite, NeDB, etc**: this is an internal task (not exposed as a playbook tag), but the role supports using [pgloader](https://pgloader.io/) to load data into Postgres

- **vacuum support**: you can vacuum all configured databases in one run using the `--tags=run-postgis-vacuum` tag

- **helpful scripts**:
  - get a `psql` interactive terminal via the `/base_path/bin/cli` and `/base_path/bin/cli-non-interactive` scripts
  - dump all databases using the `/base_path/bin/dump-all DIRECTORY_PATH` (which will dump to a `latest-dump.sql.gz` file there)
  - the CLI scripts can prefer unix sockets when `postgis_cli_use_unix_socket_enabled` is true

- **unix socket support**: optionally bind-mounts the Postgres unix socket directory to the host at `postgis_run_path` (see `postgis_container_unix_socket_enabled`)

## Usage

Example playbook:

```yaml
- hosts: servers
  roles:
    - role: galaxy/com.devture.ansible.role.systemd_docker_base

    - role: galaxy/postgis

    - role: another_role
```

Example playbook configuration (`group_vars/servers` or other):

```yaml
postgis_identifier: my-postgis

postgis_base_path: "{{ my_base_path }}/postgis"

postgis_container_network: "{{ my_container_container_network }}"

postgis_uid: "{{ my_uid }}"
postgis_gid: "{{ my_gid }}"

# If enabled, unix socket will be available at `{{ postgis_run_path }}` on the host.
postgis_container_unix_socket_enabled: true

postgis_vacuum_default_databases_list: ["mydb", "anotherdb"]

postgis_systemd_services_to_stop_for_maintenance_list: |
  {{
    (['my-service.service'])
  }}

postgis_managed_databases: |
  {{
    [{
      'name': my_database_name,
      'username': my_database_username,
      'password': my_database_password,
    }]
    +
    [{
      'name': another_database_name,
      'username': another_database_username,
      'password': another_database_password,
    }]
  }}
```

## Development

You can optionally install a Git pre-commit hook (via [mise](https://mise.jdx.dev/) + [prek](https://prek.j178.dev/)) that runs formatting and linting checks before each commit. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.

To install the hook, run the [`just`](https://github.com/casey/just) command below:

```sh
just prek-install-git-pre-commit-hook
```

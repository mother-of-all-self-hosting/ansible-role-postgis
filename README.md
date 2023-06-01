# Postgis Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Postgis](http://postgis.net/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service. It is based on this [postgres role](https://github.com/devture/com.devture.ansible.role.postgres) but only supports a subset of functions for easier maintainability.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)


## Features

- **multiple databases support**: this role manages one main database and root credentials, and optionally a list of additional managed databases with their own credentials (see `postgis_managed_databases`)

- **vacuum support**: you can vacuum the database using the `--tags=run-postgres-vacuum` tag

- **helpful scripts**:
  - get a `psql` interactive terminal via the `/base_path/bin/cli` and `/base_path/bin/cli-non-interactive` scripts
  - dump all databases using the `/base_path/bin/dump-all DIRECTORY_PATH` (which will dump to a `latest-dump.sql.gz` file there)



# Run Ansible Playbook (Docker) — reusable GitHub Action

Brief: A Docker-based GitHub Action to run Ansible playbooks. Supports a base64-encoded SSH private key (pass as a secret).

Inputs (see `action.yml`):
- `playbook` (required) — path to the playbook (relative to the workspace) or a path inside a cloned repository.
- `inventory` — path to the inventory file or an inventory string.
- `playbook_url` / `inventory_url` — git/https URL to obtain the playbook/inventory.
- `ssh_key_base64` (required) — base64-encoded private key (provide via GitHub Secret).
- `ssh_user`, `extra_args`, `strict_host_key_checking`, `ansible_version` — additional options.

Best practices:
- Store the SSH private key in GitHub Secrets and pass it as `ssh_key_base64: ${{ secrets.SSH_KEY_BASE64 }}`.
- Use `playbook_url` and `inventory_url` when playbooks or inventories live in a separate repository.
- Do not disable `StrictHostKeyChecking` in production unless you manage `known_hosts` securely.

Example usage (in a repo with this action):

```yaml
name: Run playbook
on: [workflow_dispatch]

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Ansible
        uses: ./  # or user/repo@v1
        with:
          playbook: playbooks/site.yml
          inventory: inventories/hosts.yml
          ssh_key_base64: ${{ secrets.SSH_KEY_BASE64 }}
          ssh_user: ubuntu
          extra_args: "-e env=prod"
```

Local build and test:

```bash
# from repo root
docker build -t ansible-action:local .
docker run --rm -e INPUT_PLAYBOOK=playbooks/site.yml -e INPUT_SSH_KEY_BASE64="$(cat id_rsa | base64)" ansible-action:local
```

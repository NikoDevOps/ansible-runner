#!/usr/bin/env bash
set -euo pipefail

# Inputs from action are passed as args (see action.yml ordering)
PLAYBOOK="$1"
INVENTORY="$2"
PLAYBOOK_URL="$3"
INVENTORY_URL="$4"
SSH_KEY_BASE64="$5"
SSH_USER="$6"
EXTRA_ARGS="$7"
STRICT_HOST_KEY_CHECKING="$8"
ANSIBLE_VERSION="$9"

mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Use the GitHub workspace if available (the runner mounts the repo at $GITHUB_WORKSPACE)
BASE_WORKDIR="${GITHUB_WORKSPACE:-/work}"
cd "$BASE_WORKDIR" || exit 1

if [ -n "$SSH_KEY_BASE64" ]; then
  echo "$SSH_KEY_BASE64" | base64 --decode > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
fi

if [ "${STRICT_HOST_KEY_CHECKING:-true}" = "false" ]; then
  echo "Setting StrictHostKeyChecking=no"
  echo -e "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null\n" > /root/.ssh/config
  chmod 600 /root/.ssh/config
fi

# Optionally install specific ansible version
if [ -n "$ANSIBLE_VERSION" ]; then
  pip install --no-cache-dir "ansible-core==$ANSIBLE_VERSION"
fi


# Fetch playbook repo if provided
if [ -n "$PLAYBOOK_URL" ]; then
  echo "Fetching playbook from $PLAYBOOK_URL"
  if [[ "$PLAYBOOK_URL" == git@* || "$PLAYBOOK_URL" == http* ]]; then
    rm -rf "$BASE_WORKDIR/playbook_src"
    git clone --depth 1 "$PLAYBOOK_URL" "$BASE_WORKDIR/playbook_src"
    PLAYBOOK="playbook_src/$PLAYBOOK"
  else
    echo "Unsupported playbook_url format: $PLAYBOOK_URL"
    exit 2
  fi
fi

# Fetch inventory if provided as URL
if [ -n "$INVENTORY_URL" ]; then
  echo "Fetching inventory from $INVENTORY_URL"
  rm -rf "$BASE_WORKDIR/inventory"
  if [[ "$INVENTORY_URL" == git@* || "$INVENTORY_URL" == http* ]]; then
    git clone --depth 1 "$INVENTORY_URL" "$BASE_WORKDIR/inventory"
    INVENTORY="inventory/$INVENTORY"
  else
    echo "Unsupported inventory_url format: $INVENTORY_URL"
    exit 3
  fi
fi

# Build ansible-playbook command
CMD=(ansible-playbook)

if [ -n "$INVENTORY" ]; then
  # If inventory is a relative path, resolve against workspace
  if [[ "$INVENTORY" != /* ]]; then
    INVENTORY="$BASE_WORKDIR/$INVENTORY"
  fi
  CMD+=( -i "$INVENTORY" )
fi

if [ -n "$SSH_USER" ]; then
  CMD+=( -u "$SSH_USER" )
fi

# Resolve playbook path if relative
if [[ "$PLAYBOOK" != /* ]]; then
  PLAYBOOK="$BASE_WORKDIR/$PLAYBOOK"
fi

# verify playbook exists
if [ ! -f "$PLAYBOOK" ]; then
  echo "Error: playbook file not found: $PLAYBOOK"
  echo "Current working dir: $(pwd)"
  echo "Workspace dir: $BASE_WORKDIR"
  echo "Workspace top-level files:" 
  ls -la "$BASE_WORKDIR" || true
  echo "Workspace tree (depth=2):"
  find "$BASE_WORKDIR" -maxdepth 2 -print || true
  exit 4
fi

CMD+=( "$PLAYBOOK" )

if [ -n "$EXTRA_ARGS" ]; then
  # NOTE: extra args are passed as a single string; use eval expansion
  echo "Running: ${CMD[*]} $EXTRA_ARGS"
  eval "${CMD[*]} $EXTRA_ARGS"
else
  echo "Running: ${CMD[*]}"
  "${CMD[@]}"
fi
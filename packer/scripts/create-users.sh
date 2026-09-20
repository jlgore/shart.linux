#!/bin/bash
set -euo pipefail

CREATE_LOCAL_USER=${CREATE_LOCAL_USER:-false}
LOCAL_USERNAME=${LOCAL_USERNAME:-debian}
LOCAL_PASSWORD=${LOCAL_PASSWORD:-changeMe123!}

echo "Configuring users..."

if [[ "${CREATE_LOCAL_USER}" == "true" ]]; then
  echo "Creating local user '${LOCAL_USERNAME}'..."
  id -u "${LOCAL_USERNAME}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${LOCAL_USERNAME}"
  echo "${LOCAL_USERNAME}:${LOCAL_PASSWORD}" | chpasswd
  usermod -aG sudo "${LOCAL_USERNAME}" || true
else
  echo "Skipping local user creation (CREATE_LOCAL_USER!=true)."
fi

# Root password is set during preseed for Packer SSH; leave as-is here.
echo "User configuration completed"

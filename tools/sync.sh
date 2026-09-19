#!/bin/bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tar -czf - --exclude='.git' -C "$DIR" . | /tmp/vm_ssh.sh "mkdir -p /root/bend && tar -xzf - -C /root/bend"

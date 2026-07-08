#!/usr/bin/env bash
set -euo pipefail

env_dir=".venv"

if ! command -v python3 > /dev/null; then
    echo "Python3 is not installed. Please install Python3 using 'apt-get install python3' and try again."
    exit 1
fi

if [[ ! -d "$env_dir" ]]; then
    echo "Env directory '$env_dir' does not exist, it will be created"
    python3 -m venv "$env_dir"
fi

source "$env_dir"/bin/activate

pip install -r requirements.txt

echo "Dependencies successfully installed, now run command 'source .venv/bin/activate' to start work into the venv"
#!/bin/bash

# following line copied from https://stackoverflow.com/questions/59895
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

exec ansible-playbook --ask-become-pass "$SCRIPT_DIR"/configure.yaml "$@"

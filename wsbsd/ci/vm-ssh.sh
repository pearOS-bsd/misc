#!/bin/sh
exec ssh -i $HOME/fbsd-vm/id_ed25519 -p 2222 -o StrictHostKeyChecking=no "$@"

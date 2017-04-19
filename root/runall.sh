#!/bin/bash
set -x

(docker events | /watcher.sh) &

# Run nginx
nginx -g 'daemon off;'

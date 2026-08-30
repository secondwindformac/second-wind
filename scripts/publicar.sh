#!/usr/bin/env bash
# Alias en español (compatibilidad): la publicación vive en publish.sh
exec "$(dirname "$0")/publish.sh" "$@"

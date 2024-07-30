#!/bin/sh
# vue-cli
# cd apps/hitb_web/assets/ && npm run build:release && cd ../../../
# esbuild
mix phx.digest
MIX_ENV=prod mix release check_school
mix phx.digest.clean --all
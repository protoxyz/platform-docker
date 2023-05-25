#!/usr/bin/env sh
# /docker-entrypoint.sh

if [[ -z "${DATABASE_URL}" ]]; then
export DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?schema=public"
fi

if [[ -z "${REDIS_PORT}" ]]; then
export REDIS_URL="redis://${REDIS_HOST}:${REDIS_PORT}"
fi

# Migrate prisma
if [[ -z "${SKIP_MIGRATE}" ]]; then
cd ./packages/database && pnpm prisma migrate deploy && cd ../..
fi

exec "$@"
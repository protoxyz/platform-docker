FROM node:18-alpine AS base

FROM base AS builder
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
RUN apk update

# Set working directory
WORKDIR /app
RUN corepack enable pnpm 
RUN npm i -g turbo
COPY . .

ARG ROOT_PATH="apps/api"
ARG INSTALL_COMMAND="pnpm install"
ARG BUILD_COMMAND='turbo run build --filter="./${ROOT_PATH}"'
ARG START_COMMAND='node ./${ROOT_PATH}/dist/index.js'
ARG SCOPE="api"

RUN turbo prune --scope="${SCOPE}" --docker

# Add lockfile and package.json's of isolated subworkspace
FROM base AS installer
RUN apk add --no-cache libc6-compat
RUN apk update
WORKDIR /app
RUN corepack enable pnpm 
RUN npm i -g turbo

# First install dependencies (as they change less often)
COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=builder /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml

RUN pnpm install

# Build the project and its dependencies
COPY --from=builder /app/out/full/ .
COPY turbo.json turbo.json

ARG ROOT_PATH="apps/api"
RUN turbo run build --filter="./${ROOT_PATH}"

FROM base AS runner
WORKDIR /app

RUN corepack enable pnpm 
RUN npm i -g turbo

# Don't run production as root
RUN addgroup --system --gid 1001 expressjs
RUN adduser --system --uid 1001 expressjs
USER expressjs
COPY --from=installer /app .

COPY ./docker-entrypoint.sh ./docker-entrypoint.sh 

ENTRYPOINT ["./docker-entrypoint.sh"]
EXPOSE 80

ENV ROOT_PATH="apps/api"
RUN echo "ROOT_PATH: ${ROOT_PATH}"

CMD ls -al ./${ROOT_PATH}/dist && node ./${ROOT_PATH}/dist/app.js
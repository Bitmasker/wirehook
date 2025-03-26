# syntax=docker.io/docker/dockerfile:1

FROM alpine:latest AS base

# If you are behind a proxy and need to install your cert to the trusted certificates
# store in the image, uncomment the following lines and replace your cert name
# COPY cert.crt /usr/local/share/ca-certificates/cert.crt
# RUN cat /usr/local/share/ca-certificates/cert.crt >> /etc/ssl/certs/ca-certificates.crt

# Install dependencies only when needed
FROM base AS builder
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --update --no-cache nodejs npm libc6-compat
WORKDIR /app

RUN echo "Node version:"
RUN node --version
RUN echo "Npm version:"
RUN npm --version

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json ./
# Do a clean install of the dependencies (c-parameter)
RUN npm ci

# Rebuild the source code only when needed
# FROM base AS builder
# RUN apk add --update --no-cache nodejs npm
# WORKDIR /app
# COPY --from=deps /app/node_modules ./node_modules
COPY . .


# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
# RUN apk add --update --no-cache nodejs npm libc6-compat
RUN apk add --update --no-cache nodejs htop
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/config/next-config-js/output
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
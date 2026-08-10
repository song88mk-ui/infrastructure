FROM node:24-alpine

# Enable pnpm via Corepack (ships with Node 20)
RUN corepack enable

WORKDIR /app

# Copy manifest + lockfile first so this layer caches until deps change
COPY package.json pnpm-lock.yaml ./

# --frozen-lockfile fails if the lockfile is out of sync — reproducible builds.
# --prod skips devDependencies.
RUN pnpm install --frozen-lockfile --prod

COPY index.js zh.json ./

USER node
CMD ["node", "index.js"]

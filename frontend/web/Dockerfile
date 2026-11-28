# ==============================
# Stage 1: Build React application
# ==============================
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY . .

ARG VITE_API_URL
ARG VITE_BASE_PATH

# Docker Compose may pass an empty VITE_API_URL. Unset empty build args so Vite can load
# the checked-in .env.production fallback; explicit non-empty build args still take priority.
RUN if [ -z "${VITE_API_URL}" ]; then unset VITE_API_URL; fi \
    && if [ -z "${VITE_BASE_PATH}" ]; then unset VITE_BASE_PATH; fi \
    && npm run build

# ==============================
# Stage 2: Serve production files
# ==============================
FROM nginx:stable-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

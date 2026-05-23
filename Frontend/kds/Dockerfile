# ══════════════════════════════════════════════════════════════
#  KDS Frontend — Dockerfile
#  Stages: build (Flutter web) → serve (nginx)
#
#  ARGs disponibles:
#    API_URL    URL base del backend (default: http://localhost:8000)
#    BUILD_MODE flutter build mode: release | profile | debug
#               · release → prod (tree-shaking completo, mínimo tamaño)
#               · profile → dev  (DevTools activos, sin minificación agresiva)
# ══════════════════════════════════════════════════════════════

# ── Build stage ───────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Cachear dependencias de pub antes de copiar el código fuente.
# Esta capa solo se invalida si pubspec.yaml o pubspec.lock cambian.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copiar código fuente
COPY . .

ARG API_URL=http://localhost:8000
ARG BUILD_MODE=release

# flutter build web compila todo el Dart a JavaScript.
# --dart-define inyecta constantes en tiempo de compilación
# accesibles en Dart con: const String.fromEnvironment('API_URL')
RUN flutter build web \
    --${BUILD_MODE} \
    --dart-define=API_URL=${API_URL}

# ── Serve stage ───────────────────────────────────────────────
# Imagen final: solo nginx + los archivos compilados de Flutter.
# El SDK de Flutter NO está en esta imagen (~1.5 GB menos).
FROM nginx:1.27-alpine AS serve

# Copiar artefactos compilados
COPY --from=build /app/build/web /usr/share/nginx/html

# Configuración nginx optimizada para SPAs Flutter
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/ || exit 1

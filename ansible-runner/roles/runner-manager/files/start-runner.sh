#!/bin/bash
set -euo pipefail

# Variables provistas por env:
# GITHUB_ORG  -> nombre de la organización (p. ej. "TestingJDA")
# GITHUB_TOKEN -> PAT con permisos para crear registration tokens a nivel org

if [ -z "${GITHUB_ORG:-}" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Faltan variables GITHUB_ORG o GITHUB_TOKEN"
  exit 1
fi

# Obtener token de registro para la organización (dura ~1 hora)
echo "Solicitando registration token para org ${GITHUB_ORG}..."
REG_JSON=$(curl -sX POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  "https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token")

REG_TOKEN=$(echo "${REG_JSON}" | jq -r .token)

if [ -z "${REG_TOKEN}" ] || [ "${REG_TOKEN}" = "null" ]; then
  echo "No se pudo obtener registration token: ${REG_JSON}"
  exit 1
fi

# directorio runtime del runner
RUNNER_DIR="/runner"
mkdir -p ${RUNNER_DIR}
cd ${RUNNER_DIR}

# Descargar runner si no existe
if [ ! -f ./config.sh ]; then
  echo "Se asume que la imagen base ya contiene el runner (actions/runner)."
fi

# Configurar runner como efímero
./config.sh --url "https://github.com/${GITHUB_ORG}" --token "${REG_TOKEN}" --name "runner-${HOSTNAME}-$(date +%s)" --labels "ephemeral,docker" --ephemeral --unattended

cleanup() {
  echo "Limpiando runner..."
  # intenta remover la configuración (token ya expirado puede fallar)
  ./config.sh remove --unattended || true
}
trap cleanup EXIT

# Ejecuta el runner (bloqueante). Cuando termine, el contenedor debe salir.
./run.sh
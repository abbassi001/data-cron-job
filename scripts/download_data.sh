#!/bin/bash

# Configuration
DATA_DIR="$(pwd)/data"
RAW_DIR="$DATA_DIR/raw"
PROCESSED_DIR="$DATA_DIR/processed"
LOG_DIR="$(pwd)/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/download_$DATE.log"

# Sources de données ouvertes
# Format: NOM|URL|TYPE_FICHIER
SOURCES=(
  "METEO_FRANCE|https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/donnees-synop-essentielles-omm/exports/csv|CSV"
)

# Créer les répertoires s'ils n'existent pas
mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$LOG_DIR"

# Fonction pour télécharger et journaliser
download_data() {
  local NAME=$1
  local URL=$2
  local TYPE=$3
  local OUTPUT_FILE="$RAW_DIR/${NAME}_${DATE}.${TYPE,,}"
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement de $NAME depuis $URL" | tee -a "$LOG_FILE"
  
  # Télécharger le fichier
  if curl -s -L -o "$OUTPUT_FILE" "$URL"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement réussi: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))" | tee -a "$LOG_FILE"
    
    # Vérifier si le fichier est vide
    if [ -s "$OUTPUT_FILE" ]; then
      # Ajouter des métadonnées sur la source
      echo "# Données téléchargées le: $DATE" > "$OUTPUT_FILE.meta"
      echo "# Source: $URL" >> "$OUTPUT_FILE.meta"
      echo "# Type: $TYPE" >> "$OUTPUT_FILE.meta"
      
      # Pour les CSV, afficher les premières lignes
      if [[ "${TYPE,,}" == "csv" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Aperçu des données:" | tee -a "$LOG_FILE"
        head -n 5 "$OUTPUT_FILE" | tee -a "$LOG_FILE"
      fi
      
      # Pour JSON, compter le nombre d'éléments
      if [[ "${TYPE,,}" == "json" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Structure JSON:" | tee -a "$LOG_FILE"
        # Si jq est installé
        if command -v jq >/dev/null 2>&1; then
          jq 'keys' "$OUTPUT_FILE" | tee -a "$LOG_FILE"
        else
          echo "jq non installé, impossible d'analyser le JSON" | tee -a "$LOG_FILE"
        fi
      fi
      
      # Afficher le hash du fichier pour vérifier les modifications
      SHA=$(sha256sum "$OUTPUT_FILE" | cut -d' ' -f1)
      echo "$(date '+%Y-%m-%d %H:%M:%S') - SHA256: $SHA" | tee -a "$LOG_FILE"
      echo "$SHA" > "$OUTPUT_FILE.sha256"
      
      git add "$OUTPUT_FILE.meta" "$OUTPUT_FILE.sha256"
      
      return 0
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Fichier téléchargé vide" | tee -a "$LOG_FILE"
      rm -f "$OUTPUT_FILE"
      return 1
    fi
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: Échec du téléchargement depuis $URL" | tee -a "$LOG_FILE"
    return 1
  fi
}

# Télécharger toutes les sources
echo "===== Début du téléchargement des données: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

for SOURCE in "${SOURCES[@]}"; do
  IFS='|' read -r NAME URL TYPE <<< "$SOURCE"
  download_data "$NAME" "$URL" "$TYPE"
done

echo "===== Fin du téléchargement des données: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

# Commit des métadonnées dans Git
git add "$LOG_FILE"
git commit -m "Data download: $DATE" || echo "Aucun changement à committer"
#!/bin/bash

# Script amélioré pour télécharger de grands volumes de données
# ============================================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
RAW_DIR="$DATA_DIR/raw"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/download_$DATE.log"

# Créer les répertoires s'ils n'existent pas
mkdir -p "$RAW_DIR" "$LOG_DIR"

# Initialiser le journal
echo "===== DÉBUT DU TÉLÉCHARGEMENT DE DONNÉES MASSIVES: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

# Sources de données volumineuses - environ 250+ MB combinées
# Format: NOM|URL|TYPE_FICHIER|TAILLE_ESTIMÉE_MB
SOURCES=(
  # Données météorologiques complètes - historique depuis 2010
  "METEO_HISTORIQUE|https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/donnees-synop-essentielles-omm/exports/csv?limit=1000000|CSV|80"
  
  # Données économiques de l'INSEE (gros fichier)
  "INSEE_ECONOMIE|https://www.insee.fr/fr/statistiques/fichier/6544344/base-cc-emploi-pop-act-2019-csv.zip|ZIP|45"
  
  # Données environnementales européennes
  "ENVIRO_EU|https://www.eea.europa.eu/data-and-maps/data/waterbase-water-quality-icm-2/waterbase-water-quality-icm-2/waterbase-water-quality-data-results.csv/at_download/file|CSV|60"
  
  # Données de transport SNCF (volumineuse)
  "SNCF_DATA|https://ressources.data.sncf.com/api/v2/catalog/datasets/regularite-mensuelle-tgv-aqst/exports/csv?limit=-1&timezone=Europe%2FBerlin|CSV|35"
  
  # Données démographiques mondiales
  "WORLD_POP|https://population.un.org/wpp/Download/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2022_Demographic_Indicators_Medium.zip|ZIP|50"
)

# Fonction pour télécharger et journaliser avec support pour les grands fichiers
download_data() {
  local NAME=$1
  local URL=$2
  local TYPE=$3
  local SIZE_MB=$4
  local OUTPUT_FILE="$RAW_DIR/${NAME}_${DATE}.${TYPE,,}"
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Début téléchargement de $NAME (taille estimée: ${SIZE_MB}MB) depuis $URL" | tee -a "$LOG_FILE"
  
  # Verification de l'espace disque
  local AVAILABLE_SPACE=$(df -m "$RAW_DIR" | awk 'NR==2 {print $4}')
  if [ "$AVAILABLE_SPACE" -lt $(($SIZE_MB * 2)) ]; then
    echo "⚠️ AVERTISSEMENT: Espace disque disponible ($AVAILABLE_SPACE MB) faible pour ce téléchargement (${SIZE_MB}MB). Poursuite quand même..." | tee -a "$LOG_FILE"
  fi
  
  # Téléchargement avec barre de progression et reprise
  # -C - pour permettre la reprise des téléchargements interrompus
  if curl -L --retry 5 --retry-delay 10 --max-time 3600 -C - --progress-bar -o "$OUTPUT_FILE" "$URL"; then
    if [ -s "$OUTPUT_FILE" ]; then
      local ACTUAL_SIZE=$(du -m "$OUTPUT_FILE" | cut -f1)
      echo "✅ Téléchargement réussi: $OUTPUT_FILE (${ACTUAL_SIZE}MB)" | tee -a "$LOG_FILE"
      
      # Ajouter des métadonnées détaillées
      echo "# Données téléchargées le: $DATE à $(date '+%H:%M:%S')" > "$OUTPUT_FILE.meta"
      echo "# Source: $URL" >> "$OUTPUT_FILE.meta"
      echo "# Type: $TYPE" >> "$OUTPUT_FILE.meta"
      echo "# Taille: ${ACTUAL_SIZE}MB" >> "$OUTPUT_FILE.meta"
      
      # Traitement spécial pour les ZIP - décompression
      if [[ "${TYPE,,}" == "zip" ]]; then
        echo "📦 Décompression du fichier ZIP..." | tee -a "$LOG_FILE"
        EXTRACT_DIR="$RAW_DIR/${NAME}_${DATE}_extracted"
        mkdir -p "$EXTRACT_DIR"
        
        if unzip -q "$OUTPUT_FILE" -d "$EXTRACT_DIR"; then
          echo "✅ Décompression réussie dans $EXTRACT_DIR" | tee -a "$LOG_FILE"
          
          # Liste des fichiers extraits
          echo "📄 Fichiers extraits:" | tee -a "$LOG_FILE"
          find "$EXTRACT_DIR" -type f | tee -a "$LOG_FILE"
          
          # Compter le nombre de fichiers CSV extraits
          CSV_COUNT=$(find "$EXTRACT_DIR" -name "*.csv" | wc -l)
          if [ "$CSV_COUNT" -gt 0 ]; then
            echo "🔍 $CSV_COUNT fichier(s) CSV trouvé(s) dans l'archive" | tee -a "$LOG_FILE"
          fi
        else
          echo "❌ Échec de la décompression de $OUTPUT_FILE" | tee -a "$LOG_FILE"
        fi
      fi
      
      # Pour les CSV volumineux, afficher uniquement les 2 premières et 2 dernières lignes
      if [[ "${TYPE,,}" == "csv" ]]; then
        echo "📊 Aperçu des données (2 premières lignes):" | tee -a "$LOG_FILE"
        head -n 2 "$OUTPUT_FILE" | tee -a "$LOG_FILE"
        
        # Nombre total de lignes
        LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
        echo "📏 Nombre total de lignes: $LINE_COUNT" | tee -a "$LOG_FILE"
        
        echo "📊 2 dernières lignes:" | tee -a "$LOG_FILE"
        tail -n 2 "$OUTPUT_FILE" | tee -a "$LOG_FILE"
      fi
      
      # Calcul du hash pour les fichiers volumineux (plus lent mais plus sûr)
      echo "🔐 Calcul du hash SHA256 (peut prendre un moment pour les gros fichiers)..." | tee -a "$LOG_FILE"
      SHA=$(sha256sum "$OUTPUT_FILE" | cut -d' ' -f1)
      echo "$SHA" > "$OUTPUT_FILE.sha256"
      echo "🔐 Hash SHA256: $SHA" | tee -a "$LOG_FILE"
      
      return 0
    else
      echo "❌ Fichier téléchargé vide: $NAME" | tee -a "$LOG_FILE"
      rm -f "$OUTPUT_FILE"
      return 1
    fi
  else
    echo "❌ Échec du téléchargement de $NAME" | tee -a "$LOG_FILE"
    return 1
  fi
}

# Fonction pour vérifier l'accès Internet
check_internet() {
  echo "🌐 Vérification de la connexion Internet..." | tee -a "$LOG_FILE"
  if ping -c 3 google.com > /dev/null 2>&1; then
    echo "✅ Connexion Internet fonctionnelle" | tee -a "$LOG_FILE"
    return 0
  else
    echo "❌ Pas de connexion Internet détectée" | tee -a "$LOG_FILE"
    return 1
  fi
}

# Vérifier la connexion Internet avant de commencer
if ! check_internet; then
  echo "⚠️ Connexion Internet insuffisante pour télécharger des fichiers volumineux. Abandon." | tee -a "$LOG_FILE"
  exit 1
fi

# Calculer l'espace total nécessaire
TOTAL_SIZE=0
for SOURCE in "${SOURCES[@]}"; do
  IFS='|' read -r NAME URL TYPE SIZE_MB <<< "$SOURCE"
  TOTAL_SIZE=$((TOTAL_SIZE + SIZE_MB))
done

echo "📊 Volume total à télécharger: environ ${TOTAL_SIZE}MB" | tee -a "$LOG_FILE"

# Vérification d'espace disque global
AVAILABLE_SPACE=$(df -m "$RAW_DIR" | awk 'NR==2 {print $4}')
echo "💾 Espace disque disponible: ${AVAILABLE_SPACE}MB" | tee -a "$LOG_FILE"

if [ "$AVAILABLE_SPACE" -lt $(($TOTAL_SIZE * 2)) ]; then
  echo "⚠️ AVERTISSEMENT: L'espace disque disponible ($AVAILABLE_SPACE MB) est faible pour le total des téléchargements (${TOTAL_SIZE}MB)" | tee -a "$LOG_FILE"
  read -p "Voulez-vous continuer quand même? (o/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "🛑 Téléchargement annulé par l'utilisateur." | tee -a "$LOG_FILE"
    exit 1
  fi
fi

# Télécharger toutes les sources
echo "🚀 Début des téléchargements massifs (${#SOURCES[@]} sources, environ ${TOTAL_SIZE}MB au total)" | tee -a "$LOG_FILE"

SUCCESS_COUNT=0
FAILED_COUNT=0

for SOURCE in "${SOURCES[@]}"; do
  IFS='|' read -r NAME URL TYPE SIZE_MB <<< "$SOURCE"
  
  echo "📥 Traitement de la source: $NAME (${SIZE_MB}MB)" | tee -a "$LOG_FILE"
  
  if download_data "$NAME" "$URL" "$TYPE" "$SIZE_MB"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
  
  echo "------------------------------------------------" | tee -a "$LOG_FILE"
done

# Résumé final
echo "===== RÉSUMÉ DU TÉLÉCHARGEMENT =====" | tee -a "$LOG_FILE"
echo "✅ Téléchargements réussis: $SUCCESS_COUNT" | tee -a "$LOG_FILE"
echo "❌ Téléchargements échoués: $FAILED_COUNT" | tee -a "$LOG_FILE"
echo "💾 Espace disque utilisé: $(du -sh "$RAW_DIR" | cut -f1)" | tee -a "$LOG_FILE"
echo "===== FIN DES TÉLÉCHARGEMENTS MASSIFS: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

# Retourner un code d'erreur si tous les téléchargements ont échoué
if [ "$SUCCESS_COUNT" -eq 0 ]; then
  echo "❌ ERREUR: Tous les téléchargements ont échoué." | tee -a "$LOG_FILE"
  exit 1
fi

exit 0
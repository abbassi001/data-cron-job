#!/bin/bash

# Script principal simplifié
# Ce script orchestre l'ensemble du processus :
# 1. Téléchargement des données
# 2. Traitement des données
# 3. Génération d'un rapport

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/job_$DATE.log"
EMAIL="abbassiadamou55@gmail.com" # À modifier si nécessaire

# Vérifier que le script est exécuté depuis le répertoire du projet
cd "$PROJECT_DIR" || {
  echo "Erreur: Impossible d'accéder au répertoire du projet: $PROJECT_DIR"
  exit 1
}

# Initialiser le journal
mkdir -p "$LOG_DIR"
echo "===== Début du job de données: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

# Fonctions 
notify() {
  local subject="$1"
  local message="$2"
  
  # Envoi d'email si mail est configuré
  if command -v mail &> /dev/null; then
    echo "$message" | mail -s "$subject" "$EMAIL"
    echo "Email envoyé à $EMAIL" | tee -a "$LOG_FILE"
  else
    echo "Notification: $subject - $message" | tee -a "$LOG_FILE"
    echo "⚠️ La commande 'mail' n'est pas disponible, impossible d'envoyer un email." | tee -a "$LOG_FILE"
  fi
}

handle_error() {
  local error_msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: $error_msg" | tee -a "$LOG_FILE"
  notify "❌ Job de données échoué" "Le job de données a échoué: $error_msg. Voir $LOG_FILE pour plus de détails."
  exit 1
}

# 1. Télécharger les données
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des données" | tee -a "$LOG_FILE"
bash "$SCRIPT_DIR/download_data.sh" || handle_error "Échec du téléchargement des données"

# 2. Traiter les données
echo "$(date '+%Y-%m-%d %H:%M:%S') - Traitement des données" | tee -a "$LOG_FILE"
python3 "$SCRIPT_DIR/process_data.py" || handle_error "Échec du traitement des données"

# 3. Générer un résumé des statistiques
echo "$(date '+%Y-%m-%d %H:%M:%S') - Génération du résumé" | tee -a "$LOG_FILE"

# Compter les fichiers
RAW_COUNT=$(find "$DATA_DIR/raw" -type f -name "*.$DATE.*" | wc -l)
PROCESSED_COUNT=$(find "$DATA_DIR/processed" -type f -mtime -1 | wc -l)
REPORT_COUNT=$(find "$DATA_DIR/reports" -type f -mtime -1 | wc -l)
REPORT_HTML=$(find "$DATA_DIR/reports" -name "rapport_$DATE.html")

# Créer un résumé
SUMMARY="
=== Résumé du job de données du $DATE ===
- Fichiers bruts collectés: $RAW_COUNT
- Fichiers traités générés: $PROCESSED_COUNT
- Rapports générés: $REPORT_COUNT
- Rapport principal: $REPORT_HTML
- Logs: $LOG_FILE
"

echo "$SUMMARY" | tee -a "$LOG_FILE"

# 4. Envoyer une notification
notify "✅ Job de données réussi - $DATE" "$SUMMARY"

echo "===== Fin du job de données: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"

echo "Pour consulter le rapport HTML: $REPORT_HTML"

exit 0
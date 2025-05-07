#!/bin/bash

# Script principal du cron job
# Ce script orchestre l'ensemble du processus :
# 1. Téléchargement des données
# 2. Traitement des données
# 3. Génération d'un rapport
# 4. Publication sur Git
# 5. Notification par email et webhook

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/job_$DATE.log"
EMAIL="votre.email@example.com" # À modifier
GIT_BRANCH="data-updates"
WEBHOOK_URL="" # Optionnel, pour les notifications

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
  
  echo "$message" | mail -s "$subject" "$EMAIL"
  
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"text\":\"$subject\", \"message\":\"$message\"}" \
         "$WEBHOOK_URL"
  fi
}

handle_error() {
  local error_msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR: $error_msg" | tee -a "$LOG_FILE"
  notify "❌ Job de données échoué" "Le job de données a échoué: $error_msg. Voir $LOG_FILE pour plus de détails."
  exit 1
}

# 1. Créer une nouvelle branche Git (ou utiliser l'existante)
echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuration de Git" | tee -a "$LOG_FILE"
git fetch origin || handle_error "Impossible de récupérer les branches distantes"

# Créer une nouvelle branche si elle n'existe pas déjà
if git show-ref --verify --quiet "refs/heads/$GIT_BRANCH"; then
  git checkout "$GIT_BRANCH" || handle_error "Impossible de passer à la branche $GIT_BRANCH"
  git pull origin "$GIT_BRANCH" || handle_error "Impossible de mettre à jour la branche $GIT_BRANCH"
else
  git checkout -b "$GIT_BRANCH" || handle_error "Impossible de créer la branche $GIT_BRANCH"
fi

# 2. Télécharger les données
echo "$(date '+%Y-%m-%d %H:%M:%S') - Téléchargement des données" | tee -a "$LOG_FILE"
bash "$SCRIPT_DIR/download_data.sh" || handle_error "Échec du téléchargement des données"

# 3. Traiter les données
echo "$(date '+%Y-%m-%d %H:%M:%S') - Traitement des données" | tee -a "$LOG_FILE"
python3 "$SCRIPT_DIR/process_data.py" || handle_error "Échec du traitement des données"

# 4. Commit des changements
echo "$(date '+%Y-%m-%d %H:%M:%S') - Commit des changements dans Git" | tee -a "$LOG_FILE"

# Ajouter uniquement les fichiers pertinents (pas les données brutes volumineuses)
git add "$LOG_DIR" 
git add "$DATA_DIR/processed" 
git add "$DATA_DIR/reports"
git add "*.meta" "*.sha256"

# Vérifier s'il y a des changements à committer
if git diff --staged --quiet; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Aucun changement à committer" | tee -a "$LOG_FILE"
else
  git commit -m "Data job: $DATE - Mise à jour automatique" || handle_error "Échec du commit"
  
  # Push vers le dépôt distant (si configuré)
  if git remote | grep -q "origin"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Push des changements vers le dépôt distant" | tee -a "$LOG_FILE"
    git push origin "$GIT_BRANCH" || handle_error "Échec du push vers origin"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Aucun dépôt distant configuré" | tee -a "$LOG_FILE"
  fi
fi

# 5. Générer un résumé des statistiques
echo "$(date '+%Y-%m-%d %H:%M:%S') - Génération du résumé" | tee -a "$LOG_FILE"

# Compter les fichiers
RAW_COUNT=$(find "$DATA_DIR/raw" -type f -name "*.$DATE.*" | wc -l)
PROCESSED_COUNT=$(find "$DATA_DIR/processed" -type f -mtime -1 | wc -l)
REPORT_COUNT=$(find "$DATA_DIR/reports" -type f -mtime -1 | wc -l)

# Créer un résumé
SUMMARY="
=== Résumé du job de données du $DATE ===
- Fichiers bruts collectés: $RAW_COUNT
- Fichiers traités générés: $PROCESSED_COUNT
- Rapports générés: $REPORT_COUNT
- Logs: $LOG_FILE
"

echo "$SUMMARY" | tee -a "$LOG_FILE"

# 6. Envoyer une notification
notify "✅ Job de données réussi - $DATE" "$SUMMARY"

echo "===== Fin du job de données: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"
exit 0
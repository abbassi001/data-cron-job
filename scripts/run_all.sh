#!/bin/bash

# ============================================================
# SCRIPT PRINCIPAL - ORCHESTRATEUR DE TOUT LE PROCESSUS
# ============================================================
# Ce script unique lance l'ensemble du processus :
# 1. Configuration initiale
# 2. Téléchargement des données
# 3. Traitement et analyse des données
# 4. Génération de rapports
# 5. Versionning Git
# 6. Envoi de notifications Discord avec rapport
# ============================================================

# Fonction pour afficher un texte en figlet si disponible
show_figlet() {
    local text="$1"
    if command -v figlet &> /dev/null; then
        figlet -f standard "$text"
    else
        echo ""
        echo "=== $text ==="
        echo ""
    fi
}

# Afficher le titre du projet
show_figlet "Data Process"
echo "============================================================"
echo "  SYSTÈME AUTOMATISÉ DE TRAITEMENT DE DONNÉES OUVERTES"
echo "============================================================"
echo ""

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
RAW_DIR="$DATA_DIR/raw"
PROCESSED_DIR="$DATA_DIR/processed"
REPORT_DIR="$DATA_DIR/reports"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/complet_$DATE.log"

# Configuration Discord - URL du webhook
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1369668625744662669/Vj-FfURhiuzXR7qD_kXIaw8oAl_-A41L8spsGnCdAZ2IKYSVgeXHeJ4f_YDA2at7-cC0"

# Vérifier que le script est exécuté depuis le répertoire du projet
cd "$PROJECT_DIR" || {
  echo "Erreur: Impossible d'accéder au répertoire du projet: $PROJECT_DIR"
  exit 1
}

# === INITIALISATION ===
# Créer les répertoires nécessaires
mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$REPORT_DIR" "$LOG_DIR"

# Initialiser le journal
echo "===== DÉBUT DU PROCESSUS COMPLET: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"
echo "👨‍💻 Script lancé par: $(whoami)" | tee -a "$LOG_FILE"
echo "📂 Répertoire du projet: $PROJECT_DIR" | tee -a "$LOG_FILE"

# Vérification de l'environnement
show_figlet "Check Env"
echo "--- Vérification de l'environnement ---" | tee -a "$LOG_FILE"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python installé: $PYTHON_VERSION" | tee -a "$LOG_FILE"
else
    echo "❌ Python non installé. Installation requise." | tee -a "$LOG_FILE"
    exit 1
fi

if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo "✅ Git installé: $GIT_VERSION" | tee -a "$LOG_FILE"
    GIT_ENABLED=true
    GIT_BRANCH="data-updates"
else
    echo "⚠️ Git non installé. Le versionning ne sera pas disponible." | tee -a "$LOG_FILE"
    GIT_ENABLED=false
fi

# Vérifier les dépendances Python
echo "--- Vérification des dépendances Python ---" | tee -a "$LOG_FILE"
python3 -c "import pandas" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Pandas non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install pandas || {
        echo "❌ Échec de l'installation de pandas. Veuillez l'installer manuellement." | tee -a "$LOG_FILE"
        exit 1
    }
else
    echo "✅ Pandas installé" | tee -a "$LOG_FILE"
fi

python3 -c "import matplotlib" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Matplotlib non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install matplotlib || {
        echo "❌ Échec de l'installation de matplotlib. Veuillez l'installer manuellement." | tee -a "$LOG_FILE"
        exit 1
    }
else
    echo "✅ Matplotlib installé" | tee -a "$LOG_FILE"
fi

# Vérifier requests pour Discord
python3 -c "import requests" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Requests non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install requests || {
        echo "❌ Échec de l'installation de requests. Les notifications Discord ne fonctionneront pas." | tee -a "$LOG_FILE"
    }
else
    echo "✅ Requests installé" | tee -a "$LOG_FILE"
fi

# Vérifier PIL pour la création d'images
python3 -c "from PIL import Image" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️ PIL/Pillow non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install pillow || {
        echo "⚠️ Échec de l'installation de PIL/Pillow. Les images ne seront pas générées." | tee -a "$LOG_FILE"
    }
else
    echo "✅ PIL/Pillow installé" | tee -a "$LOG_FILE"
fi

# Vérifier figlet (optionnel)
if ! command -v figlet &> /dev/null; then
    echo "ℹ️ Figlet n'est pas installé. Les bannières seront simplifiées." | tee -a "$LOG_FILE"
    echo "ℹ️ Pour installer figlet : sudo apt-get install figlet (Debian/Ubuntu)"
fi

# === FONCTIONS UTILITAIRES ===
# Script Python pour envoyer des notifications Discord avec rapport
create_discord_report_script() {
    local DISCORD_SCRIPT="$SCRIPT_DIR/send_discord_with_report.py"
    
    cat > "$DISCORD_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime

def read_report_content(report_path):
    """
    Lit le contenu d'un rapport HTML et extrait les éléments clés
    """
    try:
        with open(report_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Extraire les informations pertinentes
        # Ceci est une version simplifiée - vous pourriez avoir besoin d'un parsing HTML plus avancé
        summary = []
        
        # Extraire le nombre de fichiers traités
        if 'Nombre de fichiers traités:' in content:
            start = content.find('Nombre de fichiers traités:')
            end = content.find('</p>', start)
            if start > 0 and end > start:
                file_count = content[start:end].split(':')[1].strip()
                summary.append(f"Fichiers traités: {file_count}")
        
        # Extraire les graphiques générés
        if '<h2>Graphiques générés</h2>' in content:
            start = content.find('<h2>Graphiques générés</h2>')
            list_start = content.find('<ul>', start)
            list_end = content.find('</ul>', list_start)
            
            if list_start > 0 and list_end > list_start:
                graphs_list = content[list_start:list_end]
                graphs = []
                
                start_idx = 0
                while True:
                    li_start = graphs_list.find('<li>', start_idx)
                    if li_start == -1:
                        break
                    li_end = graphs_list.find('</li>', li_start)
                    if li_end == -1:
                        break
                    
                    graph_name = graphs_list[li_start+4:li_end].strip()
                    graphs.append(graph_name)
                    start_idx = li_end
                
                if graphs:
                    summary.append(f"Graphiques: {', '.join(graphs)}")
        
        # Si on n'a pas pu extraire d'infos, retourner un message par défaut
        if not summary:
            return "Rapport HTML généré. Consultez le fichier pour plus de détails."
        
        return "\n".join(summary)
        
    except Exception as e:
        print(f"⚠️ Erreur lors de la lecture du rapport: {str(e)}")
        return "Rapport HTML généré, mais impossible d'extraire le contenu."

def send_discord_message(webhook_url, message, title=None, report_path=None):
    """
    Envoie un message à Discord via un webhook, avec un résumé du rapport si disponible
    
    Args:
        webhook_url (str): URL du webhook Discord
        message (str): Le message à envoyer
        title (str, optional): Titre du message (embeds)
        report_path (str, optional): Chemin vers le rapport HTML
    """
    # Préparer le payload de base
    payload = {
        "content": message,
        "embeds": []
    }
    
    # Ajouter un embed avec titre et rapport si spécifié
    if title:
        embed = {
            "title": title,
            "description": message,
            "color": 3447003,  # Bleu Discord
            "timestamp": datetime.now().isoformat(),
            "fields": []
        }
        
        # Si un rapport est spécifié et existe
        if report_path and os.path.exists(report_path):
            report_content = read_report_content(report_path)
            
            embed["fields"].append({
                "name": "Résumé du rapport",
                "value": report_content
            })
            
            # Ajouter le chemin du rapport pour référence
            embed["footer"] = {
                "text": f"Rapport complet: {os.path.basename(report_path)}"
            }
        
        payload["embeds"].append(embed)
    
    # Envoyer la requête
    try:
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 204:
            print(f"✅ Message Discord envoyé avec succès!")
            return True
        else:
            print(f"❌ Erreur lors de l'envoi du message Discord: {response.status_code}")
            print(response.text)
            return False
    
    except Exception as e:
        print(f"❌ Exception lors de l'envoi du message Discord: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_discord_with_report.py webhook_url message [title] [report_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    report_path = sys.argv[4] if len(sys.argv) > 4 else None
    
    success = send_discord_message(webhook_url, message, title, report_path)
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$DISCORD_SCRIPT"
    echo "✅ Script d'envoi Discord avec rapport créé: $DISCORD_SCRIPT" | tee -a "$LOG_FILE"
}

# Fonction pour envoyer une notification Discord avec rapport
notify_discord_with_report() {
    local title="$1"
    local message="$2"
    local report_path="$3"
    
    echo "🎮 Tentative d'envoi de notification Discord avec rapport: $title" | tee -a "$LOG_FILE"
    
    # Créer le script Discord s'il n'existe pas déjà
    if [ ! -f "$SCRIPT_DIR/send_discord_with_report.py" ]; then
        create_discord_report_script
    fi
    
    # Envoyer la notification via Discord avec le rapport
    if python3 "$SCRIPT_DIR/send_discord_with_report.py" "$DISCORD_WEBHOOK" "$message" "$title" "$report_path"; then
        echo "✅ Notification Discord avec rapport envoyée avec succès" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Échec de l'envoi de la notification Discord avec rapport" | tee -a "$LOG_FILE"
        return 1
    fi
}

handle_error() {
    local step="$1"
    local error_msg="$2"
    
    show_figlet "ERROR"
    echo "❌ ERREUR à l'étape '$step': $error_msg" | tee -a "$LOG_FILE"
    notify_discord_with_report "❌ Erreur processus de données - Étape: $step" "Le processus a échoué à l'étape '$step': $error_msg. Voir $LOG_FILE pour plus de détails." ""
    exit 1
}

# === CONFIGURATION GIT ===
setup_git() {
    show_figlet "Git Setup"
    echo "--- Configuration du versionning Git ---" | tee -a "$LOG_FILE"
    
    if [ "$GIT_ENABLED" = true ]; then
        # Vérifier si le répertoire est un dépôt Git
        if [ ! -d ".git" ]; then
            echo "Initialisation du dépôt Git..." | tee -a "$LOG_FILE"
            git init || handle_error "Git init" "Impossible d'initialiser le dépôt Git"
        fi
        
        # Vérifier s'il y a des modifications non committées
        if git diff --quiet; then
            echo "✅ Aucune modification non commitée détectée" | tee -a "$LOG_FILE"
        else
            echo "⚠️ Modifications non commitées détectées" | tee -a "$LOG_FILE"
            # Auto-commit des modifications actuelles avant de changer de branche
            git add . || handle_error "Git add" "Impossible d'ajouter les modifications actuelles"
            git commit -m "Auto-commit avant traitement de données: $DATE" || handle_error "Git commit" "Impossible de committer les modifications actuelles"
            echo "✅ Modifications actuelles commitées" | tee -a "$LOG_FILE"
        fi
        
        # Créer ou utiliser la branche de données
        if git show-ref --verify --quiet "refs/heads/$GIT_BRANCH"; then
            git checkout "$GIT_BRANCH" || handle_error "Git checkout" "Impossible de passer à la branche $GIT_BRANCH"
            echo "✅ Passage à la branche existante: $GIT_BRANCH" | tee -a "$LOG_FILE"
        else
            git checkout -b "$GIT_BRANCH" || handle_error "Git branch" "Impossible de créer la branche $GIT_BRANCH"
            echo "✅ Création et passage à la nouvelle branche: $GIT_BRANCH" | tee -a "$LOG_FILE"
        fi
    else
        echo "⚠️ Git non disponible, étape de versionning ignorée" | tee -a "$LOG_FILE"
    fi
}

# === 1. TÉLÉCHARGEMENT DES DONNÉES ===
download_data() {
    show_figlet "Download"
    echo "=== ÉTAPE 1: TÉLÉCHARGEMENT DES DONNÉES ===" | tee -a "$LOG_FILE"
    
    # Sources de données ouvertes légères
    # Format: NOM|URL|TYPE_FICHIER
    SOURCES=(
        "METEO_FRANCE|https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/donnees-synop-essentielles-omm/exports/csv?limit=100|CSV"
        "OPEN_METEO|https://open-meteo.com/en/docs/historical-weather-api/stationdata/paris/download.csv?start_date=2023-01-01&end_date=2023-01-31|CSV"
        "DONNEES_ECO|https://www.data.gouv.fr/fr/datasets/r/7fc346b1-1894-44e5-ba96-f73977776260|CSV"
    )
    
    echo "📥 Téléchargement de ${#SOURCES[@]} sources de données" | tee -a "$LOG_FILE"
    
    for SOURCE in "${SOURCES[@]}"; do
        IFS='|' read -r NAME URL TYPE <<< "$SOURCE"
        
        echo "⏳ Téléchargement de $NAME depuis $URL" | tee -a "$LOG_FILE"
        
        OUTPUT_FILE="$RAW_DIR/${NAME}_${DATE}.${TYPE,,}"
        
        # Télécharger avec timeout et retry
        if curl -s -L --retry 3 --max-time 30 -o "$OUTPUT_FILE" "$URL"; then
            # Vérifier si le fichier est vide
            if [ -s "$OUTPUT_FILE" ]; then
                SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
                echo "✅ Téléchargement réussi: $OUTPUT_FILE ($SIZE)" | tee -a "$LOG_FILE"
                
                # Ajouter métadonnées
                echo "# Données téléchargées le: $DATE" > "$OUTPUT_FILE.meta"
                echo "# Source: $URL" >> "$OUTPUT_FILE.meta"
                echo "# Type: $TYPE" >> "$OUTPUT_FILE.meta"
                
                # Pour CSV, aperçu
                if [[ "${TYPE,,}" == "csv" ]]; then
                    echo "📊 Aperçu des données (3 premières lignes):" | tee -a "$LOG_FILE"
                    head -n 3 "$OUTPUT_FILE" | tee -a "$LOG_FILE"
                fi
                
                # Hash pour vérification
                SHA=$(sha256sum "$OUTPUT_FILE" | cut -d' ' -f1)
                echo "$SHA" > "$OUTPUT_FILE.sha256"
            else
                echo "❌ Fichier téléchargé vide: $NAME" | tee -a "$LOG_FILE"
                rm -f "$OUTPUT_FILE"
            fi
        else
            echo "❌ Échec du téléchargement de $NAME" | tee -a "$LOG_FILE"
        fi
    done
    
    # Compter les fichiers téléchargés avec succès
    DOWNLOADED_COUNT=$(find "$RAW_DIR" -type f -name "*_${DATE}.csv" | wc -l)
    
    if [ "$DOWNLOADED_COUNT" -eq 0 ]; then
        handle_error "Téléchargement" "Aucun fichier n'a pu être téléchargé"
    else
        echo "✅ $DOWNLOADED_COUNT fichiers téléchargés avec succès" | tee -a "$LOG_FILE"
    fi
}

# === 2. TRAITEMENT DES DONNÉES ===
process_data() {
    show_figlet "Processing"
    echo "=== ÉTAPE 2: TRAITEMENT DES DONNÉES ===" | tee -a "$LOG_FILE"
    
    echo "🔄 Lancement du script de traitement Python..." | tee -a "$LOG_FILE"
    
    # Créer un script Python temporaire
    TEMP_PYTHON_SCRIPT="$SCRIPT_DIR/temp_process_data.py"
    
    cat > "$TEMP_PYTHON_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import logging
import datetime
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# Configuration
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
REPORT_DIR = DATA_DIR / "reports"
LOG_DIR = BASE_DIR / "logs"

# Configuration du logging
today = datetime.datetime.now().strftime("%Y-%m-%d")
log_file = LOG_DIR / f"process_{today}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Créer les répertoires nécessaires
os.makedirs(PROCESSED_DIR, exist_ok=True)
os.makedirs(REPORT_DIR, exist_ok=True)

def get_files_to_process():
    """Récupère les fichiers CSV du jour."""
    files_to_process = {}
    
    # Rechercher les fichiers CSV du jour
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    for file in RAW_DIR.glob(f"*_{today}.csv"):
        prefix = file.name.split("_")[0]
        files_to_process[prefix] = file
    
    logger.info(f"Fichiers à traiter: {files_to_process}")
    return files_to_process

def process_csv(file_path, output_prefix):
    """Traite un fichier CSV de manière simplifiée."""
    try:
        logger.info(f"Traitement du fichier CSV: {file_path}")
        
        # Charger le CSV - tenter plusieurs séparateurs
        try:
            df = pd.read_csv(file_path, sep=',')
        except:
            try:
                df = pd.read_csv(file_path, sep=';')
            except:
                df = pd.read_csv(file_path, sep=None, engine='python')
        
        # Informations de base
        row_count = len(df)
        col_count = len(df.columns)
        logger.info(f"Dimensions: {row_count} lignes, {col_count} colonnes")
        
        # Conserver seulement les 500 premières lignes pour aller plus vite
        if row_count > 500:
            df = df.head(500)
            logger.info(f"Limitation à 500 lignes pour un traitement plus rapide")
        
        # Détecter les colonnes numériques
        numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
        
        # Statistiques de base pour les colonnes numériques
        if numeric_cols:
            stats_file = PROCESSED_DIR / f"{output_prefix}_stats.csv"
            stats = df[numeric_cols].describe()
            stats.to_csv(stats_file)
            logger.info(f"Statistiques enregistrées dans {stats_file}")
            
            # Générer un graphique pour la première colonne numérique
            if len(numeric_cols) > 0:
                fig, ax = plt.subplots(figsize=(10, 6))
                df[numeric_cols[0]].hist(bins=20, ax=ax)
                ax.set_title(f"Distribution de {numeric_cols[0]}")
                chart_file = REPORT_DIR / f"{output_prefix}_chart.png"
                plt.savefig(chart_file)
                plt.close()
                logger.info(f"Graphique enregistré dans {chart_file}")
        
        # Enregistrer une version nettoyée
        clean_file = PROCESSED_DIR / f"{output_prefix}_clean.csv"
        df.to_csv(clean_file, index=False)
        logger.info(f"Fichier nettoyé enregistré dans {clean_file}")
        
        return {
            "fichier": str(file_path),
            "lignes": row_count,
            "colonnes": col_count,
            "colonnes_numeriques": numeric_cols,
            "fichiers_sortie": [str(stats_file), str(clean_file)]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}")
        return {"erreur": str(e)}

def generate_report(results):
    """Génère un rapport simple en HTML."""
    try:
        # Créer un résumé en HTML
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Rapport de traitement des données - {today}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                h1 {{ color: #2c3e50; }}
                table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
                tr:nth-child(even) {{ background-color: #f9f9f9; }}
                .error {{ color: red; }}
            </style>
        </head>
        <body>
            <h1>Rapport de traitement des données - {today}</h1>
            <p>Nombre de fichiers traités: {len(results)}</p>
            
            <h2>Résultats par fichier</h2>
            <table>
                <tr>
                    <th>Source</th>
                    <th>Lignes</th>
                    <th>Colonnes</th>
                    <th>Statut</th>
                </tr>
        """
        
        for result in results:
            source = result.get("fichier", "").split("/")[-1].split("_")[0]
            if "erreur" in result:
                html += f"""
                <tr class="error">
                    <td>{source}</td>
                    <td>-</td>
                    <td>-</td>
                    <td>Erreur: {result["erreur"]}</td>
                </tr>
                """
            else:
                html += f"""
                <tr>
                    <td>{source}</td>
                    <td>{result.get("lignes", "-")}</td>
                    <td>{result.get("colonnes", "-")}</td>
                    <td>Succès</td>
                </tr>
                """
        
        html += """
            </table>
            
            <h2>Graphiques générés</h2>
            <p>Les graphiques suivants ont été générés :</p>
            <ul>
        """
        
        # Lister les graphiques
        for file in REPORT_DIR.glob(f"*_chart.png"):
            html += f"<li>{file.name}</li>\n"
        
        html += """
            </ul>
            
            <p>Rapport généré automatiquement le """ + datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S") + """</p>
        </body>
        </html>
        """
        
        # Enregistrer le rapport HTML
        report_file = REPORT_DIR / f"rapport_{today}.html"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html)
        
        logger.info(f"Rapport HTML généré: {report_file}")
        return report_file
    
    except Exception as e:
        logger.error(f"Erreur lors de la génération du rapport: {str(e)}")
        return None

def main():
    """Fonction principale."""
    logger.info("=== Début du traitement des données ===")
    
    # Récupérer les fichiers à traiter
    files_to_process = get_files_to_process()
    
    if not files_to_process:
        logger.warning("Aucun fichier à traiter trouvé.")
        return 1
    
    results = []
    
    # Traiter chaque fichier
    for prefix, file_path in files_to_process.items():
        result = process_csv(file_path, prefix)
        results.append(result)
    
    # Générer le rapport
    report_file = generate_report(results)
    
    if report_file:
        logger.info(f"Rapport généré avec succès: {report_file}")
    else:
        logger.error("Échec de la génération du rapport")
    
    logger.info("=== Fin du traitement des données ===")
    
    return 0 if report_file else 1

if __name__ == "__main__":
    sys.exit(main())
EOF
    
    # Rendre le script exécutable
    chmod +x "$TEMP_PYTHON_SCRIPT"
    
    # Exécuter le script
    python3 "$TEMP_PYTHON_SCRIPT"
    PYTHON_EXIT_CODE=$?
    
    # Supprimer le script temporaire
    rm -f "$TEMP_PYTHON_SCRIPT"
    
    # Vérifier le résultat
    if [ $PYTHON_EXIT_CODE -ne 0 ]; then
        handle_error "Traitement" "Le script Python a échoué avec le code d'erreur $PYTHON_EXIT_CODE"
    else
        echo "✅ Traitement des données terminé avec succès" | tee -a "$LOG_FILE"
    fi
}

# === 3. GÉNÉRATION DE RAPPORT ===
generate_summary() {
    show_figlet "Report"
    echo "=== ÉTAPE 3: GÉNÉRATION DU RAPPORT FINAL ===" | tee -a "$LOG_FILE"

    # Compter les fichiers
    RAW_COUNT=$(find "$RAW_DIR" -type f -name "*.$DATE.*" | wc -l)
    PROCESSED_COUNT=$(find "$PROCESSED_DIR" -type f -mtime -1 | wc -l)
    CHART_COUNT=$(find "$REPORT_DIR" -type f -name "*_chart.png" -mtime -1 | wc -l)
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_$DATE.html")
    
    # Créer un résumé
    SUMMARY=$(cat << EOF
==========================================================
           RÉSUMÉ DU TRAITEMENT DE DONNÉES
==========================================================
📅 Date d'exécution: $DATE à $(date '+%H:%M:%S')
👤 Exécuté par: $(whoami)

📊 STATISTIQUES:
----------------------------------------------------------
📥 Fichiers bruts téléchargés:       $RAW_COUNT
🧹 Fichiers traités générés:         $PROCESSED_COUNT
📈 Graphiques générés:               $CHART_COUNT
📄 Rapport principal:                $REPORT_HTML

📂 EMPLACEMENTS:
----------------------------------------------------------
📊 Données brutes:                   $RAW_DIR
📈 Données traitées:                 $PROCESSED_DIR
📑 Rapports et graphiques:           $REPORT_DIR
📝 Logs:                             $LOG_DIR

Pour consulter le rapport complet, ouvrez:
$REPORT_HTML
==========================================================
EOF
)
    
    echo "$SUMMARY" | tee -a "$LOG_FILE"
    
    # Enregistrer le résumé dans un fichier
    SUMMARY_FILE="$REPORT_DIR/resume_$DATE.txt"
    echo "$SUMMARY" > "$SUMMARY_FILE"
    
    echo "✅ Résumé généré et enregistré dans $SUMMARY_FILE" | tee -a "$LOG_FILE"
    
    # Vérifier si le rapport HTML existe
    if [ ! -f "$REPORT_HTML" ]; then
        handle_error "Rapport" "Le rapport HTML n'a pas été généré"
    fi
    
    return 0
}

# === 4. VERSIONNING GIT ===
commit_to_git() {
    show_figlet "Git Update"
    echo "=== ÉTAPE 4: VERSIONNING GIT ===" | tee -a "$LOG_FILE"
    
    if [ "$GIT_ENABLED" = true ]; then
        echo "📦 Ajout des fichiers au suivi Git" | tee -a "$LOG_FILE"
        
        # Ajouter les fichiers au suivi Git
        git add "$LOG_DIR" 
        git add "$DATA_DIR/processed"
        git add "$DATA_DIR/reports"
        git add "$DATA_DIR/raw/*.meta" 
        git add "$DATA_DIR/raw/*.sha256"
        
        # Vérifier s'il y a des changements à committer
        if git diff --staged --quiet; then
            echo "ℹ️ Aucun changement à committer" | tee -a "$LOG_FILE"
        else
            echo "💾 Commit des changements" | tee -a "$LOG_FILE"
            git commit -m "Mise à jour des données: $DATE - Exécution automatique" || {
                echo "⚠️ Erreur lors du commit Git" | tee -a "$LOG_FILE"
            }
            
            # Push vers le dépôt distant (si configuré)
            if git remote | grep -q "origin"; then
                echo "🔄 Push des changements vers le dépôt distant" | tee -a "$LOG_FILE"
                git push origin "$GIT_BRANCH" || {
                    echo "⚠️ Échec du push vers origin" | tee -a "$LOG_FILE"
                }
            else
                echo "ℹ️ Aucun dépôt distant configuré" | tee -a "$LOG_FILE"
            fi
        fi
    else
        echo "⚠️ Git non disponible, étape de versionning ignorée" | tee -a "$LOG_FILE"
    fi
}

# === 5. NOTIFICATION ===
send_notification() {
    show_figlet "Notify"
    echo "=== ÉTAPE 5: ENVOI DE NOTIFICATION ===" | tee -a "$LOG_FILE"
    
    # Compter les fichiers
    RAW_COUNT=$(find "$RAW_DIR" -type f -name "*.$DATE.*" | wc -l)
    PROCESSED_COUNT=$(find "$PROCESSED_DIR" -type f -mtime -1 | wc -l)
    CHART_COUNT=$(find "$REPORT_DIR" -type f -name "*_chart.png" -mtime -1 | wc -l)
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_$DATE.html")
    
    # Créer le message de notification
    NOTIFICATION="
Le traitement automatique des données du $DATE s'est terminé avec succès.

Résumé:
- $RAW_COUNT fichiers de données téléchargés
- $PROCESSED_COUNT fichiers traités générés
- $CHART_COUNT graphiques générés
"
    
    # Envoyer la notification Discord avec le rapport HTML
    NOTIFICATION_TITLE="✅ Traitement des données réussi - $DATE"
    notify_discord_with_report "$NOTIFICATION_TITLE" "$NOTIFICATION" "$REPORT_HTML"
    
    echo "🎮 Notification avec rapport envoyée" | tee -a "$LOG_FILE"
}

# === EXÉCUTION PRINCIPALE ===
main() {
    # Étape 0: Configuration Git (si disponible)
    setup_git
    
    # Étape 1: Télécharger les données
    download_data
    
    # Étape 2: Traiter les données
    process_data
    
    # Étape 3: Générer le rapport final
    generate_summary
    
    # Étape 4: Versionning Git
    commit_to_git
    
    # Étape 5: Envoyer la notification
    send_notification
    
    # Terminer
    show_figlet "Success"
    echo "===== FIN DU PROCESSUS COMPLET: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"
    echo "✅ Processus terminé avec succès"
    echo "📄 Pour plus de détails, consultez les logs: $LOG_FILE"
    echo "📊 Rapport HTML: $REPORT_DIR/rapport_$DATE.html"
    
    return 0
}

# Lancer l'exécution principale
main
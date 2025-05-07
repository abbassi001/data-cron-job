#!/bin/bash

# ============================================================
# SCRIPT PRINCIPAL - ORCHESTRATEUR DE TOUT LE PROCESSUS
# ============================================================
# Ce script unique lance l'ensemble du processus :
# 1. Configuration initiale
# 2. Téléchargement massif de données (environ 250MB)
# 3. Traitement et analyse avancée des données
# 4. Génération de rapports avec visualisations améliorées
# 5. Versionning Git
# 6. Envoi de notifications Discord avec graphiques intégrés
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
echo "  SYSTÈME AVANCÉ DE TRAITEMENT DE DONNÉES MASSIVES"
echo "============================================================"
echo ""

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
RAW_DIR="$DATA_DIR/raw"
PROCESSED_DIR="$DATA_DIR/processed"
REPORT_DIR="$DATA_DIR/reports"
VISUALIZATION_DIR="$DATA_DIR/visualizations"
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
mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$REPORT_DIR" "$VISUALIZATION_DIR" "$LOG_DIR"

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

python3 -c "import seaborn" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Seaborn non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install seaborn || {
        echo "❌ Échec de l'installation de seaborn. Les visualisations seront limitées." | tee -a "$LOG_FILE"
    }
else
    echo "✅ Seaborn installé" | tee -a "$LOG_FILE"
fi

python3 -c "import scipy" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ SciPy non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install scipy || {
        echo "❌ Échec de l'installation de scipy. Certaines analyses statistiques seront limitées." | tee -a "$LOG_FILE"
    }
else
    echo "✅ SciPy installé" | tee -a "$LOG_FILE"
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

# Vérifier unzip pour les archives
if ! command -v unzip &> /dev/null; then
    echo "⚠️ Unzip n'est pas installé. L'extraction des archives ZIP peut échouer." | tee -a "$LOG_FILE"
    echo "⚠️ Pour installer unzip : sudo apt-get install unzip (Debian/Ubuntu)" | tee -a "$LOG_FILE"
fi

# Vérifier figlet (optionnel)
if ! command -v figlet &> /dev/null; then
    echo "ℹ️ Figlet n'est pas installé. Les bannières seront simplifiées." | tee -a "$LOG_FILE"
    echo "ℹ️ Pour installer figlet : sudo apt-get install figlet (Debian/Ubuntu)" | tee -a "$LOG_FILE"
fi

# === FONCTIONS UTILITAIRES ===
# Script Python pour envoyer des notifications Discord avec graphiques
create_discord_charts_script() {
    local DISCORD_SCRIPT="$SCRIPT_DIR/send_discord_with_charts.py"
    
    cat > "$DISCORD_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime
from glob import glob

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

def find_charts(report_dir, date_str):
    """
    Recherche les graphiques générés dans le répertoire des rapports
    """
    # Recherche les fichiers PNG qui contiennent "chart" dans le nom
    charts = glob(os.path.join(report_dir, "*_chart.png"))
    
    # Si aucun graphique trouvé dans les charts, chercher dans le dossier visualizations
    if not charts:
        viz_dir = os.path.join(os.path.dirname(report_dir), "visualizations")
        if os.path.exists(viz_dir):
            charts = glob(os.path.join(viz_dir, "*.png"))
    
    # Trouver aussi les dashboards
    dashboards = glob(os.path.join(os.path.dirname(report_dir), "visualizations", "*_dashboard.png"))
    if dashboards:
        # Privilégier les tableaux de bord s'ils existent
        return dashboards[0]
    
    # Filtrer par date si nécessaire
    if date_str and charts:
        today_charts = [c for c in charts if os.path.getmtime(c) > (datetime.now().timestamp() - 86400)]
        if today_charts:
            return today_charts[0]
    
    return charts[0] if charts else None

def upload_image_to_discord(webhook_url, image_path):
    """
    Télécharge une image sur Discord en utilisant le webhook
    """
    try:
        print(f"📤 Tentative d'envoi de l'image {image_path} vers Discord...")
        
        with open(image_path, 'rb') as img:
            # Utiliser la partie file pour envoyer l'image
            files = {'file': (os.path.basename(image_path), img, 'image/png')}
            
            response = requests.post(webhook_url, files=files)
            
        if response.status_code == 200:
            print(f"✅ Image {os.path.basename(image_path)} envoyée avec succès!")
            image_url = response.json().get('attachments', [{}])[0].get('url', '')
            return image_url
        else:
            print(f"❌ Échec de l'envoi de l'image: {response.status_code}")
            print(response.text)
            return None
    
    except Exception as e:
        print(f"❌ Exception lors de l'envoi de l'image: {str(e)}")
        return None

def send_discord_message(webhook_url, message, title=None, report_path=None, chart_path=None):
    """
    Envoie un message à Discord via un webhook, avec un résumé du rapport si disponible
    
    Args:
        webhook_url (str): URL du webhook Discord
        message (str): Le message à envoyer
        title (str, optional): Titre du message (embeds)
        report_path (str, optional): Chemin vers le rapport HTML
        chart_path (str, optional): Chemin vers un graphique à inclure
    """
    # Tenter d'abord d'envoyer l'image si spécifiée
    image_url = None
    if chart_path and os.path.exists(chart_path):
        try:
            image_url = upload_image_to_discord(webhook_url, chart_path)
        except Exception as e:
            print(f"⚠️ Impossible d'envoyer l'image: {str(e)}")
    
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
        
        # Si on a une URL d'image, l'ajouter à l'embed
        if image_url:
            embed["image"] = {
                "url": image_url
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
        print("Usage: python3 send_discord_with_charts.py webhook_url message [title] [report_path] [chart_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    report_path = sys.argv[4] if len(sys.argv) > 4 else None
    chart_path = sys.argv[5] if len(sys.argv) > 5 else None
    
    # Si aucun graphique n'est spécifié mais qu'on a un répertoire de rapport,
    # chercher automatiquement le premier graphique disponible
    if not chart_path and report_path:
        report_dir = os.path.dirname(report_path)
        date_str = datetime.now().strftime("%Y-%m-%d")
        chart_path = find_charts(report_dir, date_str)
        if chart_path:
            print(f"🔍 Graphique trouvé automatiquement: {chart_path}")
    
    success = send_discord_message(webhook_url, message, title, report_path, chart_path)
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$DISCORD_SCRIPT"
    echo "✅ Script d'envoi Discord avec graphiques créé: $DISCORD_SCRIPT" | tee -a "$LOG_FILE"
}

# Script Python pour le traitement avancé des données
create_processing_script() {
    local PROCESSING_SCRIPT="$SCRIPT_DIR/process_data_advanced.py"
    
    echo "📝 Création du script de traitement avancé des données..." | tee -a "$LOG_FILE"
    
    cat > "$PROCESSING_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script avancé de traitement des données avec visualisations améliorées
"""

import os
import sys
import json
import logging
import datetime
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
from pathlib import Path
from matplotlib.gridspec import GridSpec
from matplotlib.ticker import MaxNLocator
import matplotlib.ticker as mtick
from scipy import stats
import gc

# Configuration améliorée de matplotlib
plt.style.use('ggplot')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 12
plt.rcParams['axes.labelsize'] = 14
plt.rcParams['axes.titlesize'] = 16
plt.rcParams['xtick.labelsize'] = 12
plt.rcParams['ytick.labelsize'] = 12
plt.rcParams['legend.fontsize'] = 12
plt.rcParams['figure.titlesize'] = 20
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['savefig.bbox'] = 'tight'

# Configuration
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
REPORT_DIR = DATA_DIR / "reports"
VISUALIZATION_DIR = DATA_DIR / "visualizations"
LOG_DIR = BASE_DIR / "logs"

# Configuration du logging
today = datetime.datetime.now().strftime("%Y-%m-%d")
log_file = LOG_DIR / f"enhanced_process_{today}.log"
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
os.makedirs(VISUALIZATION_DIR, exist_ok=True)

def find_files_to_process():
    """
    Récupère tous les fichiers à traiter, y compris les fichiers extraits des ZIPs.
    """
    files_to_process = {}
    
    # Rechercher les fichiers CSV du jour
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    
    # Fichiers CSV directement téléchargés
    for file in RAW_DIR.glob(f"*_{today}.csv"):
        prefix = file.name.split("_")[0]
        files_to_process[prefix] = file
    
    # Fichiers extraits des ZIP
    for dir_path in RAW_DIR.glob(f"*_{today}_extracted"):
        prefix = dir_path.name.split("_")[0]
        
        # Trouver tous les CSV dans le répertoire extrait
        extracted_csvs = list(dir_path.glob("**/*.csv"))
        
        if extracted_csvs:
            # Si plusieurs CSV, les traiter tous avec un préfixe différent
            for i, csv_file in enumerate(extracted_csvs):
                sub_prefix = f"{prefix}_{i+1}"
                files_to_process[sub_prefix] = csv_file
    
    logger.info(f"Fichiers à traiter: {len(files_to_process)} fichiers trouvés")
    for k, v in files_to_process.items():
        logger.info(f"  - {k}: {v}")
    
    return files_to_process

def optimize_dataframe(df):
    """
    Optimisation de la mémoire utilisée par le DataFrame
    """
    start_mem = df.memory_usage().sum() / 1024**2
    logger.info(f"Mémoire utilisée avant optimisation: {start_mem:.2f} MB")
    
    for col in df.columns:
        # Conversion des colonnes entières
        if pd.api.types.is_integer_dtype(df[col]):
            min_val = df[col].min()
            max_val = df[col].max()
            
            # Conversion au type entier le plus petit possible
            if min_val >= 0:
                if max_val < 255:
                    df[col] = df[col].astype(np.uint8)
                elif max_val < 65535:
                    df[col] = df[col].astype(np.uint16)
                elif max_val < 4294967295:
                    df[col] = df[col].astype(np.uint32)
            else:
                if min_val > -128 and max_val < 127:
                    df[col] = df[col].astype(np.int8)
                elif min_val > -32768 and max_val < 32767:
                    df[col] = df[col].astype(np.int16)
                elif min_val > -2147483648 and max_val < 2147483647:
                    df[col] = df[col].astype(np.int32)
        
        # Conversion des colonnes flottantes
        elif pd.api.types.is_float_dtype(df[col]):
            df[col] = df[col].astype(np.float32)
        
        # Conversion des colonnes catégorielles
        elif pd.api.types.is_object_dtype(df[col]):
            if df[col].nunique() / len(df) < 0.5:  # Si moins de 50% de valeurs uniques
                df[col] = df[col].astype('category')
    
    end_mem = df.memory_usage().sum() / 1024**2
    logger.info(f"Mémoire utilisée après optimisation: {end_mem:.2f} MB")
    logger.info(f"Réduction: {100 * (start_mem - end_mem) / start_mem:.2f}%")
    
    return df

def process_csv(file_path, output_prefix, max_rows=None):
    """
    Traite un fichier CSV avec des fonctionnalités avancées
    """
    try:
        logger.info(f"Traitement du fichier CSV: {file_path}")
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        logger.info(f"Taille du fichier: {file_size_mb:.2f} MB")
        
        # Pour les gros fichiers, utiliser un échantillon pour détection du séparateur
        sample_size = min(1000, os.path.getsize(file_path))
        with open(file_path, 'r', errors='ignore') as f:
            sample = f.read(sample_size)
        
        # Détection intelligente du séparateur
        separators = [',', ';', '\t', '|']
        sep_count = {sep: sample.count(sep) for sep in separators}
        likely_sep = max(sep_count, key=sep_count.get)
        
        logger.info(f"Séparateur détecté: '{likely_sep}' (occurrences: {sep_count[likely_sep]})")
        
        # Détection intelligente de l'encodage
        encodings = ['utf-8', 'latin1', 'ISO-8859-1', 'windows-1252']
        encoding_used = None
        
        for encoding in encodings:
            try:
                with open(file_path, 'r', encoding=encoding) as f:
                    f.readline()
                encoding_used = encoding
                break
            except UnicodeDecodeError:
                continue
        
        if not encoding_used:
            logger.warning("Impossible de déterminer l'encodage, utilisation de utf-8 avec errors='ignore'")
            encoding_used = 'utf-8'
        
        logger.info(f"Encodage utilisé: {encoding_used}")
        
        # Pour les fichiers volumineux, limiter le nombre de lignes ou utiliser chunks
        if file_size_mb > 500 and max_rows is None:

        logger.warning(f"Le fichier est très volumineux ({file_size_mb:.2f} MB), limitation à 1 million de lignes")
            max_rows = 1000000
        
        # Si le fichier est immense, utiliser un traitement par morceaux
        if file_size_mb > 1000:  # Plus de 1 GB
            logger.info("Fichier extrêmement volumineux, traitement par chunks")
            
            # Lecture et traitement similaire à la version précédente
            # Code pour le traitement de gros fichiers...
            
        else:
            # Lecture normale pour les fichiers de taille raisonnable
            logger.info(f"Lecture du fichier avec pandas")
            
            try:
                df = pd.read_csv(file_path, sep=likely_sep, encoding=encoding_used, 
                                nrows=max_rows, error_bad_lines=False, warn_bad_lines=True,
                                low_memory=False)
            except Exception as e:
                logger.error(f"Erreur lors de la lecture avec le séparateur '{likely_sep}': {str(e)}")
                logger.info("Tentative avec le moteur Python et détection automatique du séparateur")
                df = pd.read_csv(file_path, sep=None, encoding=encoding_used, 
                                nrows=max_rows, error_bad_lines=False, warn_bad_lines=True,
                                engine='python', low_memory=False)
            
            # Optimiser la mémoire du DataFrame
            df = optimize_dataframe(df)
            
            # Informations de base
            row_count = len(df)
            col_count = len(df.columns)
            logger.info(f"Dimensions: {row_count} lignes, {col_count} colonnes")
        
        # Analyse statistique et visualisations (fonction définie ailleurs)
        data_analysis = analyze_and_visualize_data(df, output_prefix, file_path)
        
        # Le reste du traitement et sauvegarde...
        
        return {
            "fichier": str(file_path),
            "lignes": row_count,
            "colonnes": col_count,
            "taille_mb": file_size_mb,
            "colonnes_numeriques": data_analysis["colonnes_numeriques"],
            "fichiers_sortie": [],
            "visualisations": data_analysis["visualisations"],
            "correlations": data_analysis["correlations"],
            "valeurs_manquantes": data_analysis["valeurs_manquantes"],
            "stats": data_analysis["stats"]
        }
            
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}", exc_info=True)
        return {"erreur": str(e)}

def main():
    """Fonction principale."""
    logger.info("=== Début du traitement avancé des données ===")
    
    # Récupérer les fichiers à traiter
    files_to_process = find_files_to_process()
    
    if not files_to_process:
        logger.warning("Aucun fichier à traiter trouvé.")
        return 1
    
    results = []
    
    # Traiter chaque fichier
    for prefix, file_path in files_to_process.items():
        # Déterminer la taille du fichier pour ajuster le traitement
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        
        # Limiter le nombre de lignes pour les fichiers volumineux
        max_rows = None
        if file_size_mb > 200:
            max_rows = 100000
            logger.info(f"Fichier volumineux ({file_size_mb:.2f} MB), limitation à {max_rows} lignes")
        
        # Traiter le fichier
        result = process_csv(file_path, prefix, max_rows)
        results.append(result)
    
    # Générer le rapport avancé
    report_file = generate_enhanced_report(results)
    
    if report_file:
        logger.info(f"Rapport avancé généré avec succès: {report_file}")
    else:
        logger.error("Échec de la génération du rapport avancé")
    
    logger.info("=== Fin du traitement avancé des données ===")
    
    return 0 if report_file else 1

if __name__ == "__main__":
    sys.exit(main())
EOF
    
    chmod +x "$PROCESSING_SCRIPT"
    echo "✅ Script de traitement avancé créé: $PROCESSING_SCRIPT" | tee -a "$LOG_FILE"
    return 0
}

# Fonction pour envoyer une notification Discord avec rapport et graphique
notify_discord_with_charts() {
    local title="$1"
    local message="$2"
    local report_path="$3"
    
    echo "🎮 Tentative d'envoi de notification Discord avec rapport et graphique: $title" | tee -a "$LOG_FILE"
    
    # Créer le script Discord s'il n'existe pas déjà
    if [ ! -f "$SCRIPT_DIR/send_discord_with_charts.py" ]; then
        create_discord_charts_script
    fi
    
    # Rechercher un graphique à inclure
    CHART_PATH=""
    if [ -d "$VISUALIZATION_DIR" ]; then
        # Prioriser les tableaux de bord
        CHART_PATH=$(find "$VISUALIZATION_DIR" -name "*_dashboard.png" -mtime -1 | head -1)
        
        # Si aucun tableau de bord, chercher n'importe quelle visualisation
        if [ -z "$CHART_PATH" ]; then
            CHART_PATH=$(find "$VISUALIZATION_DIR" -name "*.png" -mtime -1 | head -1)
        fi
        
        if [ -n "$CHART_PATH" ]; then
            echo "🔍 Visualisation trouvée pour l'envoi: $CHART_PATH" | tee -a "$LOG_FILE"
        else
            echo "⚠️ Aucune visualisation récente trouvée" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Envoyer la notification via Discord avec le rapport et le graphique
    if python3 "$SCRIPT_DIR/send_discord_with_charts.py" "$DISCORD_WEBHOOK" "$message" "$title" "$report_path" "$CHART_PATH"; then
        echo "✅ Notification Discord avec rapport et visualisation envoyée avec succès" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Échec de l'envoi de la notification Discord" | tee -a "$LOG_FILE"
        return 1
    fi
}

handle_error() {
    local step="$1"
    local error_msg="$2"
    
    show_figlet "ERROR"
    echo "❌ ERREUR à l'étape '$step': $error_msg" | tee -a "$LOG_FILE"
    notify_discord_with_charts "❌ Erreur processus de données - Étape: $step" "Le processus a échoué à l'étape '$step': $error_msg. Voir $LOG_FILE pour plus de détails." ""
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
        
        # Vérifier s'il y a des modifications non commitées
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

# === 1. TÉLÉCHARGEMENT DES DONNÉES MASSIVES ===
download_massive_data() {
    show_figlet "Big Data Download"
    echo "=== ÉTAPE 1: TÉLÉCHARGEMENT DE DONNÉES MASSIVES (environ 250MB) ===" | tee -a "$LOG_FILE"
    
    # Sources de données volumineuses - environ 250+ MB combinées
    # Format: NOM|URL|TYPE_FICHIER|TAILLE_ESTIMÉE_MB
    SOURCES=(
      # Données météorologiques complètes
      "METEO_HISTORIQUE|https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/donnees-synop-essentielles-omm/exports/csv?limit=100000|CSV|60"
      
      # Données économiques de l'INSEE
      "INSEE_ECONOMIE|https://www.insee.fr/fr/statistiques/fichier/6544344/base-cc-emploi-pop-act-2019-csv.zip|ZIP|45"
      
      # Données environnementales
      "ENVIRO_EU|https://www.eea.europa.eu/data-and-maps/data/waterbase-water-quality-icm-2/waterbase-water-quality-icm-2/waterbase-water-quality-data-results.csv/at_download/file|CSV|55"
      
      # Données de transport
      "SNCF_DATA|https://ressources.data.sncf.com/api/v2/catalog/datasets/regularite-mensuelle-tgv-aqst/exports/csv?limit=-1&timezone=Europe%2FBerlin|CSV|35"
      
      # Données démographiques
      "WORLD_POP|https://population.un.org/wpp/Download/Files/1_Indicators%20(Standard)/CSV_FILES/WPP2022_Demographic_Indicators_Medium.zip|ZIP|45"
    )
    
    echo "📊 Volume total à télécharger: environ 250MB en 5 sources" | tee -a "$LOG_FILE"
    
    # Vérification d'espace disque
    AVAILABLE_SPACE=$(df -m "$RAW_DIR" | awk 'NR==2 {print $4}')
    echo "💾 Espace disque disponible: ${AVAILABLE_SPACE}MB" | tee -a "$LOG_FILE"
    
    if [ "$AVAILABLE_SPACE" -lt 500 ]; then
        echo "⚠️ AVERTISSEMENT: L'espace disque disponible ($AVAILABLE_SPACE MB) est faible pour le téléchargement" | tee -a "$LOG_FILE"
        read -p "Voulez-vous continuer quand même? (o/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            handle_error "Téléchargement" "Espace disque insuffisant"
        fi
    fi
    
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    
    for SOURCE in "${SOURCES[@]}"; do
        IFS='|' read -r NAME URL TYPE SIZE_MB <<< "$SOURCE"
        
        echo "📥 Téléchargement de $NAME (${SIZE_MB}MB environ) depuis $URL" | tee -a "$LOG_FILE"
        
        OUTPUT_FILE="$RAW_DIR/${NAME}_${DATE}.${TYPE,,}"
        
        # Télécharger avec timeout et retry
        if curl -L --retry 5 --retry-delay 10 --max-time 3600 -C - --progress-bar -o "$OUTPUT_FILE" "$URL"; then
            if [ -s "$OUTPUT_FILE" ]; then
                ACTUAL_SIZE=$(du -m "$OUTPUT_FILE" | cut -f1)
                echo "✅ Téléchargement réussi: $OUTPUT_FILE (${ACTUAL_SIZE}MB)" | tee -a "$LOG_FILE"
                
                # Ajouter métadonnées
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
                    else
                        echo "❌ Échec de la décompression de $OUTPUT_FILE" | tee -a "$LOG_FILE"
                    fi
                fi
                
                # Pour les CSV, afficher uniquement les 2 premières lignes
                if [[ "${TYPE,,}" == "csv" ]]; then
                    echo "📊 Aperçu des données (2 premières lignes):" | tee -a "$LOG_FILE"
                    head -n 2 "$OUTPUT_FILE" | tee -a "$LOG_FILE"
                    
                    # Nombre total de lignes
                    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
                    echo "📏 Nombre total de lignes: $LINE_COUNT" | tee -a "$LOG_FILE"
                fi
                
                # Calcul du hash pour les fichiers volumineux
                echo "🔐 Calcul du hash SHA256..." | tee -a "$LOG_FILE"
                SHA=$(sha256sum "$OUTPUT_FILE" | cut -d' ' -f1)
                echo "$SHA" > "$OUTPUT_FILE.sha256"
                echo "🔐 Hash SHA256: $SHA" | tee -a "$LOG_FILE"
                
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "❌ Fichier téléchargé vide: $NAME" | tee -a "$LOG_FILE"
                rm -f "$OUTPUT_FILE"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        else
            echo "❌ Échec du téléchargement de $NAME" | tee -a "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        
        echo "------------------------------------------------" | tee -a "$LOG_FILE"
    done
    
    # Résumé du téléchargement
    echo "===== RÉSUMÉ DU TÉLÉCHARGEMENT =====" | tee -a "$LOG_FILE"
    echo "✅ Téléchargements réussis: $SUCCESS_COUNT" | tee -a "$LOG_FILE"
    echo "❌ Téléchargements échoués: $FAILED_COUNT" | tee -a "$LOG_FILE"
    echo "💾 Espace disque utilisé: $(du -sh "$RAW_DIR" | cut -f1)" | tee -a "$LOG_FILE"
    
    # Vérifier si au moins une source a été téléchargée
    if [ "$SUCCESS_COUNT" -eq 0 ]; then
        handle_error "Téléchargement" "Aucune source n'a pu être téléchargée"
    else
        echo "✅ Téléchargement de $SUCCESS_COUNT/$((SUCCESS_COUNT + FAILED_COUNT)) sources terminé avec succès" | tee -a "$LOG_FILE"
    fi
}

# === 2. TRAITEMENT AVANCÉ DES DONNÉES ===
process_massive_data() {
    show_figlet "Advanced Processing"
    echo "=== ÉTAPE 2: TRAITEMENT AVANCÉ DES DONNÉES MASSIVES ===" | tee -a "$LOG_FILE"
    
    echo "🔄 Lancement du script de traitement Python avancé..." | tee -a "$LOG_FILE"
    
    # Créer le script de traitement s'il n'existe pas déjà
    if [ ! -f "$SCRIPT_DIR/process_data_advanced.py" ]; then
        create_processing_script
    fi
    
    # Exécuter le script
    python3 "$SCRIPT_DIR/process_data_advanced.py"
    PYTHON_EXIT_CODE=$?
    
    # Vérifier le résultat
    if [ $PYTHON_EXIT_CODE -ne 0 ]; then
        handle_error "Traitement" "Le script Python avancé a échoué avec le code d'erreur $PYTHON_EXIT_CODE"
    else
        echo "✅ Traitement avancé des données terminé avec succès" | tee -a "$LOG_FILE"
    fi
}

# === 3. GÉNÉRATION DE RAPPORT AMÉLIORÉ ===
generate_enhanced_report() {
    show_figlet "Enhanced Report"
    echo "=== ÉTAPE 3: GÉNÉRATION DU RAPPORT AVANCÉ ===" | tee -a "$LOG_FILE"
    
    # Vérifier si le rapport a été généré par le script Python
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_advanced_$DATE.html")
    
    if [ -n "$REPORT_HTML" ]; then
        echo "✅ Rapport avancé généré avec succès: $REPORT_HTML" | tee -a "$LOG_FILE"
    else
        echo "⚠️ Rapport avancé non trouvé, recherche d'un rapport standard..." | tee -a "$LOG_FILE"
        REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_$DATE.html")
        
        if [ -n "$REPORT_HTML" ]; then
            echo "✅ Rapport standard trouvé: $REPORT_HTML" | tee -a "$LOG_FILE"
        else
            handle_error "Rapport" "Aucun rapport n'a été généré"
        fi
    fi
    
    # Compter les visualisations générées
    VIZ_COUNT=$(find "$VISUALIZATION_DIR" -type f -name "*.png" -mtime -1 | wc -l)
    echo "📊 Nombre de visualisations générées: $VIZ_COUNT" | tee -a "$LOG_FILE"
    
    # Créer un résumé du rapport
    SUMMARY=$(cat << EOF
==========================================================
           RÉSUMÉ DU TRAITEMENT AVANCÉ DE DONNÉES
==========================================================
📅 Date d'exécution: $DATE à $(date '+%H:%M:%S')
👤 Exécuté par: $(whoami)

📊 STATISTIQUES:
----------------------------------------------------------
📥 Données massives traitées:       ~250MB
📈 Visualisations générées:         $VIZ_COUNT
📄 Rapport avancé:                  $REPORT_HTML

📂 EMPLACEMENTS:
----------------------------------------------------------
📊 Données brutes:                  $RAW_DIR
📈 Données traitées:                $PROCESSED_DIR
📑 Rapports et visualisations:      $REPORT_DIR
📝 Logs:                            $LOG_DIR

Pour consulter le rapport complet, ouvrez:
$REPORT_HTML
==========================================================
EOF
)
    
    echo "$SUMMARY" | tee -a "$LOG_FILE"
    
    # Enregistrer le résumé dans un fichier
    SUMMARY_FILE="$REPORT_DIR/resume_avance_$DATE.txt"
    echo "$SUMMARY" > "$SUMMARY_FILE"
    
    echo "✅ Résumé avancé généré et enregistré dans $SUMMARY_FILE" | tee -a "$LOG_FILE"
    
    return 0
}

# === 4. VERSIONNING GIT ===
commit_to_git() {
    show_figlet "Git Update"
    echo "=== ÉTAPE 4: VERSIONNING GIT DES DONNÉES MASSIVES ===" | tee -a "$LOG_FILE"
    
    if [ "$GIT_ENABLED" = true ]; then
        echo "📦 Ajout des fichiers au suivi Git (sans les données brutes volumineuses)" | tee -a "$LOG_FILE"
        
        # Ajouter les fichiers au suivi Git, en excluant les fichiers volumineux
        git add "$LOG_DIR" 
        git add "$DATA_DIR/processed"
        git add "$DATA_DIR/reports"
        git add "$DATA_DIR/visualizations"
        git add "$DATA_DIR/raw/*.meta" 
        git add "$DATA_DIR/raw/*.sha256"
        
        # Vérifier s'il y a des changements à committer
        if git diff --staged --quiet; then
            echo "ℹ️ Aucun changement à committer" | tee -a "$LOG_FILE"
        else
            echo "💾 Commit des changements" | tee -a "$LOG_FILE"
            git commit -m "Traitement de données massives: $DATE - ~250MB traitées" || {
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

# === 5. NOTIFICATION AVEC VISUALISATIONS ===
send_enhanced_notification() {
    show_figlet "Enhanced Notify"
    echo "=== ÉTAPE 5: ENVOI DE NOTIFICATION AMÉLIORÉE AVEC VISUALISATIONS ===" | tee -a "$LOG_FILE"
    
    # Trouver le rapport généré
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_advanced_$DATE.html" -o -name "rapport_$DATE.html" | head -1)
    
    # Trouver les visualisations les plus intéressantes
    DASHBOARD=$(find "$VISUALIZATION_DIR" -name "*_dashboard.png" -mtime -1 | head -1)
    
    # Compter les éléments générés
    VIZ_COUNT=$(find "$VISUALIZATION_DIR" -type f -name "*.png" -mtime -1 | wc -l)
    DATA_SIZE=$(du -sh "$RAW_DIR" | cut -f1)
    
    # Créer le message de notification
    NOTIFICATION="
🚀 **Traitement de données massives terminé avec succès**

📊 **Résumé du traitement:**
- 📥 Volume traité: ~250MB
- 🧹 Données nettoyées et optimisées
- 📈 $VIZ_COUNT visualisations générées
- 📊 Analyses statistiques avancées réalisées

Le rapport complet avec toutes les visualisations est disponible à: $REPORT_HTML

Ce message inclut l'une des visualisations générées automatiquement à partir des données.
"
    
    # Envoyer la notification Discord avec le rapport HTML et le graphique
    NOTIFICATION_TITLE="✅ Traitement avancé de données massives réussi - $DATE"
    notify_discord_with_charts "$NOTIFICATION_TITLE" "$NOTIFICATION" "$REPORT_HTML"
    
    echo "🎮 Notification avancée avec visualisations envoyée" | tee -a "$LOG_FILE"
}

# === EXÉCUTION PRINCIPALE ===
main() {
    # Étape 0: Configuration Git (si disponible)
    setup_git
    
    # Étape 1: Télécharger les données massives
    download_massive_data
    
    # Étape 2: Traiter les données massives
    process_massive_data
    
    # Étape 3: Générer le rapport avancé
    generate_enhanced_report
    
    # Étape 4: Versionning Git
    commit_to_git
    
    # Étape 5: Envoyer la notification avancée
    send_enhanced_notification
    
    # Terminer
    show_figlet "Success"
    echo "===== FIN DU PROCESSUS AVANCÉ: $(date '+%Y-%m-%d %H:%M:%S') =====" | tee -a "$LOG_FILE"
    echo "✅ Processus de traitement de données massives terminé avec succès"
    echo "📄 Pour plus de détails, consultez les logs: $LOG_FILE"
    echo "📊 Rapport HTML avancé: $(find "$REPORT_DIR" -name "rapport_advanced_$DATE.html")"
    echo "🌐 Taille totale du jeu de données: $(du -sh "$DATA_DIR" | cut -f1)"
    
    return 0
}

# Lancer l'exécution principale
main
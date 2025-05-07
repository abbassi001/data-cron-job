#!/bin/bash

# ============================================================
# SCRIPT PRINCIPAL - ORCHESTRATEUR DE TOUT LE PROCESSUS
# ============================================================
# Ce script unique lance l'ensemble du processus :
# 1. Configuration initiale
# 2. Téléchargement massif de données
# 3. Traitement et analyse avancée des données
# 4. Génération de rapports avec visualisations
# 5. Versionning Git
# 6. Envoi de notifications Discord avec graphiques
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
EMAIL="abbassiadamou55@gmail.com" # À modifier avec votre email

# Configuration Discord - URL du webhook (à modifier avec votre URL)
DISCORD_WEBHOOK="https://discord.com/api/webhooks/VOTRE_WEBHOOK_ICI"

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

python3 -c "import requests" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Requests non installé. Installation en cours..." | tee -a "$LOG_FILE"
    pip install requests || {
        echo "❌ Échec de l'installation de requests. Les notifications Discord ne fonctionneront pas." | tee -a "$LOG_FILE"
    }
else
    echo "✅ Requests installé" | tee -a "$LOG_FILE"
fi

# === FONCTIONS UTILITAIRES ===
# Script Python pour envoyer des notifications Discord avec graphiques
create_discord_script() {
    local DISCORD_SCRIPT="$SCRIPT_DIR/send_discord_with_charts.py"
    
    echo "📝 Création du script d'envoi Discord..." | tee -a "$LOG_FILE"
    
    cat > "$DISCORD_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime
from glob import glob
from pathlib import Path

def find_charts(report_dir):
    """
    Recherche les graphiques générés dans le répertoire des rapports
    """
    # Recherche tous les types de graphiques possibles
    all_charts = []
    
    # Chercher dans le répertoire des rapports
    all_charts.extend(list(Path(report_dir).glob("*_chart.png")))
    all_charts.extend(list(Path(report_dir).glob("*_correlation_heatmap.png")))
    all_charts.extend(list(Path(report_dir).glob("*_*_histogram.png"))) 
    all_charts.extend(list(Path(report_dir).glob("*_*_timeline.png")))
    all_charts.extend(list(Path(report_dir).glob("*_*_boxplot.png")))
    
    # Chercher aussi dans le répertoire des visualisations
    viz_dir = Path(os.path.dirname(report_dir)) / "visualizations"
    if viz_dir.exists():
        all_charts.extend(list(viz_dir.glob("*.png")))
        
        # Priorité aux dashboards s'ils existent
        dashboards = list(viz_dir.glob("*_dashboard.png"))
        if dashboards:
            return str(dashboards[0])
    
    # Retourner le premier graphique trouvé, s'il y en a
    if all_charts:
        return str(all_charts[0])
    return None

def send_discord_message(webhook_url, message, title=None, image_path=None):
    """
    Envoie un message à Discord via un webhook, avec une image si fournie
    """
    # Préparer le payload de base
    payload = {
        "content": message,
        "username": "Data Processing Bot"
    }
    
    # Envoyer l'image si spécifiée
    files = {}
    if image_path and os.path.exists(image_path):
        try:
            files = {'file': (os.path.basename(image_path), open(image_path, 'rb'), 'image/png')}
            print(f"📊 Envoi de l'image: {image_path}")
        except Exception as e:
            print(f"⚠️ Erreur lors de la lecture de l'image: {str(e)}")
            files = {}
    
    try:
        if files:
            # Si on envoie une image, on utilise multipart/form-data
            response = requests.post(
                webhook_url,
                data={"payload_json": json.dumps(payload)},
                files=files
            )
        else:
            # Sinon, on utilise application/json
            response = requests.post(
                webhook_url,
                json=payload
            )
        
        if response.status_code in [200, 204]:
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
        print("Usage: python3 send_discord_with_charts.py webhook_url message [image_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    image_path = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Si aucune image n'est spécifiée mais que le répertoire des rapports est défini dans l'environnement
    if not image_path and "REPORT_DIR" in os.environ:
        image_path = find_charts(os.environ["REPORT_DIR"])
        if image_path:
            print(f"🔍 Image trouvée automatiquement: {image_path}")
    
    success = send_discord_message(webhook_url, message, None, image_path)
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$DISCORD_SCRIPT"
    echo "✅ Script d'envoi Discord créé: $DISCORD_SCRIPT" | tee -a "$LOG_FILE"
}

# Fonction pour envoyer une notification Discord avec rapport et graphique
notify_discord() {
    local message="$1"
    local title="$2"
    local image_path="$3"
    
    echo "🎮 Tentative d'envoi de notification Discord: $message" | tee -a "$LOG_FILE"
    
    # Créer le script Discord s'il n'existe pas déjà
    if [ ! -f "$SCRIPT_DIR/send_discord_with_charts.py" ]; then
        create_discord_script
    fi
    
    # Si aucune image spécifiée, chercher automatiquement
    if [ -z "$image_path" ]; then
        image_path=$(find "$REPORT_DIR" -name "*_correlation_heatmap.png" -o -name "*_chart.png" -o -name "*_histogram.png" -type f -mtime -1 | head -1)
        
        if [ -n "$image_path" ]; then
            echo "🔍 Visualisation trouvée pour Discord: $image_path" | tee -a "$LOG_FILE"
        else
            echo "⚠️ Aucune visualisation récente trouvée" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Exporter la variable REPORT_DIR pour le script Python
    export REPORT_DIR
    
    # Envoyer la notification via le script Python
    if python3 "$SCRIPT_DIR/send_discord_with_charts.py" "$DISCORD_WEBHOOK" "$message" "$image_path"; then
        echo "✅ Message Discord envoyé avec succès!" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Échec de l'envoi du message Discord" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Fonction pour gérer les erreurs et envoyer des notifications
handle_error() {
    local step="$1"
    local error_msg="$2"
    
    show_figlet "ERROR"
    echo "❌ ERREUR à l'étape '$step': $error_msg" | tee -a "$LOG_FILE"
    
    # Envoyer notification Discord
    notify_discord "❌ Erreur processus de données - Étape: $step\nLe processus a échoué à l'étape '$step': $error_msg. Voir $LOG_FILE pour plus de détails."
    
    exit 1
}

# Script Python pour le traitement avancé des données
create_processing_script() {
    local PROCESSING_SCRIPT="$SCRIPT_DIR/process_data_advanced.py"
    
    echo "📝 Création du script de traitement avancé des données..." | tee -a "$LOG_FILE"
    
    cat > "$PROCESSING_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script avancé de traitement des données ouvertes téléchargées.
Version améliorée avec meilleure gestion des gros fichiers et visualisations avancées.
"""

import os
import sys
import logging
import datetime
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

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
log_file = LOG_DIR / f"process_advanced_{today}.log"
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

def get_latest_files():
    """Récupère les fichiers les plus récents pour chaque source de données."""
    latest_files = {}
    
    # Rechercher les fichiers CSV du jour
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    for file in RAW_DIR.glob(f"*_{today}.csv"):
        prefix = file.name.split("_")[0]
        latest_files[prefix] = file
    
    logger.info(f"Fichiers à traiter: {latest_files}")
    return latest_files

def process_csv(file_path, output_prefix):
    """Traite un fichier CSV avec des fonctionnalités avancées."""
    try:
        logger.info(f"Traitement du fichier CSV: {file_path}")
        
        # Vérifier la taille du fichier
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        logger.info(f"Taille du fichier: {file_size_mb:.2f} MB")
        
        # Stratégie adaptative selon la taille du fichier
        if file_size_mb > 100:
            logger.warning(f"Le fichier est très volumineux ({file_size_mb:.2f} MB), limitation à 1 million de lignes")
            # Échantillonnage pour gros fichiers
            chunk_size = 1000  # Taille de chaque chunk
            total_rows = 0
            chunks = []
            
            # Charger les données par chunks
            for chunk in pd.read_csv(file_path, chunksize=chunk_size, sep=None, engine='python'):
                chunks.append(chunk)
                total_rows += len(chunk)
                if total_rows >= 1000000:  # Limiter à 1 million de lignes
                    break
            
            df = pd.concat(chunks, ignore_index=True)
            logger.info(f"Chargement de {len(df)} lignes par échantillonnage")
        else:
            # Pour fichiers plus petits, chargement complet
            try:
                df = pd.read_csv(file_path, sep=',')
            except:
                try:
                    df = pd.read_csv(file_path, sep=';')
                except:
                    df = pd.read_csv(file_path, sep=None, engine='python')
            
            # Limitation pour fichiers moyens
            if len(df) > 10000:
                df = df.sample(n=10000, random_state=42)
                logger.info(f"Échantillonnage aléatoire de 10000 lignes")
        
        # Informations de base
        row_count = len(df)
        col_count = len(df.columns)
        logger.info(f"Dimensions: {row_count} lignes, {col_count} colonnes")
        
        # Détecter les types de colonnes
        numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
        categorical_cols = df.select_dtypes(include=['object', 'category']).columns.tolist()
        date_cols = []
        
        # Tenter de convertir des colonnes en dates
        for col in categorical_cols[:]:
            try:
                df[col] = pd.to_datetime(df[col])
                categorical_cols.remove(col)
                date_cols.append(col)
                logger.info(f"Colonne convertie en date: {col}")
            except:
                pass
        
        # Statistiques avancées pour les colonnes numériques
        if numeric_cols:
            stats_file = PROCESSED_DIR / f"{output_prefix}_stats.csv"
            stats = df[numeric_cols].describe(percentiles=[0.05, 0.25, 0.5, 0.75, 0.95])
            stats.to_csv(stats_file)
            logger.info(f"Statistiques détaillées enregistrées dans {stats_file}")
            
            # Corrélations
            if len(numeric_cols) > 1:
                corr_file = PROCESSED_DIR / f"{output_prefix}_correlations.csv"
                corr = df[numeric_cols].corr()
                corr.to_csv(corr_file)
                logger.info(f"Matrice de corrélation enregistrée dans {corr_file}")
                
                # Visualisation des corrélations
                plt.figure(figsize=(12, 10))
                sns.heatmap(corr, annot=True, cmap='coolwarm', vmin=-1, vmax=1, fmt='.2f')
                plt.title(f"Matrice de corrélation - {output_prefix}")
                corr_chart_file = REPORT_DIR / f"{output_prefix}_correlation_heatmap.png"
                plt.savefig(corr_chart_file, bbox_inches='tight')
                plt.close()
                logger.info(f"Heatmap de corrélation enregistré dans {corr_chart_file}")
            
            # Visualisations plus avancées
            for col in numeric_cols[:3]:  # Limiter à 3 colonnes pour éviter trop de graphiques
                # Histogramme avec KDE
                plt.figure(figsize=(12, 6))
                sns.histplot(df[col], kde=True)
                plt.title(f"Distribution de {col}")
                hist_file = REPORT_DIR / f"{output_prefix}_{col}_histogram.png"
                plt.savefig(hist_file)
                plt.close()
                logger.info(f"Histogramme enregistré pour {col}")
                
                # Boxplot
                plt.figure(figsize=(10, 6))
                sns.boxplot(x=df[col])
                plt.title(f"Boxplot de {col}")
                box_file = REPORT_DIR / f"{output_prefix}_{col}_boxplot.png"
                plt.savefig(box_file)
                plt.close()
        
        # Pour les colonnes catégorielles
        if categorical_cols:
            for col in categorical_cols[:3]:  # Limiter à 3 colonnes
                # Compter les valeurs
                value_counts = df[col].value_counts().head(20)  # Top 20 valeurs
                
                # Barplot
                plt.figure(figsize=(12, 8))
                sns.barplot(x=value_counts.index, y=value_counts.values)
                plt.title(f"Top 20 valeurs pour {col}")
                plt.xticks(rotation=45, ha='right')
                cat_file = REPORT_DIR / f"{output_prefix}_{col}_categories.png"
                plt.savefig(cat_file, bbox_inches='tight')
                plt.close()
        
        # Pour les colonnes de date
        if date_cols:
            for col in date_cols:
                # Agréger par mois
                try:
                    df['month'] = df[col].dt.to_period('M')
                    monthly_counts = df.groupby('month').size()
                    
                    # Tracer l'évolution temporelle
                    plt.figure(figsize=(12, 6))
                    monthly_counts.plot(kind='line', marker='o')
                    plt.title(f"Évolution temporelle par mois ({col})")
                    time_file = REPORT_DIR / f"{output_prefix}_{col}_timeline.png"
                    plt.savefig(time_file)
                    plt.close()
                    logger.info(f"Graphique temporel enregistré pour {col}")
                except Exception as e:
                    logger.warning(f"Impossible de créer le graphique temporel pour {col}: {str(e)}")
        
        # Enregistrer une version nettoyée
        clean_file = PROCESSED_DIR / f"{output_prefix}_clean.csv"
        df.to_csv(clean_file, index=False)
        logger.info(f"Fichier nettoyé enregistré dans {clean_file}")
        
        return {
            "fichier": str(file_path),
            "lignes": row_count,
            "colonnes": col_count,
            "colonnes_numeriques": numeric_cols,
            "colonnes_categorielles": categorical_cols,
            "colonnes_dates": date_cols,
            "fichiers_sortie": [str(stats_file), str(clean_file)]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}")
        return {"erreur": str(e)}

def generate_report(results):
    """Génère un rapport amélioré en HTML."""
    try:
        # Créer un résumé en HTML
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Rapport avancé de traitement des données - {today}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; color: #333; }}
                h1 {{ color: #2c3e50; text-align: center; margin-bottom: 30px; }}
                h2 {{ color: #3498db; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 10px; }}
                h3 {{ color: #2980b9; }}
                table {{ border-collapse: collapse; width: 100%; margin: 20px 0; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }}
                th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
                th {{ background-color: #f2f2f2; color: #333; font-weight: bold; }}
                tr:nth-child(even) {{ background-color: #f9f9f9; }}
                tr:hover {{ background-color: #f1f1f1; }}
                .error {{ color: #e74c3c; }}
                .success {{ color: #27ae60; }}
                .chart-container {{ display: flex; flex-wrap: wrap; justify-content: space-around; margin: 20px 0; }}
                .chart {{ margin: 10px; border: 1px solid #ddd; padding: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); max-width: 45%; }}
                .chart img {{ max-width: 100%; height: auto; }}
                .summary {{ background-color: #f8f9fa; border-left: 5px solid #3498db; padding: 15px; margin: 20px 0; }}
                footer {{ text-align: center; margin-top: 50px; font-size: 0.9em; color: #7f8c8d; border-top: 1px solid #eee; padding-top: 20px; }}
            </style>
        </head>
        <body>
            <h1>Rapport avancé de traitement des données - {today}</h1>
            
            <div class="summary">
                <p><strong>Nombre de fichiers traités:</strong> {len(results)}</p>
                <p><strong>Date du traitement:</strong> {datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S")}</p>
                <p><strong>Statut général:</strong> {'Succès' if not any('erreur' in r for r in results) else 'Attention: Certains fichiers ont des erreurs'}</p>
            </div>
            
            <h2>Résultats détaillés par fichier</h2>
            <table>
                <tr>
                    <th>Source</th>
                    <th>Lignes</th>
                    <th>Colonnes</th>
                    <th>Colonnes numériques</th>
                    <th>Colonnes catégorielles</th>
                    <th>Colonnes de dates</th>
                    <th>Statut</th>
                </tr>
        """
        
        for result in results:
            source = Path(result.get("fichier", "")).stem.split("_")[0] if "fichier" in result else "Inconnu"
            if "erreur" in result:
                html += f"""
                <tr>
                    <td>{source}</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td class="error">Erreur: {result["erreur"]}</td>
                </tr>
                """
            else:
                html += f"""
                <tr>
                    <td>{source}</td>
                    <td>{result.get("lignes", "-")}</td>
                    <td>{result.get("colonnes", "-")}</td>
                    <td>{len(result.get("colonnes_numeriques", []))}</td>
                    <td>{len(result.get("colonnes_categorielles", []))}</td>
                    <td>{len(result.get("colonnes_dates", []))}</td>
                    <td class="success">Succès</td>
                </tr>
                """
        
        html += """
            </table>
            
            <h2>Visualisations générées</h2>
            <p>Voici les graphiques générés pendant l'analyse:</p>
            <div class="chart-container">
        """
        
        # Lister et inclure les graphiques directement
        charts = list(REPORT_DIR.glob(f"*_correlation_heatmap.png"))
        charts.extend(list(REPORT_DIR.glob(f"*_*_histogram.png")))
        charts.extend(list(REPORT_DIR.glob(f"*_*_timeline.png")))
        charts.extend(list(REPORT_DIR.glob(f"*_*_boxplot.png")))
        charts.extend(list(REPORT_DIR.glob(f"*_chart.png")))
        
        for chart_file in charts:
            chart_name = chart_file.name
            source = chart_name.split("_")[0]
            
            html += f"""
            <div class="chart">
                <h3>{source} - {chart_name}</h3>
                <img src="{chart_name}" alt="{chart_name}" />
            </div>
            """
        
        html += """
            </div>
            
            <footer>
                <p>Rapport généré automatiquement par le système avancé de traitement de données le """ + datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S") + """</p>
            </footer>
        </body>
        </html>
        """
        
        # Enregistrer le rapport HTML
        report_file = REPORT_DIR / f"rapport_avance_{today}.html"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html)
        
        logger.info(f"Rapport HTML avancé généré: {report_file}")
        return report_file
    
    except Exception as e:
logger.error(f"Erreur lors de la génération du rapport avancé: {str(e)}")
        return None

def main():
    """Fonction principale."""
    logger.info("=== Début du traitement avancé des données ===")
    
    # Récupérer les fichiers les plus récents
    latest_files = get_latest_files()
    
    if not latest_files:
        logger.warning("Aucun fichier à traiter trouvé.")
        return 1
    
    results = []
    
    # Traiter chaque fichier
    for prefix, file_path in latest_files.items():
        result = process_csv(file_path, prefix)
        results.append(result)
    
    # Générer le rapport
    report_file = generate_report(results)
    
    if report_file:
        logger.info(f"Traitement avancé terminé avec succès. Rapport: {report_file}")
    else:
        logger.error("Échec de la génération du rapport avancé")
        return 1
    
    logger.info("=== Fin du traitement avancé des données ===")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF
    
    chmod +x "$PROCESSING_SCRIPT"
    echo "✅ Script de traitement avancé créé: $PROCESSING_SCRIPT" | tee -a "$LOG_FILE"
    return 0
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

# === 3. GÉNÉRATION DE RAPPORT ===
generate_summary() {
    show_figlet "Report"
    echo "=== ÉTAPE 3: GÉNÉRATION DU RAPPORT AVANCÉ ===" | tee -a "$LOG_FILE"
    
    # Chercher d'abord le rapport avancé
    echo "Recherche du rapport avancé..." | tee -a "$LOG_FILE"
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_avance_$DATE.html")

    # Si le rapport avancé n'est pas trouvé, chercher le rapport standard
    if [ -z "$REPORT_HTML" ] || [ ! -f "$REPORT_HTML" ]; then
        echo "⚠️ Rapport avancé non trouvé, recherche d'un rapport standard..." | tee -a "$LOG_FILE"
        REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_$DATE.html")
    fi

    # Afficher le contenu du répertoire pour le débogage
    echo "📂 Contenu du répertoire des rapports:" | tee -a "$LOG_FILE"
    ls -la "$REPORT_DIR" | tee -a "$LOG_FILE"

    # Vérifier si un rapport a été trouvé
    if [ -z "$REPORT_HTML" ] || [ ! -f "$REPORT_HTML" ]; then
        handle_error "Rapport" "Aucun rapport n'a été généré"
    else
        echo "✅ Rapport trouvé: $REPORT_HTML" | tee -a "$LOG_FILE"
    fi
    
    # Compter les fichiers
    RAW_COUNT=$(find "$RAW_DIR" -type f -name "*.$DATE.*" | wc -l)
    PROCESSED_COUNT=$(find "$PROCESSED_DIR" -type f -mtime -1 | wc -l)
    CHART_COUNT=$(find "$REPORT_DIR" -type f -name "*.png" -mtime -1 | wc -l)
    
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
    echo "=== ÉTAPE 5: ENVOI DE NOTIFICATION AVEC VISUALISATIONS ===" | tee -a "$LOG_FILE"
    
    # Compter les fichiers
    RAW_COUNT=$(find "$RAW_DIR" -type f -name "*.$DATE.*" | wc -l)
    PROCESSED_COUNT=$(find "$PROCESSED_DIR" -type f -mtime -1 | wc -l)
    CHART_COUNT=$(find "$REPORT_DIR" -type f -name "*.png" -mtime -1 | wc -l)
    
    # Créer le message de notification
    local MESSAGE="
✅ Le traitement de données du $DATE s'est terminé avec succès.

Résumé:
- $RAW_COUNT fichiers de données téléchargés
- $PROCESSED_COUNT fichiers traités générés
- $CHART_COUNT graphiques générés
    
Le rapport complet est disponible dans: $REPORT_DIR
"
    
    # Envoyer notification Discord
    notify_discord "$MESSAGE" "Traitement de données réussi - $DATE"
    
    echo "📧 Notification envoyée" | tee -a "$LOG_FILE"
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
    echo "📊 Rapport HTML: $REPORT_DIR/rapport_avance_$DATE.html"
    
    return 0
}

# Lancer l'exécution principale
main
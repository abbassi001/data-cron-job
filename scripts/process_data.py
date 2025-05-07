#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script simplifié de traitement des données ouvertes téléchargées.
"""

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
            <p>Les graphiques suivants ont été générés dans le dossier reports:</p>
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
    
    logger.info("=== Fin du traitement des données ===")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
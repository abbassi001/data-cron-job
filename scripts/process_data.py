#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script de traitement des données ouvertes téléchargées.
Transforme les données brutes en fichiers traités et génère des statistiques.
"""

import os
import sys
import json
import csv
import glob
import logging
import datetime
import hashlib
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
    
    # Pour chaque type de fichier dans le répertoire raw
    for file_type in ["CSV", "JSON"]:
        pattern = str(RAW_DIR / f"*_{file_type.lower()}")
        files = glob.glob(pattern)
        
        # Grouper par préfixe (nom de la source)
        grouped_files = {}
        for file in files:
            base_name = os.path.basename(file)
            prefix = base_name.split("_")[0]  # Récupérer le nom de la source (COVID19_FR, etc.)
            
            if prefix not in grouped_files:
                grouped_files[prefix] = []
            
            grouped_files[prefix].append(file)
        
        # Prendre le fichier le plus récent pour chaque préfixe
        for prefix, file_list in grouped_files.items():
            latest_file = max(file_list, key=os.path.getctime)
            latest_files[prefix] = latest_file
    
    logger.info(f"Fichiers les plus récents trouvés: {latest_files}")
    return latest_files

def process_csv(file_path, output_prefix):
    """Traite un fichier CSV."""
    try:
        logger.info(f"Traitement du fichier CSV: {file_path}")
        
        # Charger le CSV
        df = pd.read_csv(file_path, sep=None, engine='python')
        
        # Informations de base
        row_count = len(df)
        col_count = len(df.columns)
        logger.info(f"Dimensions: {row_count} lignes, {col_count} colonnes")
        
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
        
        # Supprimer les doublons
        df_clean = df.drop_duplicates()
        
        # Remplacer les valeurs manquantes par NaN
        df_clean = df_clean.fillna(pd.NA)
        
        df_clean.to_csv(clean_file, index=False)
        logger.info(f"Fichier nettoyé enregistré dans {clean_file}")
        
        return {
            "file": file_path,
            "rows": row_count,
            "columns": col_count,
            "numeric_columns": numeric_cols,
            "output_files": [str(stats_file), str(clean_file)]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}")
        return {"error": str(e)}

def process_json(file_path, output_prefix):
    """Traite un fichier JSON."""
    try:
        logger.info(f"Traitement du fichier JSON: {file_path}")
        
        # Charger le JSON
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        # Enregistrer une version formatée
        formatted_file = PROCESSED_DIR / f"{output_prefix}_formatted.json"
        with open(formatted_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        # Analyse basique de la structure
        if isinstance(data, dict):
            keys = list(data.keys())
            analysis = {
                "type": "dict",
                "keys": keys,
                "nested_objects": {}
            }
            
            # Analyser le premier niveau
            for key in keys:
                if isinstance(data[key], list) and len(data[key]) > 0:
                    analysis["nested_objects"][key] = {
                        "type": "list",
                        "length": len(data[key])
                    }
                    
                    # Analyser le premier élément de la liste si c'est un dict
                    if isinstance(data[key][0], dict):
                        analysis["nested_objects"][key]["first_item_keys"] = list(data[key][0].keys())
        
        elif isinstance(data, list):
            analysis = {
                "type": "list",
                "length": len(data)
            }
            
            if len(data) > 0 and isinstance(data[0], dict):
                analysis["first_item_keys"] = list(data[0].keys())
        
        # Enregistrer l'analyse
        analysis_file = PROCESSED_DIR / f"{output_prefix}_analysis.json"
        with open(analysis_file, 'w') as f:
            json.dump(analysis, f, indent=2)
        
        logger.info(f"Analyse JSON enregistrée dans {analysis_file}")
        
        # Tenter de convertir en CSV si possible
        if isinstance(data, list) and all(isinstance(item, dict) for item in data):
            try:
                df = pd.json_normalize(data)
                csv_file = PROCESSED_DIR / f"{output_prefix}_converted.csv"
                df.to_csv(csv_file, index=False)
                logger.info(f"JSON converti en CSV: {csv_file}")
            except Exception as e:
                logger.warning(f"Impossible de convertir le JSON en CSV: {str(e)}")
        
        return {
            "file": file_path,
            "analysis": analysis,
            "output_files": [str(formatted_file), str(analysis_file)]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier JSON {file_path}: {str(e)}")
        return {"error": str(e)}

def generate_report(results):
    """Génère un rapport global de traitement."""
    report = {
        "timestamp": datetime.datetime.now().isoformat(),
        "files_processed": len(results),
        "results": results
    }
    
    report_file = REPORT_DIR / f"report_{today}.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    
    logger.info(f"Rapport global enregistré dans {report_file}")
    return report_file

def main():
    """Fonction principale."""
    logger.info("=== Début du traitement des données ===")
    
    # Récupérer les fichiers les plus récents
    latest_files = get_latest_files()
    
    results = []
    
    # Traiter chaque fichier
    for prefix, file_path in latest_files.items():
        if file_path.endswith(".csv"):
            result = process_csv(file_path, prefix)
        elif file_path.endswith(".json"):
            result = process_json(file_path, prefix)
        else:
            logger.warning(f"Type de fichier non pris en charge: {file_path}")
            continue
        
        results.append(result)
    
    # Générer le rapport global
    report_file = generate_report(results)
    
    logger.info("=== Fin du traitement des données ===")
    
    # Calculer un hash du rapport pour Git
    with open(report_file, 'rb') as f:
        report_hash = hashlib.sha256(f.read()).hexdigest()
    
    logger.info(f"Hash du rapport: {report_hash}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
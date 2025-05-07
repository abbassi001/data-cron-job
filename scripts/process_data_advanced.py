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
                                nrows=max_rows, on_bad_lines='skip', warn_bad_lines=True,
                                low_memory=False)
            except Exception as e:
                logger.error(f"Erreur lors de la lecture avec le séparateur '{likely_sep}': {str(e)}")
                logger.info("Tentative avec le moteur Python et détection automatique du séparateur")
                df = pd.read_csv(file_path, sep=None, encoding=encoding_used, 
                                nrows=max_rows, on_bad_lines='skip', warn_bad_lines=True,
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

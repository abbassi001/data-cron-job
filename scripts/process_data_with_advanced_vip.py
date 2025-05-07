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
            
            # Lire les en-têtes pour obtenir les noms de colonnes
            header_df = pd.read_csv(file_path, sep=likely_sep, encoding=encoding_used, 
                                    nrows=0, error_bad_lines=False, warn_bad_lines=True)
            columns = header_df.columns.tolist()
            
            # Détecter les colonnes numériques sur un échantillon
            sample_df = pd.read_csv(file_path, sep=likely_sep, encoding=encoding_used, 
                                    nrows=10000, error_bad_lines=False, warn_bad_lines=True)
            numeric_cols = sample_df.select_dtypes(include=['number']).columns.tolist()
            
            # Initialiser les statistiques
            stats_data = {col: {'sum': 0, 'sum_sq': 0, 'count': 0, 'min': float('inf'), 'max': float('-inf')} 
                        for col in numeric_cols}
            
            # Traiter par chunks
            chunk_size = 100000
            chunk_count = 0
            total_rows = 0
            
            # Initialiser un dataframe pour stocker une version échantillonnée
            sampled_rows = []
            sampling_rate = 0.01  # 1%
            
            for chunk in pd.read_csv(file_path, sep=likely_sep, encoding=encoding_used, 
                                    chunksize=chunk_size, error_bad_lines=False, 
                                    warn_bad_lines=True, low_memory=False):
                chunk_count += 1
                rows_in_chunk = len(chunk)
                total_rows += rows_in_chunk
                
                logger.info(f"Traitement du chunk {chunk_count}, {rows_in_chunk} lignes")
                
                # Optimiser la mémoire du chunk
                chunk = optimize_dataframe(chunk)
                
                # Mettre à jour les statistiques
                for col in numeric_cols:
                    if col in chunk.columns:
                        non_na = chunk[col].dropna()
                        if len(non_na) > 0:
                            stats_data[col]['sum'] += non_na.sum()
                            stats_data[col]['sum_sq'] += (non_na ** 2).sum()
                            stats_data[col]['count'] += len(non_na)
                            stats_data[col]['min'] = min(stats_data[col]['min'], non_na.min())
                            stats_data[col]['max'] = max(stats_data[col]['max'], non_na.max())
                
                # Échantillonner des lignes pour l'analyse
                if len(sampled_rows) < 50000:  # Limiter à 50k lignes max
                    sample = chunk.sample(frac=sampling_rate)
                    sampled_rows.append(sample)
                
                # Si on a dépassé max_rows, arrêter
                if max_rows and total_rows >= max_rows:
                    logger.info(f"Limite de {max_rows} lignes atteinte, arrêt du traitement par chunks")
                    break
                
                # Libérer la mémoire
                del chunk
                gc.collect()
            
            # Calculer les statistiques finales
            stats = {}
            for col in numeric_cols:
                if stats_data[col]['count'] > 0:
                    mean = stats_data[col]['sum'] / stats_data[col]['count']
                    variance = (stats_data[col]['sum_sq'] / stats_data[col]['count']) - (mean ** 2)
                    std = np.sqrt(variance) if variance > 0 else 0
                    stats[col] = {
                        'count': stats_data[col]['count'],
                        'mean': mean,
                        'std': std,
                        'min': stats_data[col]['min'],
                        '25%': None,  # Impossible de calculer sans les données complètes
                        '50%': None,
                        '75%': None,
                        'max': stats_data[col]['max']
                    }
            
            # Combiner les échantillons pour les visualisations
            df_sample = pd.concat(sampled_rows, ignore_index=True)
            logger.info(f"Échantillon créé avec {len(df_sample)} lignes pour visualisation")
            
            # Créer un DataFrame comme si on avait tout lu
            df = df_sample
            row_count = total_rows
            col_count = len(columns)
            
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
        
        # Analyse statistique et visualisations
        data_analysis = analyze_and_visualize_data(df, output_prefix, file_path)
        
        # Sauvegarder une version échantillonnée pour traitement ultérieur
        if row_count > 10000:
            logger.info(f"Sauvegarde d'un échantillon de 10000 lignes")
            sample_size = min(10000, row_count)
            df_sample = df.sample(n=sample_size, random_state=42) if len(df) > sample_size else df
            sample_file = PROCESSED_DIR / f"{output_prefix}_sample.csv"
            df_sample.to_csv(sample_file, index=False)
        else:
            df_sample = df
            sample_file = PROCESSED_DIR / f"{output_prefix}_clean.csv"
            df_sample.to_csv(sample_file, index=False)
        
        # Compresser le fichier complet si nécessaire
        full_file = PROCESSED_DIR / f"{output_prefix}_full.csv.gz"
        if file_size_mb < 200:  # Ne pas sauvegarder les fichiers trop grands
            logger.info(f"Sauvegarde du fichier complet compressé")
            df.to_csv(full_file, index=False, compression='gzip')
        else:
            logger.info(f"Fichier trop volumineux pour être sauvegardé en entier")
        
        # Libérer la mémoire
        del df
        gc.collect()
        
        return {
            "fichier": str(file_path),
            "lignes": row_count,
            "colonnes": col_count,
            "taille_mb": file_size_mb,
            "colonnes_numeriques": data_analysis["colonnes_numeriques"],
            "fichiers_sortie": [str(sample_file), str(full_file)],
            "visualisations": data_analysis["visualisations"],
            "correlations": data_analysis["correlations"],
            "valeurs_manquantes": data_analysis["valeurs_manquantes"],
            "stats": data_analysis["stats"]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}", exc_info=True)
        return {"erreur": str(e)}

def analyze_and_visualize_data(df, output_prefix, file_path):
    """
    Fonction avancée d'analyse et de visualisation des données
    """
    logger.info(f"Analyse et visualisation des données pour {output_prefix}")
    result = {
        "colonnes_numeriques": [],
        "visualisations": [],
        "correlations": {},
        "valeurs_manquantes": {},
        "stats": {}
    }
    
    # Analyser les types de colonnes
    numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
    categorical_cols = df.select_dtypes(include=['object', 'category']).columns.tolist()
    date_cols = []
    
    result["colonnes_numeriques"] = numeric_cols
    
    # Détecter les colonnes de dates
    for col in categorical_cols.copy():
        try:
            # Vérifier si la colonne contient des dates
            if df[col].iloc[0] and isinstance(df[col].iloc[0], str):
                pd.to_datetime(df[col], errors='raise')
                date_cols.append(col)
                categorical_cols.remove(col)
                logger.info(f"Colonne {col} identifiée comme date")
        except:
            pass
    
    ## Analyse des valeurs manquantes
    missing_values = df.isnull().sum()
    missing_pct = (missing_values / len(df)) * 100
    
    missing_df = pd.DataFrame({
        'manquantes': missing_values,
        'pourcentage': missing_pct
    })
    missing_df = missing_df[missing_df['manquantes'] > 0].sort_values('pourcentage', ascending=False)
    
    result["valeurs_manquantes"] = missing_df.to_dict()
    
    # Créer un graphique de valeurs manquantes si présentes
    if not missing_df.empty:
        plt.figure(figsize=(12, 6))
        ax = sns.barplot(x=missing_df.index, y='pourcentage', data=missing_df)
        plt.title('Pourcentage de valeurs manquantes par colonne')
        plt.xticks(rotation=90)
        plt.ylabel('Pourcentage (%)')
        plt.tight_layout()
        
        missing_chart = VISUALIZATION_DIR / f"{output_prefix}_missing_values.png"
        plt.savefig(missing_chart)
        plt.close()
        
        result["visualisations"].append(str(missing_chart))
        logger.info(f"Graphique des valeurs manquantes créé: {missing_chart}")
    
    # Statistiques descriptives pour les colonnes numériques
    if numeric_cols:
        stats = df[numeric_cols].describe(percentiles=[0.1, 0.25, 0.5, 0.75, 0.9]).transpose()
        stats['skew'] = df[numeric_cols].skew()
        stats['kurtosis'] = df[numeric_cols].kurtosis()
        
        stats_file = PROCESSED_DIR / f"{output_prefix}_stats.csv"
        stats.to_csv(stats_file)
        result["stats"] = stats.to_dict()
        logger.info(f"Statistiques enregistrées dans {stats_file}")
        
        # Créer des visualisations pour les colonnes numériques (maximum 5 colonnes)
        cols_to_plot = numeric_cols[:5]
        if cols_to_plot:
            # 1. Histogrammes
            fig, axes = plt.subplots(len(cols_to_plot), 1, figsize=(12, 4 * len(cols_to_plot)))
            if len(cols_to_plot) == 1:
                axes = [axes]
            
            for i, col in enumerate(cols_to_plot):
                if df[col].nunique() > 1:  # Éviter les colonnes avec une seule valeur
                    sns.histplot(df[col].dropna(), kde=True, ax=axes[i])
                    axes[i].set_title(f'Distribution de {col}')
                    # Ajouter des lignes verticales pour les quartiles
                    q1, median, q3 = df[col].quantile([0.25, 0.5, 0.75])
                    axes[i].axvline(q1, color='red', linestyle='--', alpha=0.7, label='Q1')
                    axes[i].axvline(median, color='green', linestyle='--', alpha=0.7, label='Médiane')
                    axes[i].axvline(q3, color='orange', linestyle='--', alpha=0.7, label='Q3')
                    # Ajouter des statistiques sur le graphique
                    stats_text = f"Moy: {df[col].mean():.2f}, Med: {median:.2f}, Écart-type: {df[col].std():.2f}"
                    axes[i].text(0.05, 0.95, stats_text, transform=axes[i].transAxes, 
                                verticalalignment='top', bbox=dict(boxstyle='round', facecolor='white', alpha=0.7))
                    axes[i].legend()
            
            plt.tight_layout()
            hist_chart = VISUALIZATION_DIR / f"{output_prefix}_histograms.png"
            plt.savefig(hist_chart)
            plt.close()
            
            result["visualisations"].append(str(hist_chart))
            logger.info(f"Histogrammes créés: {hist_chart}")
            
            # 2. Boîtes à moustaches
            plt.figure(figsize=(14, 8))
            sns.boxplot(data=df[cols_to_plot])
            plt.title('Boîtes à moustaches des variables numériques')
            plt.xticks(rotation=90)
            plt.tight_layout()
            
            boxplot_chart = VISUALIZATION_DIR / f"{output_prefix}_boxplots.png"
            plt.savefig(boxplot_chart)
            plt.close()
            
            result["visualisations"].append(str(boxplot_chart))
            logger.info(f"Boîtes à moustaches créées: {boxplot_chart}")
            
            # 3. Matrice de corrélation pour les colonnes numériques
            if len(cols_to_plot) > 1:
                corr_matrix = df[cols_to_plot].corr()
                result["correlations"] = corr_matrix.to_dict()
                
                plt.figure(figsize=(10, 8))
                mask = np.triu(np.ones_like(corr_matrix, dtype=bool))
                cmap = sns.diverging_palette(220, 10, as_cmap=True)
                
                sns.heatmap(corr_matrix, mask=mask, cmap=cmap, vmax=1, vmin=-1, center=0,
                        square=True, linewidths=.5, annot=True, fmt='.2f')
                plt.title('Matrice de corrélation')
                plt.tight_layout()
                
                corr_chart = VISUALIZATION_DIR / f"{output_prefix}_correlation.png"
                plt.savefig(corr_chart)
                plt.close()
                
                result["visualisations"].append(str(corr_chart))
                logger.info(f"Matrice de corrélation créée: {corr_chart}")
    
    # Analyse des variables catégorielles (maximum 5 colonnes)
    cat_cols_to_plot = categorical_cols[:5]
    if cat_cols_to_plot:
        # Créer des graphiques pour chaque variable catégorielle (top 10 catégories)
        for col in cat_cols_to_plot:
            if df[col].nunique() > 1 and df[col].nunique() < 50:  # Seulement pour les colonnes avec un nombre raisonnable de catégories
                plt.figure(figsize=(12, 6))
                
                # Calculer les fréquences et prendre les 10 catégories les plus fréquentes
                value_counts = df[col].value_counts().head(10)
                
                # Créer un graphique à barres avec des pourcentages
                ax = sns.barplot(x=value_counts.index, y=value_counts.values)
                
                # Ajouter des pourcentages sur les barres
                total = len(df[col].dropna())
                for i, v in enumerate(value_counts.values):
                    percentage = (v / total) * 100
                    ax.text(i, v + 0.1, f"{percentage:.1f}%", ha='center')
                
                plt.title(f'Top 10 catégories dans {col}')
                plt.xticks(rotation=45, ha='right')
                plt.tight_layout()
                
                cat_chart = VISUALIZATION_DIR / f"{output_prefix}_{col}_categories.png"
                plt.savefig(cat_chart)
                plt.close()
                
                result["visualisations"].append(str(cat_chart))
                logger.info(f"Graphique des catégories créé pour {col}: {cat_chart}")
    
    # Analyse des séries temporelles si des colonnes de date sont détectées
    if date_cols and numeric_cols:
        date_col = date_cols[0]  # Utiliser la première colonne de date trouvée
        
        try:
            # Convertir en datetime
            df[date_col] = pd.to_datetime(df[date_col], errors='coerce')
            
            # Sélectionner la première colonne numérique pour l'évolution temporelle
            numeric_col = numeric_cols[0]
            
            # Créer un graphique d'évolution temporelle
            plt.figure(figsize=(14, 6))
            
            # Regrouper par jour et calculer la moyenne
            time_data = df.dropna(subset=[date_col, numeric_col])
            time_data = time_data.set_index(date_col)
            time_data = time_data[numeric_col].resample('D').mean()
            
            # Créer un graphique de ligne avec tendance
            time_data.plot(marker='o', linestyle='-', alpha=0.7, figsize=(14, 6))
            
            # Ajouter une courbe de tendance
            z = np.polyfit(range(len(time_data)), time_data.values, 1)
            p = np.poly1d(z)
            plt.plot(range(len(time_data)), p(range(len(time_data))), "r--", 
                    alpha=0.7, label=f"Tendance: {z[0]:.4f}x + {z[1]:.2f}")
            
            plt.title(f'Évolution temporelle de {numeric_col}')
            plt.ylabel(numeric_col)
            plt.xlabel(date_col)
            plt.grid(True, alpha=0.3)
            plt.legend()
            plt.tight_layout()
            
            time_chart = VISUALIZATION_DIR / f"{output_prefix}_time_series.png"
            plt.savefig(time_chart)
            plt.close()
            
            result["visualisations"].append(str(time_chart))
            logger.info(f"Graphique d'évolution temporelle créé: {time_chart}")
            
        except Exception as e:
            logger.warning(f"Impossible de créer l'analyse temporelle: {str(e)}")
    
    # Créer un graphique spécial combiné pour un résumé visuel des données
    try:
        create_dashboard_visualization(df, output_prefix, numeric_cols[:3], categorical_cols[:2])
        dashboard_chart = VISUALIZATION_DIR / f"{output_prefix}_dashboard.png"
        result["visualisations"].append(str(dashboard_chart))
    except Exception as e:
        logger.warning(f"Impossible de créer le tableau de bord: {str(e)}")
    
    return result

def create_dashboard_visualization(df, output_prefix, numeric_cols, categorical_cols):
    """
    Crée une visualisation de type tableau de bord combinant plusieurs graphiques
    """
    if not numeric_cols:
        return
    
    # Créer une mise en page pour le tableau de bord
    fig = plt.figure(figsize=(16, 12))
    gs = GridSpec(3, 2, figure=fig)
    
    # Titre principal
    fig.suptitle(f'Tableau de bord analytique - {output_prefix}', fontsize=20, y=0.98)
    
    # 1. Histogramme de la première colonne numérique
    ax1 = fig.add_subplot(gs[0, 0])
    if len(numeric_cols) > 0:
        sns.histplot(df[numeric_cols[0]].dropna(), kde=True, ax=ax1)
        ax1.set_title(f'Distribution de {numeric_cols[0]}')
    
    # 2. Boîte à moustaches pour toutes les colonnes numériques
    ax2 = fig.add_subplot(gs[0, 1])
    if numeric_cols:
        sns.boxplot(data=df[numeric_cols], ax=ax2)
        ax2.set_title('Comparaison des distributions')
        ax2.tick_params(axis='x', rotation=45)
    
    # 3. Graphique à barres pour la première colonne catégorielle
    ax3 = fig.add_subplot(gs[1, 0])
    if categorical_cols and len(categorical_cols) > 0:
        col = categorical_cols[0]
        if df[col].nunique() < 20:  # Limiter aux colonnes avec un nombre raisonnable de catégories
            value_counts = df[col].value_counts().head(10)
            sns.barplot(x=value_counts.index, y=value_counts.values, ax=ax3)
            ax3.set_title(f'Top 10 catégories dans {col}')
            ax3.tick_params(axis='x', rotation=45)
            ax3.set_xticklabels(ax3.get_xticklabels(), ha='right')
    
    # 4. Nuage de points entre deux colonnes numériques
    ax4 = fig.add_subplot(gs[1, 1])
    if len(numeric_cols) >= 2:
        sns.scatterplot(x=df[numeric_cols[0]], y=df[numeric_cols[1]], ax=ax4, alpha=0.5)
        ax4.set_title(f'Relation entre {numeric_cols[0]} et {numeric_cols[1]}')
        
        # Ajouter une ligne de tendance
        x = df[numeric_cols[0]].dropna()
        y = df[numeric_cols[1]].dropna()
        
        # Supprimer les lignes où l'une des deux colonnes est manquante
        valid_data = ~(x.isna() | y.isna())
        x = x[valid_data]
        y = y[valid_data]
        
        if len(x) > 1 and len(y) > 1:
            try:
                slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)
                ax4.plot(x, intercept + slope*x, 'r', 
                        label=f'y={slope:.2f}x+{intercept:.2f}, r²={r_value**2:.2f}')
                ax4.legend()
            except:
                pass
    
    # 5. Graphique résumant les valeurs manquantes
    ax5 = fig.add_subplot(gs[2, :])
    missing_values = df.isnull().sum()
    missing_pct = (missing_values / len(df)) * 100
    missing_df = pd.DataFrame({
        'manquantes': missing_values,
        'pourcentage': missing_pct
    })
    missing_df = missing_df[missing_df['manquantes'] > 0].sort_values('pourcentage', ascending=False).head(10)
    
    if not missing_df.empty:
        sns.barplot(x=missing_df.index, y='pourcentage', data=missing_df, ax=ax5)
        ax5.set_title('Pourcentage de valeurs manquantes par colonne')
        ax5.tick_params(axis='x', rotation=45)
        ax5.set_xticklabels(ax5.get_xticklabels(), ha='right')
        ax5.set_ylabel('Pourcentage (%)')
    else:
        ax5.text(0.5, 0.5, 'Aucune valeur manquante trouvée dans le jeu de données', 
                 horizontalalignment='center', verticalalignment='center', fontsize=14)
        ax5.set_title('Analyse des valeurs manquantes')
        ax5.set_xticks([])
        ax5.set_yticks([])
    
    # Ajouter des informations générales sur le dataset
    plt.figtext(0.5, 0.01, 
                f"Jeu de données: {output_prefix} | Nombre de lignes: {len(df)} | Nombre de colonnes: {len(df.columns)}", 
                ha="center", fontsize=12, 
                bbox={"facecolor":"orange", "alpha":0.2, "pad":5})
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    
    # Sauvegarder le dashboard
    dashboard_chart = VISUALIZATION_DIR / f"{output_prefix}_dashboard.png"
    plt.savefig(dashboard_chart)
    plt.close()
    
    logger.info(f"Tableau de bord créé: {dashboard_chart}")
    return dashboard_chart

def generate_enhanced_report(results):
    """
    Génère un rapport HTML amélioré avec des visualisations interactives
    """
    try:
        # Créer un résumé en HTML avec Bootstrap et intégration de graphiques
        now = datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S")
        report_id = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Rapport avancé de traitement des données - {today}</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>
                body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; color: #333; }}
                .header {{ background-color: #375a7f; color: white; padding: 2rem 0; margin-bottom: 2rem; }}
                .card {{ margin-bottom: 1.5rem; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); border: none; }}
                .card-header {{ background-color: #375a7f; color: white; font-weight: 500; }}
                .table {{ width: 100%; border-collapse: collapse; }}
                .table th {{ background-color: #f8f9fa; }}
                .stats-value {{ font-weight: bold; color: #375a7f; }}
                .error {{ color: #dc3545; }}
                .progress {{ height: 0.8rem; margin-top: 0.5rem; }}
                .chart-container {{ height: 400px; margin-bottom: 1.5rem; }}
                .file-info {{ background-color: #f8f9fa; padding: 1rem; border-radius: 0.3rem; margin-bottom: 1rem; }}
                .insights {{ background-color: #e3f2fd; padding: 0.8rem; border-radius: 0.3rem; border-left: 4px solid #2196f3; }}
                .warning {{ background-color: #fff3cd; padding: 0.8rem; border-radius: 0.3rem; border-left: 4px solid #ffc107; }}
                footer {{ background-color: #f8f9fa; padding: 1.5rem 0; margin-top: 3rem; text-align: center; font-size: 0.9rem; color: #666; }}
            </style>
        </head>
        <body>
            <div class="header text-center">
                <div class="container">
                    <h1 class="display-4">Rapport d'analyse de données</h1>
                    <p class="lead">Traitement automatisé avec visualisations avancées - {today}</p>
                </div>
            </div>
            
            <div class="container">
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header">
                                <h2 class="h4 mb-0">Résumé global</h2>
                            </div>
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-md-6">
                                        <p><strong>Fichiers traités :</strong> {len(results)}</p>
                                        <p><strong>Date de génération :</strong> {now}</p>
                                        <p><strong>Identifiant du rapport :</strong> {report_id}</p>
                                    </div>
                                    <div class="col-md-6">
                                        <canvas id="summary_chart"></canvas>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <h2 class="mt-4 mb-3">Résultats par fichier</h2>
        """
        
        # Ajouter une section pour chaque fichier traité
        for result in results:
            source = result.get("fichier", "").split("/")[-1].split("_")[0]
            
            if "erreur" in result:
                # Afficher une carte d'erreur
                html += f"""
                <div class="card mb-4">
                    <div class="card-header bg-danger text-white">
                        <h3 class="h5 mb-0">Source: {source} - ERREUR</h3>
                    </div>
                    <div class="card-body">
                        <div class="alert alert-danger">
                            {result["erreur"]}
                        </div>
                    </div>
                </div>
                """
            else:
                # Récupérer les informations du résultat
                lignes = result.get("lignes", "-")
                colonnes = result.get("colonnes", "-")
                taille_mb = result.get("taille_mb", "-")
                columns_num = result.get("colonnes_numeriques", [])
                visualisations = result.get("visualisations", [])
                
                # Créer la section du rapport pour ce fichier
                html += f"""
                <div class="card mb-5">
                    <div class="card-header">
                        <h3 class="h5 mb-0">Source: {source}</h3>
                    </div>
                    <div class="card-body">
                        <div class="file-info mb-4">
                            <div class="row">
                                <div class="col-md-4">
                                    <p><strong>Nombre de lignes :</strong> <span class="stats-value">{lignes:,}</span></p>
                                    <p><strong>Nombre de colonnes :</strong> <span class="stats-value">{colonnes}</span></p>
                                </div>
                                <div class="col-md-4">
                                    <p><strong>Taille du fichier :</strong> <span class="stats-value">{taille_mb:.2f} MB</span></p>
                                    <p><strong>Colonnes numériques :</strong> <span class="stats-value">{len(columns_num)}</span></p>
                                </div>
                                <div class="col-md-4">
                                    <p><strong>Fichier :</strong> {result.get("fichier", "")}</p>
                                </div>
                            </div>
                        </div>
                        
                        <h4 class="mt-4 mb-3">Aperçu des visualisations</h4>
                        <div class="row">
                """
                
                # Ajouter les visualisations
                for i, viz in enumerate(visualisations):
                    viz_name = viz.split('/')[-1].replace(f"{source}_", "").replace(".png", "")
                    html += f"""
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-header bg-light">
                                {viz_name.replace("_", " ").title()}
                            </div>
                            <div class="card-body text-center">
                                <img src="../visualizations/{viz.split('/')[-1]}" class="img-fluid" alt="{viz_name}">
                            </div>
                        </div>
                    </div>
                    """
                
                html += """
                        </div>
                """
                
                # Ajouter la section des valeurs manquantes si présente
                if "valeurs_manquantes" in result and result["valeurs_manquantes"]:
                    missing_values = result["valeurs_manquantes"]
                    
                    html += """
                        <h4 class="mt-4 mb-3">Valeurs manquantes</h4>
                        <div class="table-responsive">
                            <table class="table table-striped table-hover">
                                <thead>
                                    <tr>
                                        <th>Colonne</th>
                                        <th>Valeurs manquantes</th>
                                        <th>Pourcentage</th>
                                        <th>Visualisation</th>
                                    </tr>
                                </thead>
                                <tbody>
                    """
                    
                    for col, values in missing_values.get("manquantes", {}).items():
                        if values > 0:
                            pct = missing_values.get("pourcentage", {}).get(col, 0)
                            html += f"""
                            <tr>
                                <td>{col}</td>
                                <td>{values:,}</td>
                                <td>{pct:.2f}%</td>
                                <td>
                                    <div class="progress">
                                        <div class="progress-bar bg-warning" role="progressbar" style="width: {pct}%" 
                                             aria-valuenow="{pct}" aria-valuemin="0" aria-valuemax="100"></div>
                                    </div>
                                </td>
                            </tr>
                            """
                    
                    html += """
                                </tbody>
                            </table>
                        </div>
                    """
                
                # Ajouter la section statistiques si présente
                if "stats" in result and result["stats"]:
                    html += """
                        <h4 class="mt-4 mb-3">Statistiques descriptives</h4>
                        <div class="table-responsive">
                            <table class="table table-striped table-hover">
                                <thead>
                                    <tr>
                                        <th>Variable</th>
                                        <th>Moyenne</th>
                                        <th>Écart-type</th>
                                        <th>Min</th>
                                        <th>Q1 (25%)</th>
                                        <th>Médiane</th>
                                        <th>Q3 (75%)</th>
                                        <th>Max</th>
                                        <th>Asymétrie</th>
                                    </tr>
                                </thead>
                                <tbody>
                    """
                    
                    stats_data = result["stats"]
                    for col, values in stats_data.items():
                        if "mean" in values:
                            html += f"""
                            <tr>
                                <td>{col}</td>
                                <td>{values.get("mean", "-"):.2f}</td>
                                <td>{values.get("std", "-"):.2f}</td>
                                <td>{values.get("min", "-"):.2f}</td>
                                <td>{values.get("25%", "-"):.2f}</td>
                                <td>{values.get("50%", "-"):.2f}</td>
                                <td>{values.get("75%", "-"):.2f}</td>
                                <td>{values.get("max", "-"):.2f}</td>
                                <td>{values.get("skew", "-"):.2f}</td>
                            </tr>
                            """
                    
                    html += """
                                </tbody>
                            </table>
                        </div>
                    """
                
                # Ajouter la section corrélations si présente
                if "correlations" in result and result["correlations"]:
                    html += """
                        <h4 class="mt-4 mb-3">Matrice de corrélation</h4>
                        <div class="table-responsive">
                            <table class="table table-striped table-hover">
                                <thead>
                                    <tr>
                                        <th>Variable</th>
                    """
                    
                    # En-têtes de colonnes
                    for col in result["correlations"].keys():
                        html += f"""<th>{col}</th>"""
                    
                    html += """
                                    </tr>
                                </thead>
                                <tbody>
                    """
                    
                    # Lignes de la matrice
                    for row, values in result["correlations"].items():
                        html += f"""<tr><td><strong>{row}</strong></td>"""
                        
                        for col, val in values.items():
                            # Colorer les cellules selon la valeur de corrélation
                            if abs(val) > 0.7:
                                cell_class = "bg-danger text-white"
                            elif abs(val) > 0.5:
                                cell_class = "bg-warning"
                            elif abs(val) > 0.3:
                                cell_class = "bg-info"
                            else:
                                cell_class = ""
                            
                            html += f"""<td class="{cell_class}">{val:.2f}</td>"""
                        
                        html += """</tr>"""
                    
                    html += """
                                </tbody>
                            </table>
                        </div>
                        
                        <div class="insights mt-3">
                            <h5>Insights sur les corrélations</h5>
                            <p>Les cases en rouge indiquent une forte corrélation (>0.7), en jaune une corrélation modérée (>0.5) et en bleu une faible corrélation (>0.3).</p>
                        </div>
                    """
                
                # Fermeture de la carte
                html += """
                    </div>
                </div>
                """
        
        # Fermeture du HTML
        html += """
            </div>
            
            <footer>
                <div class="container">
                    <p>Rapport d'analyse de données généré automatiquement</p>
                    <p>Version 2.0 - Système avancé de traitement et visualisation</p>
                </div>
            </footer>
            
            <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>
         
            
            <script>
                // Code JavaScript pour les graphiques interactifs
                document.addEventListener('DOMContentLoaded', function() {
                    // Graphique de résumé global
                    const ctxSummary = document.getElementById('summary_chart').getContext('2d');
                    
                    // Compiler les données pour le graphique de résumé
                    const fileNames = [];
                    const rowCounts = [];
                    const colCounts = [];
                    
                    // Extraire les données des résultats
                    const results = ${json.dumps([r for r in results if "erreur" not in r])};
                    results.forEach(result => {
                        const fileName = result.fichier.split('/').pop().split('_')[0];
                        fileNames.push(fileName);
                        rowCounts.push(result.lignes);
                        colCounts.push(result.colonnes);
                    });
                    
                    // Créer le graphique de résumé
                    new Chart(ctxSummary, {
                        type: 'bar',
                        data: {
                            labels: fileNames,
                            datasets: [
                                {
                                    label: 'Nombre de lignes',
                                    data: rowCounts,
                                    backgroundColor: 'rgba(54, 162, 235, 0.5)',
                                    borderColor: 'rgba(54, 162, 235, 1)',
                                    borderWidth: 1
                                }
                            ]
                        },
                        options: {
                            responsive: true,
                            plugins: {
                                title: {
                                    display: true,
                                    text: 'Taille des jeux de données'
                                },
                                legend: {
                                    position: 'top',
                                }
                            },
                            scales: {
                                y: {
                                    beginAtZero: true,
                                    title: {
                                        display: true,
                                        text: 'Nombre de lignes'
                                    }
                                }
                            }
                        }
                    });
                });
            </script>
        </body>
        </html>
        """
        
        # Enregistrer le rapport HTML
        report_file = REPORT_DIR / f"rapport_advanced_{today}.html"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html)
        
        logger.info(f"Rapport HTML avancé généré: {report_file}")
        return report_file
    
    except Exception as e:
        logger.error(f"Erreur lors de la génération du rapport avancé: {str(e)}", exc_info=True)
        return None

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
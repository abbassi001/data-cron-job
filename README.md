# Projet Cron Job avec Open Data et Git

Ce projet implémente un système automatisé de récupération et d'analyse de données ouvertes, avec versionnement Git intégré.

## 🚀 Fonctionnalités

- **Récupération automatique** de données depuis plusieurs fournisseurs d'Open Data
- **Traitement et analyse** des données avec Python
- **Génération de rapports** et visualisations
- **Versionnement Git** intégré pour suivre l'évolution des données
- **Historique des métadonnées** pour assurer la traçabilité
- **Système de notification** par email et webhooks
- **Journalisation complète** pour faciliter le débogage

## 📋 Prérequis

- Git
- Python 3.8+
- Bash
- Accès à internet pour télécharger les données
- Droit d'exécution de cron (pour l'automatisation)

## 🔧 Installation

1. **Cloner ce dépôt :**
   ```bash
   git clone https://github.com/votre-utilisateur/data-cron-job.git
   cd data-cron-job
   ```

2. **Créer la structure de répertoires :**
   ```bash
   mkdir -p data/raw data/processed data/reports logs
   ```

3. **Installer les dépendances Python :**
   ```bash
   pip install -r requirements.txt
   ```

4. **Rendre les scripts exécutables :**
   ```bash
   chmod +x scripts/*.sh
   ```

5. **Configurer les paramètres :**
   - Modifier l'adresse email dans `scripts/run_data_job.sh`
   - Personnaliser les sources de données dans `scripts/download_data.sh`

## 📊 Sources de données

Les données sont récupérées des sources ouvertes suivantes :

1. **COVID19_FR** - Données Covid-19 en France 
   - Source : data.gouv.fr

2. **METEO_FRANCE** - Données météorologiques essentielles
   - Source : opendatasoft.com

3. **OPEN_AQ** - Qualité de l'air en France
   - Source : openaq.org

## 💻 Utilisation

### Exécution manuelle

Pour lancer le job complet manuellement :

```bash
./scripts/run_data_job.sh
```

Pour exécuter une étape spécifique :

```bash
# Téléchargement seul
./scripts/download_data.sh

# Traitement seul
python3 scripts/process_data.py
```

### Configuration Cron

Pour automatiser l'exécution, ajoutez une entrée cron :

```bash
# Éditer la crontab
crontab -e

# Ajouter la ligne suivante pour une exécution quotidienne à 3h du matin
0 3 * * * /chemin/absolu/vers/data-cron-job/scripts/run_data_job.sh
```

## 📁 Structure du projet

```
data-cron-job/
├── data/
│   ├── raw/         # Données brutes téléchargées
│   ├── processed/   # Données traitées
│   └── reports/     # Rapports et visualisations
├── logs/            # Journaux d'exécution
├── scripts/
│   ├── download_data.sh    # Script de téléchargement
│   ├── process_data.py     # Script de traitement
│   └── run_data_job.sh     # Script principal
├── .gitignore
├── README.md
└── requirements.txt
```

## 🔄 Workflow Git

Le projet utilise Git pour versionner les métadonnées et les résultats d'analyse :

1. Une branche dédiée `data-updates` est utilisée pour les mises à jour de données
2. Les données brutes volumineuses ne sont pas versionnées (voir `.gitignore`)
3. Les fichiers de métadonnées (`.meta` et `.sha256`) sont versionnés pour assurer la traçabilité
4. Les rapports générés et les données traitées sont versionnés
5. Chaque exécution du job crée un commit daté

## 🔍 Suivi et supervision

Le système génère différents types de journaux :

- **Logs d'exécution** : Dans le répertoire `logs/`
- **Métadonnées des fichiers** : Fichiers `.meta` associés aux données brutes
- **Empreintes SHA256** : Fichiers `.sha256` pour vérifier l'intégrité des données
- **Rapports de traitement** : Dans `data/reports/`

## 🔄 Personnalisation

Vous pouvez facilement adapter ce projet :

1. **Ajouter de nouvelles sources** : Modifiez la variable `SOURCES` dans `download_data.sh`
2. **Modifier le traitement** : Adaptez les fonctions dans `process_data.py`
3. **Changer la fréquence** : Modifiez l'entrée cron
4. **Ajouter des intégrations** : Complétez le système de notification dans `run_data_job.sh`

## 🤝 Contribution

Les contributions sont bienvenues ! Pour contribuer :

1. Forkez le projet
2. Créez une branche pour votre fonctionnalité
3. Committez vos changements
4. Soumettez une Pull Request

## 📜 Licence

Ce projet est sous licence MIT.

## ✨ Inspirations et ressources

- [Data.gouv.fr](https://www.data.gouv.fr/) - Plateforme de données ouvertes française
- [OpenDataSoft](https://public.opendatasoft.com/) - Plateforme de données ouvertes
- [OpenAQ](https://openaq.org/) - Données sur la qualité de l'air
- [Git Data Workflows](https://www.atlassian.com/git/tutorials/git-data-workflows) - Bonnes pratiques pour versionner des données
- [Pandas Documentation](https://pandas.pydata.org/docs/) - Documentation pour l'analyse de données
# Système Automatisé de Traitement de Données Ouvertes

Un outil tout-en-un pour télécharger, traiter et analyser des données ouvertes avec versionnement Git et notifications Discord.

## 🚀 Vue d'ensemble

Ce projet fournit un système automatisé qui :

1. **Télécharge** des données depuis plusieurs sources d'Open Data
2. **Traite et analyse** ces données avec Python (pandas, matplotlib)
3. **Génère des rapports HTML** et des visualisations
4. **Versionne** les résultats avec Git
5. **Envoie des notifications** via Discord avec images intégrées

Parfait pour créer un tableau de bord de données actualisé régulièrement avec un minimum d'intervention manuelle.

## 💡 Caractéristiques principales

- **Script tout-en-un** qui orchestre l'ensemble du processus
- **Téléchargement robuste** avec gestion des erreurs et retry
- **Traitement flexible** qui s'adapte automatiquement au format des données
- **Visualisations** générées automatiquement
- **Notifications riches** via Discord incluant graphiques et rapports
- **Versionning Git** pour suivre l'évolution des données
- **Interface visuelle** avec bannières Figlet pour une meilleure lisibilité

## 📋 Prérequis

- **Python 3.6+**
- **Git** (optionnel, pour le versionning)
- **Bibliothèques Python** : pandas, matplotlib, requests
- **Figlet** (optionnel, pour l'affichage)
- **Compte Discord** et webhook (pour les notifications)

## 🛠️ Installation

1. **Cloner ce dépôt :**
   ```bash
   git clone <URL_DU_REPO>
   cd data-process-system
   ```

2. **Installer les dépendances :**
   ```bash
   pip install pandas matplotlib requests
   sudo apt-get install figlet  # Optionnel, pour les bannières
   ```

3. **Configurer les notifications Discord :**
   - Créer un webhook dans votre serveur Discord
   - Copier l'URL du webhook
   - Mettre à jour la variable `DISCORD_WEBHOOK` dans `run_all.sh`

4. **Créer la structure de dossiers :**
   ```bash
   mkdir -p data/raw data/processed data/reports logs
   ```

## 📊 Sources de données

Le système télécharge actuellement des données depuis :

- **METEO_FRANCE** - Données météorologiques (via OpenDataSoft)
- **OPEN_METEO** - Données climatiques historiques de Paris
- **DONNEES_ECO** - Données économiques (via data.gouv.fr)

Vous pouvez facilement ajouter ou modifier ces sources en éditant la section `SOURCES` dans le script `run_all.sh`.

## 🖥️ Utilisation

### Exécution manuelle

```bash
# Rendre le script exécutable
chmod +x scripts/run_all.sh

# Lancer le processus complet
./scripts/run_all.sh
```

### Automatisation avec Cron

Pour exécuter le script tous les jours à 2h du matin :

```bash
# Ouvrir la configuration cron
crontab -e

# Ajouter cette ligne (ajustez le chemin)
0 2 * * * /chemin/vers/scripts/run_all.sh
```

## 📊 Résultats générés

Après exécution, vous trouverez :

- **Fichiers bruts** dans `data/raw/`
- **Données traitées** dans `data/processed/`
- **Rapports et graphiques** dans `data/reports/`
- **Logs** dans `logs/`
- **Notification Discord** avec un résumé et un graphique

## 🧩 Structure du projet

```
projet/
├── scripts/
│   ├── run_all.sh              # Script principal orchestrateur
│   ├── send_discord_with_charts.py    # Script d'envoi Discord (généré auto)
│   └── temp_process_data.py    # Script temporaire de traitement
├── data/
│   ├── raw/                    # Données brutes téléchargées
│   ├── processed/              # Données analysées et nettoyées
│   └── reports/                # Rapports HTML et visualisations
├── logs/                       # Journaux d'exécution
└── README.md                   # Documentation
```

## ⚙️ Comment ça marche

Le script `run_all.sh` orchestre les étapes suivantes :

1. **Vérification de l'environnement** - S'assure que toutes les dépendances sont installées
2. **Configuration Git** - Prépare le versionning (si Git est disponible)
3. **Téléchargement des données** - Récupère les données depuis les sources configurées
4. **Traitement des données** - Nettoie, analyse et génère des statistiques
5. **Génération de rapports** - Crée un rapport HTML et des graphiques
6. **Versionning Git** - Enregistre les modifications (si Git est disponible)
7. **Notifications** - Envoie un résumé et un graphique sur Discord

Chaque étape est clairement indiquée par des bannières Figlet et des logs détaillés sont générés.

## 🔄 Personnalisation

### Ajouter une nouvelle source de données

Modifiez la section `SOURCES` dans `run_all.sh` :

```bash
SOURCES=(
    "NOM|URL|TYPE_FICHIER"
    # Par exemple :
    "NOUVELLE_SOURCE|https://example.com/data.csv|CSV"
)
```

### Modifier le traitement des données

Le script Python de traitement est généré dynamiquement. Vous pouvez personnaliser la fonction `process_csv` pour modifier le traitement.

### Changer le format de notification

Pour modifier l'apparence des notifications Discord, ajustez la fonction `notify_discord_with_charts`.

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez ce dépôt
2. Créez une branche pour votre fonctionnalité
3. Soumettez une pull request

## 📜 Licence

Ce projet est sous licence MIT.
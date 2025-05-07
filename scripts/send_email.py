#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import smtplib
import mimetypes
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.image import MIMEImage
from email.mime.application import MIMEApplication
from datetime import datetime
from pathlib import Path

def create_report_image(report_dir, date_str):
    """
    Crée une image simple avec la date et les informations du traitement
    """
    try:
        # Vérifier si PIL (Python Imaging Library) est disponible
        from PIL import Image, ImageDraw, ImageFont
        
        # Créer une image simple avec date et titre
        img_width, img_height = 800, 400
        background_color = (240, 248, 255)  # Bleu très clair
        text_color = (25, 25, 112)  # Bleu marine
        
        # Créer l'image
        img = Image.new('RGB', (img_width, img_height), color=background_color)
        draw = ImageDraw.Draw(img)
        
        # Essayer de charger une police, sinon utiliser la police par défaut
        try:
            # Essayer une police commune
            font_large = ImageFont.truetype("Arial", 36)
            font_medium = ImageFont.truetype("Arial", 24)
            font_small = ImageFont.truetype("Arial", 18)
        except Exception:
            # Utiliser les polices par défaut si Arial n'est pas disponible
            font_large = ImageFont.load_default()
            font_medium = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # Dessiner le titre
        title_text = "Traitement de Données"
        draw.text((img_width//2 - 150, 50), title_text, fill=text_color, font=font_large)
        
        # Dessiner la date
        date_text = f"Date: {date_str}"
        draw.text((img_width//2 - 100, 120), date_text, fill=text_color, font=font_medium)
        
        # Dessiner un cadre
        draw.rectangle([(50, 50), (img_width-50, img_height-50)], outline=text_color, width=2)
        
        # Ajouter un message
        message_text = "Rapport de traitement automatique"
        draw.text((img_width//2 - 150, 200), message_text, fill=text_color, font=font_medium)
        
        # Ajouter l'heure
        time_text = f"Généré le: {datetime.now().strftime('%H:%M:%S')}"
        draw.text((img_width//2 - 100, 260), time_text, fill=text_color, font=font_small)
        
        # Sauvegarder l'image
        image_path = os.path.join(report_dir, f"notification_image_{date_str}.png")
        img.save(image_path)
        
        print(f"✅ Image créée: {image_path}")
        return image_path
    
    except ImportError:
        print("⚠️ La bibliothèque PIL n'est pas installée. Impossible de créer une image.")
        return None
    except Exception as e:
        print(f"⚠️ Erreur lors de la création de l'image: {str(e)}")
        return None

def send_email(recipient, subject, message, report_dir, date_str):
    """
    Envoie un email avec une image en pièce jointe
    """
    # Créer une image pour la notification
    image_path = create_report_image(report_dir, date_str)
    
    # Créer un message multipart
    msg = MIMEMultipart()
    msg['Subject'] = subject
    msg['From'] = f"Système de données <{os.getlogin()}@localhost>"
    msg['To'] = recipient
    
    # Ajouter le texte du message
    msg.attach(MIMEText(message, 'plain'))
    
    # Ajouter l'image si elle a été créée
    if image_path and os.path.exists(image_path):
        with open(image_path, 'rb') as img_file:
            img_data = img_file.read()
            image = MIMEImage(img_data)
            image.add_header('Content-Disposition', 'attachment', filename=os.path.basename(image_path))
            msg.attach(image)
    
    # Tentative 1: Envoi via sendmail local
    try:
        p = os.popen(f"/usr/sbin/sendmail -t -i", 'w')
        p.write(msg.as_string())
        status = p.close()
        
        if status is None:
            print(f"✅ Email envoyé via sendmail local à {recipient}")
            return True
    except Exception as e:
        print(f"⚠️ Échec envoi via sendmail local: {str(e)}")
    
    # Tentative 2: Enregistrer dans un fichier
    try:
        email_file = os.path.join(report_dir, f"notification_{date_str}.eml")
        with open(email_file, 'w') as f:
            f.write(msg.as_string())
        print(f"✅ Email enregistré dans le fichier: {email_file}")
        
        # Créer aussi une version texte simple
        text_file = os.path.join(report_dir, f"notification_{date_str}.txt")
        with open(text_file, 'w') as f:
            f.write(f"To: {recipient}\n")
            f.write(f"Subject: {subject}\n\n")
            f.write(message)
            f.write(f"\n\nNote: Une image est jointe à cet email. Vous pouvez la voir ici: {image_path}")
        print(f"✅ Version texte enregistrée dans: {text_file}")
        
        return True
    except Exception as e:
        print(f"⚠️ Échec enregistrement de l'email: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 send_email.py destinataire sujet fichier_message repertoire_rapport")
        sys.exit(1)
    
    recipient = sys.argv[1]
    subject = sys.argv[2]
    
    try:
        with open(sys.argv[3], 'r') as f:
            message = f.read()
    except Exception as e:
        print(f"❌ Erreur lecture fichier message: {str(e)}")
        sys.exit(1)
    
    report_dir = sys.argv[4]
    date_str = datetime.now().strftime("%Y-%m-%d")
    
    success = send_email(recipient, subject, message, report_dir, date_str)
    sys.exit(0 if success else 1)
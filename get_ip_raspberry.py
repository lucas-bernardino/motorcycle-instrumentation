import os
import smtplib
from email.mime.text import MIMEText
import imaplib
from time import sleep

GMAIL_PASSWORD = "uskv xvhu voki qdcx"

def send_email():
    subject = "IP"
    body = "EU DEVERIA ENVIAR A URL AQUI"
    sender = "projetomotobmw@gmail.com"
    recipients = ["projetomotobmw@gmail.com"]
    password = GMAIL_PASSWORD
    
    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = ', '.join(recipients)
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp_server:
       smtp_server.login(sender, password)
       smtp_server.sendmail(sender, recipients, msg.as_string())
    print("Message sent!")

def format_raw_email(raw_email):
    content = []
    tmp = ""
    for l in raw_email:
        if l == "\n":
            content.append("".join(tmp))
            tmp = ""
        elif l != "\r":
            tmp += l
    return content

def get_email():
    mail = imaplib.IMAP4_SSL('imap.gmail.com')
    mail.login('projetomotobmw@gmail.com', GMAIL_PASSWORD)
    mail.list()
    mail.select("inbox") # connect to inbox.

    result, data = mail.search(None, '(FROM "me" SUBJECT "IP")' )
    ids = data[0]
    id_list = ids.split()
    latest_email_id = id_list[-1]

    result, data = mail.fetch(latest_email_id, "(RFC822)")
    raw_email = (data[0][1]).decode("utf-8")
    content = format_raw_email(raw_email)

    url = content[-1]
    return url

#get_email()
#send_email()
if __name__ == "__main__":
    # print(send_email())
    # sleep(5)
    # print("Vou verificar a caixa de entradas")
    print(get_email())

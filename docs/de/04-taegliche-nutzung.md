# Tägliche Nutzung

JaanOS Core ersetzt verschachtelte Menüstrukturen durch eine minimalistische, textbasierte Benutzeroberfläche (Zero UI). Kern des Systems ist der **Neural Core**, der Ihre natürlichsprachlichen Anweisungen in sichere ERP-Befehle übersetzt.

## Das zentrale Eingabefeld (Neural Core)

Über das zentrale Eingabefeld steuern Sie Ihr angebundenes System. Geben Sie dort einfach in Alltagssprache ein, was Sie tun oder abfragen möchten. Der Neural Core analysiert die Anfrage, ermittelt die betroffene Tabelle und führt die entsprechende Aktion aus.

---

## Beispiel-Anweisungen

Hier sind typische Anweisungen, die Sie im täglichen Betrieb nutzen können (entnommen aus den interaktiven Beispielen):

### 1. Daten abfragen
* **Eingabe:** `Zeige alle offenen Rechnungen über 10.000 €`
  * **Wirkung:** Führt eine Abfrage auf `account.invoice` aus, filtert nach dem Status `posted` (gebucht) und Beträgen größer als 10.000 € und listet die Treffer übersichtlich auf.
* **Eingabe:** `Zeige mir offene Kundenaufträge über 15.000 €`
  * **Wirkung:** Durchsucht `sale.order` nach Aufträgen im Bearbeitungsstatus (`processing`) mit einem Gesamtwert über 15.000 €.

### 2. Datensätze erstellen
* **Eingabe:** `Erstelle Lead für Müller GmbH`
  * **Wirkung:** Erstellt einen neuen Datensatz in `sale.opportunity` (Verkaufschance) für den entsprechenden Partner.
* **Eingabe:** `Erstelle einen neuen Kontakt: TechCorp GmbH, München`
  * **Wirkung:** Legt einen Partnerdatensatz in `party.party` mit dem Namen `TechCorp GmbH` und einer verknüpften Adresse in `München` an.

---

## Kennzahlen & KPI-Dashboard

Zusätzlich zur Texteingabe visualisiert JaanOS Core wichtige Kennzahlen direkt im Dashboard. Diese Kennzahlen werden in Echtzeit aus Ihrem ERP-System abgerufen.
* **Live-Daten:** Es findet keine dauerhafte Zwischenspeicherung oder Aggregation auf Drittsystemen statt. Die Werte entsprechen dem exakten, aktuellen Zustand Ihrer ERP-Datenbank.
* **Dynamische Korrelation:** Der Neural Core verknüpft offene Posten und Projektstatus, um proaktiv Warnungen (z. B. bei drohendem Zahlungsverzug) anzuzeigen.

---

## Grenzen und Sorgfaltspflichten (Wichtige Hinweise)

Obwohl der Neural Core Befehle deterministisch übersetzt, handelt es sich um ein KI-gestütztes System. Beachten Sie daher folgende Regeln für den sicheren Betrieb:

* **Prüfpflicht:** Generative KI-Modelle können in seltenen Fällen Anweisungen falsch interpretieren oder fehlerhafte ORM-Abfragen generieren. Überprüfen Sie vorgeschlagene Aktionen und Buchungsentwürfe stets sorgfältig vor der finalen Freigabe.
* **Keine Haftung für Fehlbuchungen:** Die Verantwortung für die Richtigkeit von Buchungen und Transaktionen liegt ausschließlich beim Anwender. JaanIQ übernimmt gemäß EULA keine Haftung für fehlerhafte Datensätze oder finanzielle Schäden, die aus der Nutzung der KI-Schnittstelle resultieren.
* **Grenzbereiche:** Komplexe steuerliche Sonderfälle oder Massenänderungen sollten weiterhin über das native Interface von Tryton bzw. Lexware vorgenommen werden.

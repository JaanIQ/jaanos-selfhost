# Updates & Wartung

JaanOS Core ist so konzipiert, dass der Wartungsaufwand für Administratoren minimal ist. Das System aktualisiert sich im Standard vollautomatisch und wendet anstehende Datenbank-Migrationen selbstständig an.

## Automatische Updates über Watchtower

In der Standardkonfiguration (`docker-compose.yml`) ist der Update-Dienst **Watchtower** integriert.
* **Funktionsweise:** Watchtower prüft alle 24 Stunden (Intervall: `86400` Sekunden), ob in der GitHub Container Registry (GHCR) ein aktualisiertes Docker-Image für `jaanos-suite` bereitgestellt wurde.
* **Ablauf:** Wenn ein neues Image vorhanden ist, lädt Watchtower dieses herunter, stoppt den laufenden Container kurzzeitig und startet ihn mit dem neuen Image und denselben Konfigurationseinstellungen neu.
* **Vorteil:** Sicherheitsupdates und Funktionsverbesserungen werden ohne manuellen Eingriff zeitnah eingespielt.

---

## Manuelle Updates

Wenn Sie ein Update sofort erzwingen möchten oder Konfigurationsänderungen in der `.env` vorgenommen haben, können Sie das Update manuell durchführen.

Wechseln Sie in das Installationsverzeichnis (Standard: `/opt/jaanos`) und führen Sie folgende Befehle aus:

```bash
cd /opt/jaanos
docker compose pull
docker compose up -d
```

Alternativ können Sie das offizielle Installationsskript einfach erneut ausführen. Es erkennt Ihre bestehende Installation und führt die Aktualisierung sicher durch:

```bash
curl -fsSL https://jaanos.com/install.sh | bash
```

---

## Datengarantie bei Updates

Während des Update-Vorgangs (sowohl automatisch als auch manuell) sind Ihre Daten zu jedem Zeitpunkt geschützt:
* **Persistente Volumes:** Die PostgreSQL-Datenbank von JaanOS liegt in einem dedizierten Docker-Volume (`postgres_data`). Dieses Volume bleibt beim Neuerstellen der Container vollständig unangetastet.
* **Erhalt der Konfiguration:** Da alle sicherheitsrelevanten Einstellungen und geheimen Schlüssel in der Datei `/opt/jaanos/.env` gespeichert sind, liest der neu gestartete Container diese Werte sofort wieder ein. Ihr `ENCRYPTION_KEY` bleibt identisch, wodurch die Entschlüsselung Ihrer ERP-Credentials weiterhin reibungslos funktioniert.

---

## Automatische Schema-Migrationen beim Booten

Wenn sich das Datenbankschema von JaanOS bei einem Update ändert, müssen die Tabellen in der PostgreSQL-Datenbank angepasst werden.
* **Automatischer Ablauf:** In der `docker-compose.yml` ist die Variable `RUN_MIGRATIONS_ON_BOOT=true` gesetzt.
* **Wirkung:** Bei jedem Start des Containers `jaanos-suite` (also auch nach jedem Update) prüft das System vor dem Start des Webservers, ob neue Schema-Migrationen ausstehend sind, und führt diese automatisch aus. Es ist kein manueller Befehl zur Datenbankmigration erforderlich.

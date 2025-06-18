
---

# 🐳 DOCMAN – Docker Admin Dashboard v2.5

A powerful and interactive terminal-based Docker management tool. Secure, efficient, and perfect for both Red Teamers and DevOps engineers.

## ✨ Features

- 🔒 **Secure Login System**  
  First-time admin registration with SHA-256 password hashing.

- 🗄️ **SQLite Database Integration**  
  Stores user credentials and access logs securely.

- 📦 **Full Container Management**  
  Start, stop, remove containers and launch bash inside them.

- 🖼️ **Image Management**  
  List, pull, and delete Docker images.

- 🌐 **Network Management**  
  Create, remove, and inspect Docker networks.

- 📊 **Live Resource Graph**  
  Displays real-time container CPU & RAM usage.

- 📁 **Reports & Snapshots**  
  - Export full container info to reports
  - Save live snapshots of containers as `.tar` files
  - Security scan using [Trivy](https://github.com/aquasecurity/trivy)

- 🔐 **One-time Setup**  
  Automatically checks for first-time use and creates:
  - Database
  - Admin account
  - Configuration directories

- 📚 **Organized Output**  
  - All reports go to: `reports/`
  - Snapshots saved in: `snapshots/`
  - Logs stored in: `logs/`

---

## 🚀 Installation

```bash
chmod +x setup.sh
./setup.sh
````

This will:

* Install required packages
* Set up the SQLite database
* Prompt for admin username and password (only once)
* Create required directories

---

## 🧠 Usage

After running the setup once:

```bash
./docman.sh
```

You will be prompted to log in, and the main menu will appear.

---

## 📁 Project Structure

```
docman.sh          # Main tool
setup.sh           # Installer
uninstall.sh       # Full cleanup script
.config/users.db   # SQLite database for user accounts
reports/           # Container info reports
snapshots/         # Container .tar snapshots
logs/              # Optional logs
usage_graph.txt    # Live resource stats
```

---

## 🛠️ Dependencies

* Docker
* Trivy (for security scanning)
* SQLite3
* Bash

All dependencies are handled automatically via `setup.sh`.

---

## 🧩 Coming Soon (Planned Features)

* ✅ Import container by name
* ✅ Save logs in DB instead of plain text
* 🔄 Web interface (optional)
* 📅 Scheduler for automated scans
* 🔍 CVE integration with Trivy results

---

## 📜 License

MIT License – Free to use and modify. Please give credit if reused in public tools.

---

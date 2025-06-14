#!/bin/bash

# =============================
#        DOCKMAN v2.5
#   Docker Admin Dashboard
#   Author: Riyad Ridwan
# =============================

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_DIR="$BASE_DIR/.config"
REPORTS_DIR="$BASE_DIR/reports"
SNAPSHOTS_DIR="$BASE_DIR/snapshots"
LOG_DIR="$BASE_DIR/logs"
DB_FILE="$CONFIG_DIR/dockman.db"
TOKEN_FILE="$CONFIG_DIR/.session_token"
GRAPH_FILE="$BASE_DIR/usage_graph.txt"

mkdir -p "$CONFIG_DIR" "$REPORTS_DIR" "$SNAPSHOTS_DIR" "$LOG_DIR"

init_db() {
  if [ ! -f "$DB_FILE" ]; then
    sqlite3 "$DB_FILE" "
      CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        password TEXT,
        role TEXT
      );
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,
        action TEXT,
        username TEXT
      );
    "
    echo "[+] SQLite database initialized."
  fi
}

generate_token() {
  echo "$1-$(date +%s)" | sha256sum | awk '{print $1}' > "$TOKEN_FILE"
}

check_token() {
  [[ -f "$TOKEN_FILE" ]] || return 1
  return 0
}

hash_password() {
  echo "$1" | sha256sum | awk '{print $1}'
}

register_admin() {
  echo "[+] First time setup. Create an admin user."
  read -p "Username: " USERNAME
  read -s -p "Password: " PASSWORD
  echo
  PASS_HASH=$(hash_password "$PASSWORD")
  sqlite3 "$DB_FILE" "INSERT INTO users VALUES ('$USERNAME', '$PASS_HASH', 'admin');"
  echo "[+] Admin registered successfully."
}

login() {
  echo "== LOGIN =="
  read -p "Username: " USERNAME
  read -s -p "Password: " PASSWORD
  echo
  PASS_HASH=$(hash_password "$PASSWORD")
  MATCH=$(sqlite3 "$DB_FILE" "SELECT username FROM users WHERE username='$USERNAME' AND password='$PASS_HASH';")
  if [[ "$MATCH" == "$USERNAME" ]]; then
    echo "[+] Login successful."
    generate_token "$USERNAME"
    sqlite3 "$DB_FILE" "INSERT INTO logs (timestamp, action, username) VALUES ('$(date)', 'Login', '$USERNAME');"
  else
    echo "[-] Invalid credentials."
    exit 1
  fi
}

show_graph() {
  echo "[+] Monitoring containers..."
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee "$GRAPH_FILE"
}

export_container_info() {
  read -p "Enter container name or ID: " CNAME
  INFO_FILE="$REPORTS_DIR/$CNAME-info.txt"
  echo "[+] Exporting container info to $INFO_FILE..."
  docker inspect "$CNAME" > "$INFO_FILE"
  echo "[✓] Done."
}

create_snapshot() {
  read -p "Container name: " CNAME
  SNAPSHOT_FILE="$SNAPSHOTS_DIR/$CNAME-$(date +%s).tar"
  docker export "$CNAME" -o "$SNAPSHOT_FILE"
  echo "[✓] Snapshot saved to $SNAPSHOT_FILE"
}

check_role() {
  ROLE=$(sqlite3 "$DB_FILE" "SELECT role FROM users WHERE username='$1';")
  echo "$ROLE"
}

security_scan() {
  read -p "Container/Image name: " TARGET
  echo "[+] Running Trivy scan on $TARGET..."
  trivy image "$TARGET" | tee "$SNAPSHOTS_DIR/$TARGET-trivy.txt"
}

manage_containers() {
  echo "=== Manage Containers ==="
  docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}"
  echo "1. Start"
  echo "2. Stop"
  echo "3. Remove"
  echo "4. Exec Bash"
  read -p "Select action: " act
  read -p "Container ID/Name: " id
  case $act in
    1) docker start "$id";;
    2) docker stop "$id";;
    3) docker rm "$id";;
    4) docker exec -it "$id" /bin/bash;;
    *) echo "Invalid";;
  esac
}

manage_images() {
  echo "=== Manage Images ==="
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
  echo "1. Remove Image"
  echo "2. Pull Image"
  read -p "Select action: " act
  case $act in
    1) read -p "Image ID: " iid; docker rmi "$iid";;
    2) read -p "Image Name:Tag: " name; docker pull "$name";;
    *) echo "Invalid";;
  esac
}

manage_networks() {
  echo "=== Manage Networks ==="
  docker network ls
  echo "1. Inspect"
  echo "2. Remove"
  echo "3. Create"
  read -p "Action: " act
  case $act in
    1) read -p "Network ID/Name: " nid; docker network inspect "$nid";;
    2) read -p "Network ID/Name: " nid; docker network rm "$nid";;
    3) read -p "New network name: " nname; docker network create "$nname";;
    *) echo "Invalid";;
  esac
}

main_menu() {
  while true; do
    echo "\n===== DOCKMAN MENU ====="
    echo "1. Live Usage Graph"
    echo "2. Export Container Info"
    echo "3. Snapshot Container"
    echo "4. Security Scan (Trivy)"
    echo "5. Manage Containers"
    echo "6. Manage Images"
    echo "7. Manage Networks"
    echo "8. Exit"
    echo "========================="
    read -p "Select: " opt
    case $opt in
      1) show_graph;;
      2) export_container_info;;
      3) create_snapshot;;
      4) security_scan;;
      5) manage_containers;;
      6) manage_images;;
      7) manage_networks;;
      8) echo "[+] Bye!"; exit 0;;
      *) echo "[-] Invalid option";;
    esac
  done
}

if [ ! -f "$DB_FILE" ]; then
  init_db
  register_admin
else
  echo "[i] Database found."
fi

if ! check_token; then
  login
fi

main_menu

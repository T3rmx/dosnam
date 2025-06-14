#!/bin/bash

# =============================
#        DOCKMAN v2.6
#   Docker Admin Dashboard
# =============================

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_DIR="$BASE_DIR/.config"
REPORTS_DIR="$BASE_DIR/reports"
SNAPSHOTS_DIR="$BASE_DIR/snapshots"
LOG_DIR="$BASE_DIR/logs"
DB_FILE="$CONFIG_DIR/dockman.db"
TOKEN_FILE="$CONFIG_DIR/.session_token"
GRAPH_FILE="$BASE_DIR/usage_graph.txt"
TOKEN_VALIDITY=1800  # 30 minutes

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
    echo -e "${GREEN}[+] SQLite database initialized.${NC}"
  fi
}

check_user_exists() {
  EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;")
  if [ "$EXISTS" -eq 0 ]; then
    echo -e "${RED}[!] No users found in database. Please run the setup script to add an admin user.${NC}"
    exit 1
  fi
}

hash_password() {
  echo "$1" | sha256sum | awk '{print $1}'
}

generate_token() {
  local username="$1"
  local timestamp=$(date +%s)
  local hash=$(echo -n "$username-$timestamp" | sha256sum | awk '{print $1}')
  echo "$username-$timestamp-$hash" > "$TOKEN_FILE"
}

check_token() {
  if [[ ! -f "$TOKEN_FILE" ]]; then
    return 1
  fi

  IFS='-' read -r token_user token_time token_hash < "$TOKEN_FILE"

  local computed_hash=$(echo -n "$token_user-$token_time" | sha256sum | awk '{print $1}')
  if [[ "$computed_hash" != "$token_hash" ]]; then
    return 1
  fi

  local now=$(date +%s)
  local elapsed=$(( now - token_time ))

  if (( elapsed > TOKEN_VALIDITY )); then
    return 1
  fi

  return 0
}

login() {
  echo -e "${BLUE}== LOGIN ==${NC}"
  read -p "Username: " USERNAME
  read -s -p "Password: " PASSWORD
  echo
  PASS_HASH=$(hash_password "$PASSWORD")
  MATCH=$(sqlite3 "$DB_FILE" "SELECT username FROM users WHERE username='$USERNAME' AND password='$PASS_HASH';")
  if [[ "$MATCH" == "$USERNAME" ]]; then
    echo -e "${GREEN}[+] Login successful.${NC}"
    generate_token "$USERNAME"
    sqlite3 "$DB_FILE" "INSERT INTO logs (timestamp, action, username) VALUES ('$(date)', 'Login', '$USERNAME');"
  else
    echo -e "${RED}[-] Invalid credentials.${NC}"
    exit 1
  fi
}

show_graph() {
  echo -e "${BLUE}[+] Monitoring containers...${NC}"
  sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee "$GRAPH_FILE"
  read -p "Press Enter to return to menu..."
  clear
}

export_container_info() {
  read -p "Enter container name or ID: " CNAME
  INFO_FILE="$REPORTS_DIR/$CNAME-info.txt"
  echo -e "${BLUE}[+] Exporting container info to $INFO_FILE...${NC}"
  sudo docker inspect "$CNAME" > "$INFO_FILE"
  echo -e "${GREEN}[✓] Done.${NC}"
  read -p "Press Enter to return to menu..."
  clear
}

create_snapshot() {
  read -p "Enter container name: " CNAME
  SNAPSHOT_FILE="$SNAPSHOTS_DIR/$CNAME-$(date +%s).tar"
  sudo docker export "$CNAME" -o "$SNAPSHOT_FILE"
  echo -e "${GREEN}[✓] Snapshot saved to $SNAPSHOT_FILE${NC}"
  read -p "Press Enter to return to menu..."
  clear
}

check_role() {
  ROLE=$(sqlite3 "$DB_FILE" "SELECT role FROM users WHERE username='$1';")
  echo "$ROLE"
}

security_scan() {
  read -p "Enter container/image name: " TARGET
  echo -e "${YELLOW}[+] Running Trivy scan on $TARGET...${NC}"
  sudo trivy image "$TARGET" | tee "$SNAPSHOTS_DIR/$TARGET-trivy.txt"
  read -p "Press Enter to return to menu..."
  clear
}

manage_containers() {
  while true; do
    echo -e "\n${BLUE}=== Manage Containers ===${NC}"
    sudo docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}"
    echo -e "${YELLOW}1. Start\n2. Stop\n3. Remove\n4. Exec Bash\n0. Back${NC}"
    read -p "Select action: " act
    [[ "$act" == "0" ]] && clear && return
    read -p "Container ID/Name: " id
    case $act in
      1) sudo docker start "$id";;
      2) sudo docker stop "$id";;
      3) sudo docker rm "$id";;
      4) sudo docker exec -it "$id" /bin/bash;;
      *) echo -e "${RED}Invalid option${NC}";;
    esac
    read -p "Press Enter to continue..."
    clear
  done
}

manage_images() {
  while true; do
    echo -e "\n${BLUE}=== Manage Images ===${NC}"
    sudo docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    echo -e "${YELLOW}1. Remove Image\n2. Pull Image\n0. Back${NC}"
    read -p "Select action: " act
    case $act in
      0) clear; return;;
      1) read -p "Image ID: " iid; docker rmi "$iid";;
      2) read -p "Image Name:Tag: " name; docker pull "$name";;
      *) echo -e "${RED}Invalid option${NC}";;
    esac
    read -p "Press Enter to continue..."
    clear
  done
}

manage_networks() {
  while true; do
    echo -e "\n${BLUE}=== Manage Networks ===${NC}"
    sudo docker network ls
    echo -e "${YELLOW}1. Inspect\n2. Remove\n3. Create\n0. Back${NC}"
    read -p "Select action: " act
    case $act in
      0) clear; return;;
      1) read -p "Network ID/Name: " nid; docker network inspect "$nid";;
      2) read -p "Network ID/Name: " nid; docker network rm "$nid";;
      3) read -p "New network name: " nname; docker network create "$nname";;
      *) echo -e "${RED}Invalid option${NC}";;
    esac
    read -p "Press Enter to continue..."
    clear
  done
}

main_menu() {
  while true; do
    echo -e "\n${BLUE}===== DOCKMAN MENU =====${NC}"
    echo -e "${YELLOW}1. Live Usage Graph\n2. Export Container Info\n3. Snapshot Container\n4. Security Scan (Trivy)\n5. Manage Containers\n6. Manage Images\n7. Manage Networks\n8. Exit${NC}"
    read -p "Select: " opt
    case $opt in
      1) show_graph;;
      2) export_container_info;;
      3) create_snapshot;;
      4) security_scan;;
      5) manage_containers;;
      6) manage_images;;
      7) manage_networks;;
      8) echo -e "${GREEN}[+] Bye!${NC}"; exit 0;;
      *) echo -e "${RED}[-] Invalid option${NC}";;
    esac
  done
}

if [ ! -f "$DB_FILE" ]; then
  init_db
else
  echo -e "${YELLOW}[i] Database found.${NC}"
fi

check_user_exists

if ! check_token; then
  login
else
  echo -e "${GREEN}[i] Valid session detected.${NC}"
fi

main_menu

#!/bin/bash

# 🛠️ DOCKER ADMIN TOOL SETUP SCRIPT
# Author: Riyad Ridwan

TOOL_NAME="docman"
TOOL_SCRIPT="./docman.sh"
DB_FILE=".config/docman_users.db"
SESSION_FILE=".config/.session_token"
ALIAS_NAME="docman"
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == *zsh* ]] && SHELL_RC="$HOME/.zshrc"

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

# 🧱 Create required directories
mkdir -p reports snapshots logs .config

# 🔍 Check for dependencies
check_deps() {
  echo -e "${YELLOW}[+] Checking requirements...${NC}"
  for pkg in sqlite3 openssl docker; do
    if ! command -v $pkg &>/dev/null; then
      echo -e "${RED}[-] Package '$pkg' is not installed.${NC}"
      echo -e "${YELLOW}Installing $pkg...${NC}"
      sudo apt update && sudo apt install -y $pkg
    fi
  done
}

# 🔐 Hash password using SHA256
hash_password() {
  echo -n "$1" | openssl dgst -sha256 | awk '{print $2}'
}

# 👤 Create admin user in DB
create_user() {
  echo -e "${YELLOW}[?] Enter your admin username:"
  read -r username
  echo -e "${YELLOW}[?] Enter password:"
  read -rs password
  echo
  hashed_pass=$(hash_password "$password")

  sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  role TEXT DEFAULT 'admin'
);
INSERT INTO users (username, password) VALUES ('$username', '$hashed_pass');
EOF

  echo -e "${GREEN}[+] Admin user '$username' created successfully.${NC}"
}

# ✅ Check if setup already done
check_already_setup() {
  if [ -f "$DB_FILE" ]; then
    echo -e "${GREEN}[✔] Setup already completed. Skipping user creation.${NC}"
    return 0
  else
    return 1
  fi
}

chmod +x "$TOOL_SCRIPT"

# 🔗 Add alias
add_alias() {
  ABS_PATH=$(realpath "$TOOL_SCRIPT")
  if ! grep -q "alias $ALIAS_NAME=" "$SHELL_RC"; then
    echo -e "${YELLOW}[+] Creating alias '${ALIAS_NAME}' in $SHELL_RC...${NC}"
    echo "alias $ALIAS_NAME=\"$ABS_PATH\"" >> "$SHELL_RC"
    source "$SHELL_RC"
    echo -e "${GREEN}[✔] Alias added. Use '$ALIAS_NAME' to run the tool.${NC}"
  else
    echo -e "${GREEN}[✔] Alias '$ALIAS_NAME' already exists.${NC}"
  fi
}

# 🧪 Create session token for current user
create_session_token() {
  token=$(openssl rand -hex 32)
  echo "$token" > "$SESSION_FILE"
  echo -e "${GREEN}[✔] Session initialized.${NC}"
}

# 🚀 Main Execution
main() {
  check_deps

  if check_already_setup; then
    echo -e "${YELLOW}[i] If you want to reset, please remove: ${DB_FILE}${NC}"
  else
    create_user
  fi

  add_alias
  create_session_token

  echo -e "${GREEN}[✓] Setup Complete. Run '${ALIAS_NAME}' to start.${NC}"
}

main

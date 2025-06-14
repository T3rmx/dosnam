#!/bin/bash

TOOL_NAME="dockman"
TOOL_SCRIPT="docman.sh"
DB_FILE=".config/dockman.db"
SESSION_FILE=".config/.session_token"
ALIAS_NAME="docman"
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && SHELL_RC="$HOME/.bashrc"

# 🎨 Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

# 🧱 Create required directories
mkdir -p reports snapshots logs .config

# 🔍 Check dependencies
check_deps() {
  echo -e "${YELLOW}[+] Checking requirements...${NC}"
  for pkg in sqlite3 openssl docker; do
    if ! command -v "$pkg" &>/dev/null; then
      echo -e "${RED}[-] Missing: $pkg${NC}"
      echo -e "${YELLOW}[*] Installing $pkg...${NC}"
      sudo apt update && sudo apt install -y "$pkg"
    else
      echo -e "${GREEN}[✓] $pkg found.${NC}"
    fi
  done
}

# 🔐 Hash password using SHA256
hash_password() {
# echo -n "$1" | openssl dgst -sha256 | awk '{print $2}'
echo "$1" | sha256sum | awk '{print $1}'

}

# 👤 Create admin user
create_user() {
  echo -e "${YELLOW}[?] Enter admin username:${NC}"
  read -r username

  echo -e "${YELLOW}[?] Enter password:${NC}"
  read -rs password
  echo

  hashed_pass=$(hash_password "$password")

  # إنشاء الجدول إذا لم يكن موجود
  sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS users (
  username TEXT PRIMARY KEY,
  password TEXT NOT NULL,
  role TEXT DEFAULT 'admin'
);
CREATE TABLE IF NOT EXISTS logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT,
  action TEXT,
  username TEXT
);
EOF

  # التحقق إذا المستخدم موجود مسبقًا
  EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE username='$username';")
  if [[ "$EXISTS" -eq 0 ]]; then
    sqlite3 "$DB_FILE" "INSERT INTO users (username, password, role) VALUES ('$username', '$hashed_pass', 'admin');"
    echo -e "${GREEN}[✓] Admin user '$username' created successfully.${NC}"
  else
    echo -e "${BLUE}[i] User '$username' already exists in database.${NC}"
  fi
}

# ✅ Check if setup already done (with real user check)
check_already_setup() {
  if [[ -f "$DB_FILE" ]]; then
    COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;")
    if [[ "$COUNT" -gt 0 ]]; then
      echo -e "${GREEN}[✔] Setup already completed with users in database.${NC}"
      return 0
    fi
  fi
  return 1
}

# 🔁 Reset setup
reset_setup() {
  echo -e "${RED}[!] Resetting Dockman setup...${NC}"
  rm -f "$DB_FILE" "$SESSION_FILE"
  sed -i "/alias $ALIAS_NAME=/d" "$SHELL_RC"
  echo -e "${GREEN}[✓] Reset complete. You can rerun the setup now.${NC}"
  exit 0
}

# 🔗 Add alias
add_alias() {
  ABS_PATH=$(realpath "$TOOL_SCRIPT")

  if grep -q "alias $ALIAS_NAME=" "$SHELL_RC"; then
    echo -e "${GREEN}[✔] Alias '$ALIAS_NAME' already exists.${NC}"
  else
    echo -e "${YELLOW}[+] Adding alias '$ALIAS_NAME' to $SHELL_RC...${NC}"
    echo "alias $ALIAS_NAME=\"$ABS_PATH\"" >> "$SHELL_RC"
    echo -e "${GREEN}[✓] Alias added. Reload your shell or run: source $SHELL_RC${NC}"
  fi
}
source "$SHELL_RC"
# 🧪 Create session token
create_session_token() {
  token=$(openssl rand -hex 32)
  echo "$token" > "$SESSION_FILE"
  echo -e "${GREEN}[✓] Session token created.${NC}"
}

# 🚀 Main Execution
main() {
  # دعم --reset
  if [[ "$1" == "--reset" ]]; then
    reset_setup
  fi

  chmod +x "$TOOL_SCRIPT"
  check_deps

  if check_already_setup; then
    echo -e "${YELLOW}[i] To reset, use: ./setup.sh --reset${NC}"
  else
    create_user
  fi

  add_alias
  create_session_token

  echo -e "${GREEN}[✓] Setup Complete.${NC}"
  echo -e "${YELLOW}[→] You can now run '${ALIAS_NAME}' in any terminal session.${NC}"
}

main "$@"

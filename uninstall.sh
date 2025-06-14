#!/bin/bash

# DOCKER ADMIN TOOL UNINSTALLER
ALIAS_NAME="docman"
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == *zsh* ]] && SHELL_RC="$HOME/.zshrc"

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

echo -e "${YELLOW}[i] Stopping Docker Admin Tool and cleaning up...${NC}"

# Remove alias from shell config
if grep -q "alias $ALIAS_NAME=" "$SHELL_RC"; then
  echo -e "${YELLOW}[-] Removing alias '$ALIAS_NAME' from $SHELL_RC...${NC}"
  sed -i "/alias $ALIAS_NAME=/d" "$SHELL_RC"
  source "$SHELL_RC"
  echo -e "${GREEN}[✔] Alias removed.${NC}"
else
  echo -e "${GREEN}[✔] Alias '$ALIAS_NAME' not found in $SHELL_RC.${NC}"
fi

# Remove directories and files
echo -e "${YELLOW}[-] Removing tool files and folders...${NC}"
rm -rf ./reports ./snapshots ./logs .config

# Remove the tool script if exists
if [ -f ./docman.sh ]; then
  echo -e "${YELLOW}[-] Removing docman.sh script...${NC}"
  rm -f ./docman.sh
fi

echo -e "${GREEN}[✔] Cleanup complete!${NC}"
echo -e "${RED}[!] Note: If you want to remove setup.sh and uninstall.sh manually, please delete them yourself.${NC}"

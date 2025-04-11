#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[-] $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# Install Chaos
print_status "Installing Chaos..."
if command_exists go; then
    go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest
    print_success "Chaos installed successfully"
else
    print_error "Go is not installed. Please install Go first"
    exit 1
fi

# Install Subfinder
print_status "Installing Subfinder..."
if command_exists go; then
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    print_success "Subfinder installed successfully"
else
    print_error "Go is not installed. Please install Go first"
    exit 1
fi

# Install Anubis dependencies
print_status "Installing Anubis dependencies..."
apt-get update
apt-get install -y python3-pip python-dev libssl-dev libffi-dev
print_success "Anubis dependencies installed successfully"

# Install Anubis
print_status "Installing Anubis..."
pip3 install anubis-netsec
print_success "Anubis installed successfully"

# Install SubEnum
print_status "Installing SubEnum..."
if [ -d "SubEnum" ]; then
    print_status "SubEnum directory already exists. Updating..."
    cd SubEnum
    git pull
else
    git clone https://github.com/bing0o/SubEnum.git
    cd SubEnum
fi
chmod +x setup.sh
./setup.sh
print_success "SubEnum installed successfully"
cd ..

# Add SubEnum alias to zshrc
print_status "Adding SubEnum alias to zshrc..."
echo 'alias subenum="bash $HOME/SubEnum/subenum.sh"' >> ~/.zshrc
print_success "SubEnum alias added to zshrc"

# Add AbuseIPDB function to zshrc
print_status "Adding AbuseIPDB function to zshrc..."
cat << 'EOF' >> ~/.zshrc
abuseipdb(){
        curl -s "https://www.abuseipdb.com/whois/$1" -H "user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36" -b "abuseipdb_session=YOUR-SESSION" | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -E '<li>\w.*</li>' | sed -E 's/<\/?li>//g' | sed "s|$|.$1|"
}
EOF
print_success "AbuseIPDB function added to zshrc"

# Install Subdominator
print_status "Installing Subdominator..."
if command_exists pipx; then
    pipx install git+https://github.com/RevoltSecurities/Subdominator
    print_success "Subdominator installed successfully"
else
    print_error "pipx is not installed. Please install pipx first"
    exit 1
fi

print_success "All tools have been installed successfully!"
print_status "Please restart your terminal or run 'source ~/.zshrc' to apply changes" 
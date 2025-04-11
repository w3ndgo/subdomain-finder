# Subdomain Finder Tools Setup

This tool uses multiple different tools for automated subdomain scanning. To use this tool, you need to install the following tools:

## Scope File Format

Create a file named `<project>_scope` (e.g., `example_scope`) in the same directory as the script. The file should contain one domain per line. For example:

```
example.com
test.com
domain.org
```

## Required Tools

### 1. Chaos
```bash
go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest
```

### 2. Subfinder
```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

### 3. Anubis
```bash
sudo apt-get install python3-pip python-dev libssl-dev libffi-dev
pip3 install anubis-netsec
```

### 4. SubEnum
```bash
git clone https://github.com/bing0o/SubEnum.git
cd SubEnum
chmod +x setup.sh
./setup.sh
```

Then add this line to your `~/.zshrc` file:
```bash
alias subenum='bash $HOME/SubEnum/subenum.sh'
```

### 5. AbuseIPDB
Add this line to your `~/.zshrc` file:
```bash
abuseipdb(){
        curl -s "https://www.abuseipdb.com/whois/$1" -H "user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36" -b "abuseipdb_session=YOUR-SESSION" | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -E '<li>\w.*</li>' | sed -E 's/<\/?li>//g' | sed "s|$|.$1|"
}
```

### 6. Subdominator
```bash
pipx install git+https://github.com/RevoltSecurities/Subdominator
```

## Installation Methods

There are two ways to install the tools:

1. **Manual Installation (Recommended)**: Install each tool separately using the commands above.

2. **Automatic Installation**: Use the `setup.sh` script:
```bash
chmod +x setup.sh
./setup.sh
```

Note: Manual installation is recommended because:
- You have more control over the installation process
- You can better diagnose potential issues
- You can install tools separately if needed

## Execution Process

1. **Prepare Scope Files**:
   - Create one or more `<project>_scope` files in the script directory
   - Each file should contain a list of domains (one per line)

2. **Run the Script**:
   - Execute the script: `./auto_enum.sh`
   - The script will automatically detect all `*_scope` files

3. **Output Structure**:
   - For each project, a directory will be created (e.g., `example/` for `example_scope`)
   - Inside each project directory:
     - Individual tool outputs (e.g., `example.com.anubis`, `example.com.chaos`, etc.)
     - A `final.txt` file containing all unique subdomains

4. **Example Output**:
```
example/
  ├── example.com.anubis
  ├── example.com.chaos
  ├── example.com.subfinder
  ├── example.com.abuseipdb
  ├── example.com.subenum
  ├── example.com.subdominator
  └── final.txt
```

5. **Progress Monitoring**:
   - The script shows real-time progress for each domain
   - Displays which tools have completed and which are still running
   - Shows a summary of results for each project at the end 
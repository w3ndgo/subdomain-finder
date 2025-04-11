#!/bin/bash
# Handle Ctrl+C and program termination
trap cleanup INT TERM EXIT

# Function to clean up all tmux sessions and processes
cleanup() {
  local trap_signal="$?"
  echo -e "\n⚠️ Cleaning up and exiting..."
  
  # Kill the tmux session if it exists
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
  fi
  
  # Kill any remaining background processes from this script
  jobs -p | xargs -r kill -9 2>/dev/null || true
  
  echo "✅ Cleanup completed"
  
  # Exit with the original exit code
  exit $trap_signal
}

# Show help message if -h or --help is passed
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "🔍 run_scans.sh - Automated Subdomain Scanner"
  echo
  echo "📄 Usage:"
  echo "  ./run_scans.sh"
  echo
  echo "📁 Requirements:"
  echo "  - Place one or more files named like '<project>_scope' in the same directory as this script."
  echo "  - Each file should contain a list of domains (one per line)."
  echo "  - tmux must be installed (sudo apt install tmux in WSL/Debian/Ubuntu)"
  echo
  echo "🔧 What it does:"
  echo "  - Creates a tmux session in the background for running all tools"
  echo "  - Detects all *_scope files automatically"
  echo "  - For each domain in each file:"
  echo "      * Creates a directory with the project name (e.g. 'tiktok' for tiktok_scope)"
  echo "      * Runs 6 tools in parallel:"
  echo "          - anubis"
  echo "          - chaos"
  echo "          - subfinder"
  echo "          - abuseipdb"
  echo "          - subenum"
  echo "          - subdominator"
  echo "      * Saves outputs in the project directory"
  echo "  - After all scans, combines and deduplicates results into final.txt inside that directory"
  echo
  echo "📂 Example output:"
  echo "  tiktok/"
  echo "    ├── example.com.anubis"
  echo "    ├── example.com.chaos"
  echo "    ├── ..."
  echo "    └── final.txt"
  echo
  echo "👨‍💻 Author: You 😎"
  exit 0
fi

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
  echo "Error: tmux is not installed. Please install it first:"
  echo "sudo apt install tmux"
  exit 1
fi

# Generate a unique session name using timestamp
SESSION_NAME="scan_session_$(date +%s)"

# Start a new tmux session in detached mode
tmux new-session -d -s "$SESSION_NAME"

# Main processing function to be run inside tmux
function run_scans() {
  for scope_file in *_scope; do
    [ -f "$scope_file" ] || continue
    
    # Extract project name (before "_")
    project_name=$(echo "$scope_file" | cut -d'_' -f1)
    echo "📁 Processing project: $project_name"
    
    # Create output directory
    mkdir -p "$project_name"
    
    # Loop through each domain in the scope file
    domain_count=0
    total_domains=$(grep -v '^$' "$scope_file" | wc -l)
    while IFS= read -r domain; do
      # Remove any carriage return characters (\r) and any extra spaces
      domain=$(echo "$domain" | tr -d '\r' | sed 's/[[:space:]]*$//')
      [ -z "$domain" ] && continue
      
      ((domain_count++))
      echo -e "\n🔍 Starting scan for domain: \033[1;32m$domain\033[0m"
      
      # Clean up existing panes first
      for i in {1..5}; do
        tmux kill-pane -t "$SESSION_NAME:0.$i" 2>/dev/null || true
      done
      
      # Make sure we start with a single clean pane
      tmux kill-pane -a -t "$SESSION_NAME:0.0" 2>/dev/null || true
      
      # Split tmux window into 6 panes with specific sizes
      tmux split-window -t "$SESSION_NAME:0" -h -p 50
      tmux split-window -t "$SESSION_NAME:0.0" -v -p 50
      tmux split-window -t "$SESSION_NAME:0.2" -v -p 50
      tmux select-pane -t "$SESSION_NAME:0.1"
      tmux split-window -t "$SESSION_NAME:0.1" -v -p 50
      tmux select-pane -t "$SESSION_NAME:0.0"
      tmux split-window -t "$SESSION_NAME:0.0" -v -p 50

      # No need for manual resize since we used percentages above
      
      # Create temporary status files to track progress
      rm -f /tmp/tool_*.done
      
      # Run tools in separate panes
      # Pane 0: anubis
      tmux send-keys -t "$SESSION_NAME:0.0" "anubis -t \"$domain\" -o \"${project_name}/${domain}.anubis\" && touch /tmp/tool_anubis.done" C-m
      
      # Pane 1: chaos
      tmux send-keys -t "$SESSION_NAME:0.1" "chaos -d \"$domain\" -o \"${project_name}/${domain}.chaos\" && touch /tmp/tool_chaos.done" C-m
      
      # Pane 2: subfinder
      tmux send-keys -t "$SESSION_NAME:0.2" "subfinder -d \"$domain\" -all -o \"${project_name}/${domain}.subfinder\" && touch /tmp/tool_subfinder.done" C-m
      
      # Pane 3: abuseipdb
      tmux send-keys -t "$SESSION_NAME:0.3" "abuseipdb \"$domain\" >> \"${project_name}/${domain}.abuseipdb\" && touch /tmp/tool_abuseipdb.done" C-m
      
      # Pane 4: subenum
      tmux send-keys -t "$SESSION_NAME:0.4" "subenum -d \"$domain\" -o \"${project_name}/${domain}.subenum\"; touch /tmp/tool_subenum.done" C-m
      
      # Pane 5: subdominator
      tmux send-keys -t "$SESSION_NAME:0.5" "subdominator -d \"$domain\" -all -o \"${project_name}/${domain}.subdominator\" && touch /tmp/tool_subdominator.done" C-m
      
      # Show progress in the main terminal
      tools=("anubis" "chaos" "subfinder" "abuseipdb" "subenum" "subdominator")
      total=${#tools[@]}
      completed=0
      
      # Define colors
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m' # No Color
      
      # Print initial status
      echo -ne "\033[K[${domain_count} of ${total_domains}] ${BLUE}$domain${NC} | ${YELLOW}Running: ${tools[*]}${NC}\r"
      
      # Continuously monitor for tool completion
      while [ $completed -lt $total ]; do
        completed=0
        completed_tools=()
        running_tools=()
        
        for tool in "${tools[@]}"; do
          if [ -f "/tmp/tool_${tool}.done" ]; then
            ((completed++))
            completed_tools+=("$tool")
          else
            running_tools+=("$tool")
          fi
        done
        
        # Print status in a single line
        if [ ${#completed_tools[@]} -gt 0 ]; then
          if [ $completed -eq $total ]; then
            echo -ne "\033[K[${domain_count} of ${total_domains}] ${BLUE}$domain${NC} | ${GREEN}✓ ${completed_tools[*]}${NC}\r"
          else
            echo -ne "\033[K[${domain_count} of ${total_domains}] ${BLUE}$domain${NC} | ${GREEN}✓ ${completed_tools[*]}${NC} | ${YELLOW}⏳ ${running_tools[*]}${NC}\r"
          fi
        fi
        
        # Exit loop if all tools completed
        [ $completed -eq $total ] && break
        
        sleep 1
      done
      
      echo -e "\n\033[K✅ ${BLUE}$domain${NC} | ${GREEN}All tools completed${NC}"
      
      # Clean up status files
      rm -f /tmp/tool_*.done
      
      # Kill all panes except the first one
      for i in {1..5}; do
        tmux kill-pane -t "$SESSION_NAME:0.$i" 2>/dev/null || true
      done
      
    done < "$scope_file"
    
    echo "📦 Merging and deduplicating results for project: $project_name"
    # Collect and merge all outputs into one final file
    cat ${project_name}/* | sort -u > "${project_name}/final.txt"
    echo "✅ Final result saved to: ${project_name}/final.txt"
    
    # Show summary for all domains in the project
    echo -e "\n📊 Summary of results for project: $project_name"
    echo "----------------------------------------"
    printf "%-12s | %-8s\n" "Tool" "Results"
    echo "----------------------------------------"
    
    # Count results from each tool for all domains
    local anubis_total=0
    local chaos_total=0
    local subfinder_total=0
    local abuseipdb_total=0
    local subenum_total=0
    local subdominator_total=0
    
    for domain in $(cat "$scope_file"); do
      anubis_total=$((anubis_total + $(wc -l < "${project_name}/${domain}.anubis" 2>/dev/null || echo 0)))
      chaos_total=$((chaos_total + $(wc -l < "${project_name}/${domain}.chaos" 2>/dev/null || echo 0)))
      subfinder_total=$((subfinder_total + $(wc -l < "${project_name}/${domain}.subfinder" 2>/dev/null || echo 0)))
      abuseipdb_total=$((abuseipdb_total + $(wc -l < "${project_name}/${domain}.abuseipdb" 2>/dev/null || echo 0)))
      subenum_total=$((subenum_total + $(wc -l < "${project_name}/${domain}.subenum" 2>/dev/null || echo 0)))
      subdominator_total=$((subdominator_total + $(wc -l < "${project_name}/${domain}.subdominator" 2>/dev/null || echo 0)))
    done
    
    local total_count=$(wc -l < "${project_name}/final.txt" 2>/dev/null || echo 0)
    
    printf "%-12s | %-8d\n" "Anubis" "$anubis_total"
    printf "%-12s | %-8d\n" "Chaos" "$chaos_total"
    printf "%-12s | %-8d\n" "Subfinder" "$subfinder_total"
    printf "%-12s | %-8d\n" "AbuseIPDB" "$abuseipdb_total"
    printf "%-12s | %-8d\n" "Subenum" "$subenum_total"
    printf "%-12s | %-8d\n" "Subdominator" "$subdominator_total"
    echo "----------------------------------------"
    printf "%-12s | %-8d\n" "Total Unique" "$total_count"
    echo "----------------------------------------"
    echo "----------------------------"
  done
}

# Run scans in the background
(
  run_scans
  
  # Kill the tmux session when done
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
) &

# Keep the main script running until all background processes complete
echo "⏳ Scans are running in background..."
echo "Press Ctrl+C to stop"
echo "----------------------------"

# Wait for the background process to complete
wait
echo "✅ All scans completed"
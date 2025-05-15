#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ASCII Art for welcome sign
ascii_art='

       # #######                      #     # #       
       # #       #####   ####   ####  ##   ## #       
       # #       #    # #    # #    # # # # # #       
       # #####   #    # #    # #      #  #  # #       
 #     # #       #####  #    # #  ### #     # #       
 #     # #       #   #  #    # #    # #     # #       
  #####  #       #    #  ####   ####  #     # ####### 
'
echo -e "${GREEN}$ascii_art${NC}"
echo -e "${GREEN}Welcome to the JFrogML Installer!${NC}"
echo "This script will perform the following actions:"
echo "1. Check for already installed CRDs (Custom Resource Definitions) in your Kubernetes cluster."
echo "2. Compare the versions of your installed CRDs with the expected versions."
echo "3. Install required CRDs for JFrogML only if necessary."
echo "4. Create the Kubernetes namespace 'jfrogml' if it doesn't already exist."
echo -e "${NC}\n"

# Ask the user if they want to proceed
read -p "Do you want to proceed? (y/n): " choice
case "$choice" in 
  y|Y ) echo -e "${GREEN}Proceeding with the installation...${NC}";;
  n|N ) echo -e "${YELLOW}Installation aborted by user.${NC}"; exit 0;;
  * ) echo -e "${RED}Invalid choice. Please run the script again and choose either 'y' or 'n'.${NC}"; exit 1;;
esac

# URLs of CRD YAMLs
CRD_URLS=(
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-podmonitors.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-servicemonitors.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-prometheusrules.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/istio.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/kafka.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/victoria-metrics.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/elasticsearch.yaml"
)

kubectl_check() {
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed or not in PATH.${NC}"
    echo "Please install kubectl by following the instructions here: https://kubernetes.io/docs/tasks/tools/#kubectl"
    exit 1
  fi
}

#!/bin/bash

check_k8s_context() {
    # Get the current Kubernetes context
    current_context=$(kubectl config current-context)
    
    if [ -z "$current_context" ]; then
        echo "No current Kubernetes context found."
        return 1
    fi
    
    # Display the current context
    echo -e "Current Kubernetes context: '${GREEN}$current_context${NC}'"
    
    # Prompt the user to confirm if it is the correct context
    read -p "Is this the correct context? (y/n): " user_input
    
    case $user_input in
        [Yy]*)
            echo -e "${GREEN}Context confirmed.${NC}"
            ;;
        [Nn]*)
            echo -e "Context not confirmed. Please update the context using '${YELLOW}kubectl config use-context <context-name>'${NC}."
            exit 1
            ;;
        *)
            echo -e "Invalid input. Please enter ${GREEN}'y'${NC} for yes or ${RED}'n'${NC} for no."
            ;;
    esac
}

create_namespace() {
  local namespace=$1
  if kubectl get namespace "$namespace" &> /dev/null; then
    echo -e "${YELLOW}Warning: Namespace '$namespace' already exists.${NC}"
  else
    echo "Creating namespace '$namespace'"
    kubectl create namespace "$namespace"
    echo -e "${GREEN}Namespace '$namespace' created successfully.${NC}"
  fi
}


# Function to extract a resource from the CRD file by name using yq
extract_resource_by_name() {
  local crd_file="$1"
  local resource_name="$2"

  if [ -z "$crd_file" ] || [ -z "$resource_name" ]; then
    echo "Usage: extract_resource_by_name <crd_file> <resource_name>"
    return 1
  fi

  # Check if the CRD file exists
  if [ ! -f "$crd_file" ]; then
    echo "CRD file not found: $crd_file"
    return 1
  fi

  # Use yq to filter the resource by name and print the resource
  yq eval-all "
    select(has(\"metadata\") and .metadata.name == \"$resource_name\")
  " "$crd_file"
}

# Function to install CRD
install_crd() {
  local crd_url="$1"
  local resource_name="$2"

  #echo -e "Applying CRD from: ${GREEN}$crd_url${NC}"
  
  # Download the CRD file
  local crd_file=$(mktemp)
  curl -s -o "$crd_file" "$crd_url"

  if [ -z "$resource_name" ]; then
    # If no resource name is provided, apply the entire CRD manifest
    kubectl apply -f "$crd_file"
  else
    # Extract and apply the specific resource from the CRD manifest
    local extracted_resource=$(extract_resource_by_name "$crd_file" "$resource_name")

    if [ -n "$extracted_resource" ]; then
      echo "$extracted_resource" | kubectl apply -f -
    else
      echo "Resource with name '$resource_name' not found in the CRD file."
      return 1
    fi
  fi

  # Remove the temporary file
  rm -f "$crd_file"
}

fetch_and_parse_crd() {
  local url=$1
  ### DEBUG
  #echo "Processing $url"
  # Fetch the CRD file content
  CRD_CONTENT=$(curl -sSL "$url")
  # Parse the CRD names using yq
  resources=($(echo "$CRD_CONTENT" | yq eval '.metadata.name // "---"' - | grep -v '^---$'))
  ### DEBUG
  #echo ${resources[@]}
  # Check if each CRD exists in the cluster
  for resource in "${resources[@]}"; do
    if kubectl get crd "$resource" > /dev/null 2>&1; then
      echo -e "CRD '${GREEN}$resource${NC}' exists in the cluster."
    else
      echo -e "CRD '${RED}$resource${NC}' is missing in the cluster "
      # Prompt the user to confirm if it is the correct context
      read -p "Do you want to install $resource? (y/n): " user_input
    
    case $user_input in
        [Yy]*)
            install_crd "$url" "$resource" && echo -e "CRD '${GREEN}$resource${NC}' installed successfully"
            ;;
        [Nn]*)
            echo -e "${RED}Installation is canceled${NC}."
            exit 1
            ;;
        *)
            echo -e "Invalid input. Please enter ${GREEN}'y'${NC} for yes or ${RED}'n'${NC} for no."
            ;;
    esac

    fi
  done
}

main() {
  kubectl_check
  check_k8s_context
  echo "Checking installed CRDs..."
  for url in "${CRD_URLS[@]}"; do
    fetch_and_parse_crd "$url"
  done
  create_namespace "jfrogml"
  echo -e "${GREEN}Installation script finished successfully.${NC}"
}

main

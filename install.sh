#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MIN_REQUIRED_ISTIO_VERSION="1.18"
MAX_REQUIRED_ISTIO_VERSION="1.24.3"

compare_versions() {
    if [[ "$1" == "$2" ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    
    return 0
}

# Function to convert a string to uppercase
to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

welcome() {
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
  
  istio_ascii_art='
    _____  _____ _______ _____ ____  
   |_   _|/ ____|__   __|_   _/ __ \ 
     | | | (___    | |    | || |  | |
     | |  \___ \   | |    | || |  | |
    _| |_ ____) |  | |   _| || |__| |
   |_____|_____/   |_|  |_____\____/ 
  '
  echo -e "${GREEN}$ascii_art${NC}"
  echo -e "${GREEN}Welcome to the JFrogML Installer!${NC}"
  echo "This script will perform the following actions:"
  echo "1. Check if the required tools (kubectl, helm, yq) are installed."
  echo "2. Verify the Kubernetes context and ensure you are using the correct cluster."
  echo "3. Check for already installed Custom Resource Definitions (CRDs) in your Kubernetes cluster."
  echo "4. Compare the versions of your installed CRDs with the expected versions."
  echo "5. Validate the Istio version installed in your cluster and ensure it is within the required range."
  echo "6. Install required CRDs for JFrogML only if they are not already installed."
  echo "7. Create the Kubernetes namespace 'jfrogml' if it doesn't already exist."
  echo -e "${NC}\n"

  # Ask the user if they want to proceed
  read -p "Do you want to proceed? (y/n): " choice
  case "$choice" in 
    yes|y|Y|YES) echo -e "${GREEN}Proceeding with the installation...${NC}";;
    no|n|N|NO) echo -e "${YELLOW}Installation aborted by user.${NC}"; exit 0;;
    * ) echo -e "${RED}Invalid choice. Please run the script again and choose either 'y' or 'n'.${NC}"; exit 1;;
  esac
}

# cloud provider
# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --cloud-provider)
        CLOUD_PROVIDER="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        echo -e "${RED}Unknown option provided: $key${NC}"
        exit 1
        ;;
    esac
done

if [ -z "$CLOUD_PROVIDER" ]; then
    echo -e "${RED}Error: --cloud-provider argument is required (aws/gcp).${NC}"
    exit 1
elif [[ "$CLOUD_PROVIDER" != "aws" && "$CLOUD_PROVIDER" != "gcp" ]]; then
    echo -e "${RED}Error: Invalid cloud provider. Expected 'aws' or 'gcp'.${NC}"
    exit 1
fi

# Convert to uppercase to ensure consistency in the rest of the script
CLOUD_PROVIDER=$(to_uppercase "$CLOUD_PROVIDER")

# URLs of CRD YAMLs
CRD_URLS=(
  #"https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-podmonitors.yaml"
  #"https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-servicemonitors.yaml"
  #"https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-prometheusrules.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/kafka.yaml"
  "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/elasticsearch.yaml"
  #"https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/istio.yaml"
)



kubectl_check() {
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed or not in PATH.${NC}"
    echo "Please install kubectl by following the instructions here: https://kubernetes.io/docs/tasks/tools/#kubectl"
    exit 1
  fi
}

helm_check() {
  if ! command -v helm &> /dev/null; then
    echo -e "${RED}ERROR: helm is not installed or not in PATH.${NC}"
    echo "Please install helm by following the instructions here: https://helm.sh/docs/intro/install/"
    exit 1
  fi
}

yq_check() {
  if ! command -v yq &> /dev/null; then
    echo -e "${RED}ERROR: yq is not installed or not in PATH.${NC}"
    echo "Please install yq by following the instructions here: https://github.com/mikefarah/yq#install"
    exit 1
  fi
}

# Function to check if AWS Load Balancer Controller is installed
is_aws_lb_controller_installed() {

  if [ "$CLOUD_PROVIDER" != "AWS" ]; then
    echo -e "${GREEN}No need to check AWS Load Balancer Controller since the cloud provider is not AWS.${NC}"
    return 0
  fi

  # Define the CRDs to check for the AWS Load Balancer Controller
  required_crds=(
    "targetgroupbindings.elbv2.k8s.aws"
  )

  # Iterate through each required CRD and check if it exists
  for crd in "${required_crds[@]}"; do
    if ! kubectl get crd "$crd" &> /dev/null; then
      echo -e "${RED}AWS Load Balancer Controller is NOT installed."${NC}
      echo -e "Please install using https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/"
      exit 1
    fi
  done
}

check_required_tools (){
  kubectl_check
  helm_check
  yq_check
}

check_istio_version() {
  # Retrieving all images from all namespaces
  images=$(kubectl get pods --all-namespaces -o jsonpath="{..image}" |\
           tr -s '[[:space:]]' '\n' |\
           sort | uniq)
  
  # Filtering Istio images
  istio_images=$(echo "${images}" | grep -i istio)
  if [ -z "$istio_images" ]; then
    echo "No Istio images found in the cluster. We can't detect istio version this way"
    return
  fi
  # DEBUG
  #echo "Istio images with versions found in the cluster:"
  #echo "==============================================="
  #echo "${istio_images}"
  #echo
  
  # Extract image tags
  tags=$(echo "$istio_images" | awk -F: '{print $NF}' | sort | uniq)

  if [ "$(echo "$tags" | wc -l)" -eq 1 ]; then
    version=$(echo "$tags" | head -n 1)
    echo -e "Probably you are running Istio version: ${GREEN}${version}${NC}"
    compare_versions $version $MIN_REQUIRED_ISTIO_VERSION
    is_min_version_ok=$?
    
    compare_versions $version $MAX_REQUIRED_ISTIO_VERSION
    is_max_version_ok=$?
    
    if [[ $is_min_version_ok -ne 2 && $is_max_version_ok -ne 1 ]]; then
        echo "Your version $version is within the required range."
    else
        echo -e ${GREEN}"Your version $version is not within the required range."${NC}
        ISTIO_IS_OK=1
    fi
      else
        echo -e ${YELLOW}"Multiple Istio versions detected:"${NC}
        echo -e "Try to reinstall istio and use 1 version from : $MIN_REQUIRED_ISTIO_VERSION to $MAX_REQUIRED_ISTIO_VERSION"
        exit 1
        echo "${tags}"
      fi
}

check_k8s_context() {
    # Get the current Kubernetes context
    current_context=$(kubectl config current-context)
    if [ -z "$current_context" ]; then
        echo "No current Kubernetes context found."
        return 1
    fi
    # Display the current context
    echo -e "Current Kubernetes context: '${YELLOW}$current_context${NC}'"
    # Prompt the user to confirm if it is the correct context
    read -p "Is this the correct context? (y/n): " user_input
    case $user_input in
        [Yy]*)
            echo -e "Context: ${GREEN}$current_context${NC} confirmed"
            ;;
        [Nn]*)
            echo -e "Context not confirmed. Please update the context using '${YELLOW}kubectl config use-context <context-name>'${NC}."
            exit 1
            ;;
        *)
            echo -e "Invalid input. Please enter ${GREEN}'y'${NC} for yes or ${RED}'n'${NC} for no."
            exit 1
            ;;
    esac
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
  CRD_CONTENT=$(curl -sSL "$url")
  resources=($(echo "$CRD_CONTENT" | yq eval '.metadata.name // "---"' - | grep -v '^---$'))

  for resource in "${resources[@]}"; do
    if kubectl get crd "$resource" > /dev/null 2>&1; then
      #echo -e "CRD '${GREEN}$resource${NC}' exists in the cluster."

      # Fetch the installed CRD spec
      installed_crd=$(kubectl get crd "$resource" -o json | jq -S )
      installed_spec=$(echo "$installed_crd" | yq e -o=json ".spec | del(.conversion)" - | jq -S)
      
      # Fetch the spec from the provided URL
      manifest_spec=$(echo "$CRD_CONTENT" | yq e -o=json "select(.metadata.name == \"$resource\").spec | del(.conversion)" - | jq -S)

      # Compare the specs using diff
      if diff <(echo "$installed_spec") <(echo "$manifest_spec") > /dev/null; then
        echo -e "CRD '${GREEN}$resource${NC}' is up-to-date."
      else
        echo -e "CRD '${YELLOW}$resource${NC}' required update"
        # DEBUG show diff
        #echo -e "DEBUG diff:"
        #diff <(echo "$installed_spec") <(echo "$manifest_spec") | sed 's/^/    /'
        DIFFERENT_CRDS+=("$resource#$url")
      fi
    else
      echo -e "CRD '${RED}$resource${NC}' is missing in the cluster."
      MISSING_CRDS+=("$resource#$url")
    fi
  done
}

check_istio() {

echo -e "${GREEN}$istio_ascii_art${NC}"
echo -e "Welcome in Istio installation!"

echo -e "\n"
read -p "Do you want to install Istio? (yes/no): " istio_choice
case "$istio_choice" in
  yes|YES|y)
    echo -e "${GREEN}Proceeding with Istio installation...${NC}"
    echo "Installing Istio..."
    install_istio_crds
    ;;
  no|NO|n)
    check_istio_version
    echo -e "${GREEN}It looks like Istio is already installed on your system.${NC}"
    echo -e "Choose ${GREEN}'Istio is already installed'${NC} in the UI."
    ;;
  * )
    echo -e "${RED}Invalid choice. Please run the script again and type yes or no.${NC}"
    exit 1
    ;;
esac
}

install_istio_crds() {
  # Clear and re-declare arrays
  # need to rewrite in the future
  unset MISSING_CRDS
  unset DIFFERENT_CRDS
  declare -a MISSING_CRDS
  declare -a DIFFERENT_CRDS

  check_istio_version
  echo "Checking Istio CRDs..."
  ISTIO_URL="https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/istio.yaml"
  local istio_missing_crds=()
  # Fetch and parse Istio CRDs
  fetch_and_parse_crd "$ISTIO_URL"
  if [ ${#MISSING_CRDS[@]} -gt 0 ]; then
    echo -e "\nThe following CRDs are missing and need to be installed:"
    for item in "${MISSING_CRDS[@]}"; do
      IFS="#" read -r resource url <<< "$item"
      echo -e "- ${YELLOW}${resource}${NC}"
    done
  fi

  if [ ${#DIFFERENT_CRDS[@]} -gt 0 ]; then
    echo -e "\nThe following CRDs are different and need to be updated:"
    for item in "${DIFFERENT_CRDS[@]}"; do
      IFS="#" read -r resource url <<< "$item"
      echo -e "- ${YELLOW}${resource}${NC}"
    done
  fi

  if [ ${#MISSING_CRDS[@]} -gt 0 ] || [ ${#DIFFERENT_CRDS[@]} -gt 0 ]; then
    read -p "Do you want to install or update these CRDs? (y/n): " user_input
    case $user_input in
        [Yy]*)
            for item in "${MISSING_CRDS[@]}"; do
              IFS="#" read -r resource url <<< "$item"
              install_crd "$ISTIO_URL" "$resource" && echo -e "Istio CRD '${GREEN}$resource${NC}' installed successfully"
            done
            for item in "${DIFFERENT_CRDS[@]}"; do
              IFS="#" read -r resource url <<< "$item"
              install_crd "$ISTIO_URL" "$resource" && echo -e "Different Istio CRD '${GREEN}$resource${NC}' updated successfully"
            done
            ;;
        [Nn]*)
            echo -e "${RED}Installation is canceled.${NC}"
            exit 1
            ;;
        *)
            echo -e "Invalid input. Please enter ${GREEN}'y'${NC} for yes or ${RED}'n'${NC} for no."
            exit 1
            ;;
    esac
  else
    echo -e "${GREEN}No missing CRDs or updates required.${NC}"
  fi
}

check_others_crds() {
  echo "Checking installed CRDs..."
  declare -a MISSING_CRDS
  declare -a DIFFERENT_CRDS
  for url in "${CRD_URLS[@]}"; do
    fetch_and_parse_crd "$url"
  done
  if [ ${#MISSING_CRDS[@]} -gt 0 ]; then
    echo -e "\nThe following CRDs are missing and need to be installed:"
    for item in "${MISSING_CRDS[@]}"; do
      IFS="#" read -r resource url <<< "$item"
      echo -e "- ${YELLOW}${resource}${NC}"
    done
  fi

  if [ ${#DIFFERENT_CRDS[@]} -gt 0 ]; then
    echo -e "\nThe following CRDs are different and need to be updated:"
    for item in "${DIFFERENT_CRDS[@]}"; do
      IFS="#" read -r resource url <<< "$item"
      echo -e "- ${YELLOW}${resource}${NC}"
    done
  fi

  if [ ${#MISSING_CRDS[@]} -gt 0 ] || [ ${#DIFFERENT_CRDS[@]} -gt 0 ]; then
    read -p "Do you want to install or update these CRDs? (y/n): " user_input
    case $user_input in
        [Yy]*)
            for item in "${MISSING_CRDS[@]}"; do
              IFS="#" read -r resource url <<< "$item"
              install_crd "$url" "$resource" && echo -e "Missing CRD '${GREEN}$resource${NC}' installed successfully"
            done
            for item in "${DIFFERENT_CRDS[@]}"; do
              IFS="#" read -r resource url <<< "$item"
              install_crd "$url" "$resource" && echo -e "Different CRD '${GREEN}$resource${NC}' updated successfully"
            done
            ;;
        [Nn]*)
            echo -e "${RED}Installation is canceled.${NC}"
            exit 1
            ;;
        *)
            echo -e "Invalid input. Please enter ${GREEN}'y'${NC} for yes or ${RED}'n'${NC} for no."
            exit 1
            ;;
    esac
  else
    echo -e "${GREEN}No missing CRDs or updates required.${NC}"
  fi
}

check_jfrogml_namespace() {
  local namespace="jfrogml"
  if kubectl get namespace "$namespace" &> /dev/null; then
    echo -e "${YELLOW}Note: Namespace '$namespace' already exists.${NC}"
  else
    echo "Creating namespace '$namespace'"
    kubectl create namespace "$namespace"
    kubectl label namespace $namespace istio-injection=enabled --overwrite
    kubectl label namespace $namespace jfrog.com/monitoring=active --overwrite
    echo -e "${GREEN}Namespace '$namespace' created successfully.${NC}"
  fi
  echo -e "${GREEN}Installation script finished successfully.${NC}"
}

check_prometheus_crds() {
  # URLs of Prometheus CRDs
  local prometheus_crd_urls=(
    "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-podmonitors.yaml"
    "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-servicemonitors.yaml"
    "https://raw.githubusercontent.com/qwak-ai/jfrogml-helm-chart-crds/main/crds/crd-prometheusrules.yaml"
  )

  local found_prometheus_crds=()

  # Check if Prometheus CRDs exist in the cluster
  for crd_url in "${prometheus_crd_urls[@]}"; do
    local crd_content=$(curl -sSL "$crd_url")

    # Get CRD resource names from the content
    local crd_names=($(echo "$crd_content" | yq eval '.metadata.name // "---"' - | grep -v '^---$'))

    for crd in "${crd_names[@]}"; do
      if kubectl get crd "$crd" &> /dev/null; then
        found_prometheus_crds+=("$crd")
      fi
    done
  done

  if [ ${#found_prometheus_crds[@]} -gt 0 ]; then
    echo -e "${GREEN}Prometheus CRDs are already installed in your system. Skipping the installation.${NC}"
  else
    echo -e "${YELLOW}No existing Prometheus CRDs found in your system.${NC}"
    read -p "Do you want to install our Prometheus CRDs (y/n): " choice
    case "$choice" in
      yes|y|Y|YES)
        echo -e "${GREEN}Proceeding with the installation of Prometheus CRDs...${NC}"
        # Install Prometheus CRDs
        for crd_url in "${prometheus_crd_urls[@]}"; do
          kubectl apply -f "$crd_url" && echo -e "CRD from ${GREEN}$crd_url${NC} installed successfully"
        done
        ;;
      no|n|N|NO)
        echo -e "${YELLOW}Installation of Prometheus CRDs aborted by user.${NC}"
        exit 1
        ;;
      *)
        echo -e "${RED}Invalid choice. Please run the script again and choose either 'y' or 'n'.${NC}"
        exit 1
        ;;
    esac
  fi
}

main() {
  check_required_tools
  echo -e "\n"
  welcome
  echo -e "\n"
  check_k8s_context
  echo -e "\n"
  is_aws_lb_controller_installed
  echo -e "\n"
  check_others_crds
  echo -e "\n"
  check_istio
  echo -e "\n"
  check_prometheus_crds
  echo -e "\n"
  check_jfrogml_namespace
  echo -e "\n"
}

main

#!/bin/bash

download_and_install() {
  local repo="$1"
  local download_file_name="$2"
  local binary_name="$3"
  local api_url="https://api.github.com/repos/$repo/releases/latest"
  
  echo "Fetching latest release information for $repo..."
  local release_info
  release_info=$(curl -s "$api_url")

  if [[ -z "$release_info" ]]; then
    echo "Error: Unable to fetch release information."
    exit 1
  fi

  local download_url
  download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name | test(\"$download_file_name\")) | .browser_download_url" | head -n 1)

  if [[ -z "$download_url" ]]; then
    echo "Error: No suitable binary found in the latest release."
    exit 1
  fi

  echo "Downloading $download_file_name from $download_url..."
  curl -L -o "/tmp/$download_file_name" "$download_url"

  if [[ $download_file_name == *.tar.gz ]]; then
    cd /tmp
    tar -xzvf $download_file_name > /dev/null
    cd -
  fi

  echo "Making $binary_name executable..."
  chmod +x "/tmp/$binary_name"

  echo "Installing $binary_name to /usr/local/bin..."
  sudo mv "/tmp/$binary_name" "/usr/local/bin/$binary_name"

  echo "$binary_name has been successfully installed to /usr/local/bin."
}

# Ensure required commands are available
check_dependencies() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is required but not installed. Please install it and try again."
      exit 1
    fi
  done

  if ! command -v semgrep &>/dev/null; then
      echo "Error: semgrep is required but not installed. Please install it and try again."
      echo "python3 -m pip install semgrep"
      exit 1
  fi

  if ! command -v syft &>/dev/null; then
      echo -e "\nInstalling syft.."
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
  fi

  if ! command -v grype &>/dev/null; then
      echo -e "\nInstalling grype.."
      curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
  fi

  if ! command -v vet &>/dev/null; then
      echo -e "\nInstalling vet.."
      download_and_install safedep/vet vet_Linux_x86_64.tar.gz vet
  fi
}

check_dependencies

# Function to display usage
usage() {
  echo "Usage: time bash $0 /path/to/repo [--skip-licensechecks] [--skip-sbom-sca]"
  echo "  --skip-licensechecks   Skip license checks"
  echo "  --skip-sbom-sca        Skip SBOM SCA checks"
  exit 1
}

# Initialize variables
skip_licensechecks=false
skip_sbom_sca=false
repo_path=$1

if [ "$#" -lt 1 ]; then
    echo -e "\nNot enough arguments...\n"
    usage
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-licensechecks)
      skip_licensechecks=true
      shift # Remove the argument from processing
      ;;
    --skip-sbom-sca)
      skip_sbom_sca=true
      shift # Remove the argument from processing
      ;;
    *)
    #   echo "Unknown argument: $1"
    #   usage
      shift
      ;;
  esac
done

echo "Enter sudo password, so that the execution wont be blocked"
sudo ls > /dev/null 2>&1
devsecops_folder_path=$(realpath .)

source configs/env

cd $repo_path
local_branch_name=$(git branch --show-current)
remote_tacking_branch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
latest_commit_id=$(git rev-parse --short HEAD)
cd -
# echo ${repo_name}_${latest_commit_id}
repo_name=$(basename ${repo_path})
repo_name=$(date +%d-%b-%Y)_${repo_name}_${latest_commit_id}
echo $repo_name

mkdir -p reports/$repo_name/{sbom,tool_outputs}

generate_report() {

    if ! $skip_sbom_sca; then
        # Supply Chain Analysis
        echo -e "\n ########### Running Supply Chain Analysis ########### \n"
        echo -e "\n ########### Running Syft ########### \n"
        time syft scan dir:$repo_path -c configs/syft.yaml -o cyclonedx-json=reports/$repo_name/sbom/${repo_name}_sbom_cyclonedx.json
        echo -e "syft: time taken is above.\n"
        # syft scan dir:$repo_path -q -o json > reports/$repo_name/sbom/${repo_name}_sbom.json
        echo -e "\n ########### Running Grype ########### \n"
        time grype sbom:reports/$repo_name/sbom/${repo_name}_sbom_cyclonedx.json -o json=reports/$repo_name/tool_outputs/${repo_name}_grype.json
        echo -e "grype: time taken is above.\n"
        python3 create-csv-from-vuln-json.py reports/$repo_name/tool_outputs/${repo_name}_grype.json reports/$repo_name/${repo_name}_supply_chain.csv
    fi

    if ! $skip_licensechecks; then
        if [ -f $repo_path/requirements.txt ]; then
            licensecheck_output=$(pwd)/reports/$repo_name/tool_outputs/${repo_name}_python_licensecheck.csv
            license_finder_output_path_relative=reports/$repo_name/tool_outputs/${repo_name}_python_license_finder.csv

            cd $repo_path/

            # requirements_pattern="requirements.*\.txt$"
            requirements_files=""
            pip_packages_to_install=""
            for file in ./requirements*.txt; do
                # Check if the file name matches the regex pattern
                if [[ -f "$file" ]]; then
                    # echo "Processing file: $file"
                    cat $file | grep -e '^-r ' > /dev/null 2>&1
                    if [[ $? -ne 0 ]]; then
                        requirements_files+="$(basename $file);"
                        while IFS= read -r line; do
                            # Skip lines that start with "ib-" or "ar-"
                            if [[ "$line" == ib-* || "$line" == ib_* || "$line" == django-swagger-utils*  || "$line" == s3_uploader* || "$line" == \#* ]]; then
                                # echo "Ignoring package $line"
                                continue
                            fi
                            # Append the line to the combined_requirements string with a newline
                            pip_packages_to_install+="$line"$'\n'
                        done < "$file"
                    else
                        echo "Ignoring file: $file"
                    fi
                fi
            done
            requirements_files="${requirements_files%;}"
            echo "requirements_files: $requirements_files"

            echo -e "\n ########### Running licensecheck ########### \n"

            time licensecheck -u "requirements:$requirements_files" -f csv -o $licensecheck_output
            echo -e "licensecheck: time taken is above.\n"

            echo -e "\n ########### Running licensefinder ########### \n"
            license_finder_columns="name version licenses approved package_manager summary install_path"
            requirements_files_install=${requirements_files//";"/" -r "}
            # echo $requirements_files_install
            echo "#### pip_packages_to_install:"
            echo $pip_packages_to_install
            # Pipe the combined requirements to pip for installation
            # Only if there is any content in combined_requirements
            if [[ -n "$pip_packages_to_install" ]]; then
                mv -f requirements.txt requirements_original_backup_${latest_commit_id}.txt
                echo "$pip_packages_to_install" > requirements.txt
                # echo "$pip_packages_to_install" > combined_requirements_${latest_commit_id}.txt
                if [ -d .venv ]; then
                    mv -T .venv .venv_${latest_commit_id}
                fi
                time docker run --rm -v $PWD:/scan \
                    -v $devsecops_folder_path/reports/:/reports \
                    -v $devsecops_folder_path/configs/:/configs \
                    -v ~/.aws:/root/.aws -v ~/.profile:/profile \
                    -v $devsecops_folder_path/.cache/license_finder/pip:/root/.cache/pip:rw \
                    licensefinder/license_finder \
                    /bin/bash -lc "cd /scan && apt update > /dev/null 2>&1 && apt install -y libmysqlclient-dev awscli python3.10-venv > /dev/null 2>&1 && chown -R root:root ~/.cache/pip && source /profile && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt > /dev/null && license_finder report --decisions-file=/configs/LicenseFinder/dependency_decisions.yml --format=csv --columns=$license_finder_columns | grep -v "LicenseFinder::*" | tee /$license_finder_output_path_relative > /dev/null"
                sudo rm -rf .venv
                
                mv -f requirements_original_backup_${latest_commit_id}.txt requirements.txt

                if [ -d .venv_${latest_commit_id} ]; then
                    mv -T .venv_${latest_commit_id} .venv
                fi
                echo -e "licensefinder: time taken is above.\n"
            else
                echo "No matching requirements files or all lines were skipped."
            fi

            cd -
            
            if [[ -f $license_finder_output_path_relative ]]; then
                echo -e "${license_finder_columns// /,}\n$(cat $license_finder_output_path_relative)" | sudo tee $license_finder_output_path_relative > /dev/null
            fi
        fi

        if [[ $? -ne 0 ]]; then
            cd $devsecops_folder_path
            exit 1
        fi

        if [ -f $repo_path/package.json ]; then
            license_finder_output_path_relative=reports/$repo_name/tool_outputs/${repo_name}_npm_license_finder.csv

            cd $repo_path/

            echo -e "\n ########### Running licensefinder ########### \n"

            license_finder_columns="name version licenses approved package_manager summary install_path"
            time docker run --rm -v $PWD:/scan -v $devsecops_folder_path/reports/:/reports -v $devsecops_folder_path/configs/:/configs -v ~/.aws:/root/.aws -v ~/.profile:/profile licensefinder/license_finder /bin/bash -lc "cd /scan && apt update > /dev/null && apt install -y libmysqlclient-dev awscli > /dev/null && source /profile && npm install || echo '' > /dev/null && license_finder report --decisions-file=/configs/LicenseFinder/dependency_decisions.yml --format=csv --columns=$license_finder_columns| grep -v "LicenseFinder::*" | tee /$license_finder_output_path_relative > /dev/null"
            echo -e "licensefinder: time taken is above.\n"

            cd -
            echo -e "${license_finder_columns// /,}\n$(cat $license_finder_output_path_relative)" | sudo tee $license_finder_output_path_relative > /dev/null
        fi

        if [[ $? -ne 0 ]]; then
            cd $devsecops_folder_path
            exit 2
        fi
    fi

    # Vet
    echo -e "\n ########### Running vet ########### \n"
    # time vet scan -D $repo_path --report-csv reports/$repo_name/tool_outputs/${repo_name}_vet.csv --filter 'vulns.critical.exists(p, true) || vulns.high.exists(p, true) || vulns.medium.exists(p, true) || vulns.low.exists(p, true)' > /dev/null
    echo -e "vet: time taken is above.\n"

    # Semgrep
    echo -e "\n ########### Running semgrep ########### \n"
    # **/*db.sqlite3*, **/*.ipynb, /src/sales_crm_backend/settings/**, /src/automation_workflows/constants/enum.py, **/*graphqlTypes.ts, **/*graphqlTypes.tsx
    time semgrep scan -q \
        --exclude=node_modules \
        --exclude=venv \
        --exclude=tests \
        --exclude=dist \
        --exclude=*enums* \
        --exclude=*.env* \
        --exclude=fixtures \
        --exclude=*InternationalMobileNumber/constants.ts \
        --exclude=*IntlPhoneNumberUtils/CountriesList.ts \
        --json --json-output=reports/$repo_name/tool_outputs/${repo_name}_semgrep.json $repo_path #> /dev/null
    echo -e "semgrep: time taken is above.\n"

    # Synk
    # REQUIRES ACCOUNT IN SNYK SERVERS

    # SonarQube
    echo -e "\n ########### Running SonarQube ########### \n"
    python3 create_project_in_sonarqube.py $repo_name
    time docker run \
        --rm \
        -v "${repo_path}:/src" \
        -v $(pwd)/configs/sonar-project.properties:/opt/sonar-scanner/conf/sonar-scanner.properties \
        --network="host" \
        -e SONAR_SCANNER_OPTS="-Dsonar.projectKey=$repo_name" \
        sonarsource/sonar-scanner-cli > /dev/null
    echo -e "SonarQube: time taken is above.\n"
    
    echo -ne "\nWaiting for sonarqube report to be ready ."
    while : ; do
        SONARQUBE_STATUS=$(curl -sS -u $DEFECT_DOJO_USER:$DEFECT_DOJO_PASSWD $SONAR_QUBE_URL/api/ce/activity?component=$repo_name | jq -r ".tasks[] | select(.componentKey | test(\"$repo_name\")) | .status")
        if [ "$SONARQUBE_STATUS" = "SUCCESS" ]; then
            break
        fi
        echo -n "."
        sleep 0.5
    done

    echo ""

    curl -sS -u $DEFECT_DOJO_USER:$DEFECT_DOJO_PASSWD $SONAR_QUBE_URL/api/issues/search?projects=$repo_name -o reports/$repo_name/tool_outputs/${repo_name}_sonarqube.json

    # Bandit is an open-source SAST tool designed specifically for Python applications.
    echo -e "\n ########### Running Bandit ########### \n"
    # echo $repo_path
    time docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bandit.yaml:/bandit.yaml ghcr.io/pycqa/bandit/bandit -c /bandit.yaml -q -r /src -f json -o /reports/$repo_name/tool_outputs/${repo_name}_bandit.json
    echo -e "Bandit: time taken is above.\n"

    # Horusec is an open-source tool that performs a static code analysis to identify security flaws during development.
    # Current languages for analysis are C#, Java, Kotlin, Python, Ruby, Golang, Terraform, Javascript, Typescript, Kubernetes, PHP, C, HTML, JSON, Dart, Elixir, Shell, and Nginx.
    echo -e "\n ########### Running Horusec ########### \n"
    time docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $repo_path:/src -v $(pwd)/reports:/reports horuszup/horusec-cli:v2.9.0-beta.3 horusec start -p /src -P $repo_path -i="**/node_modules/**, **/venv/**, **/tests/**, **/*db.sqlite3*, **/dist/**, **/*.ipynb, /src/sales_crm_backend/settings/**, *enums*, /src/automation_workflows/constants/enum.py, **/*.env*, **/*graphqlTypes.ts, **/*graphqlTypes.tsx, **/fixtures/**" -o json -O /reports/$repo_name/tool_outputs/${repo_name}_horusec.json
    echo -e "Horusec: time taken is above.\n"

    # Bearer is a static application security testing (SAST) tool that scans your source code and analyzes your data flows to discover, filter, and prioritize security and privacy risks.
    # Currently supports JavaScript, TypeScript, Ruby, and Java stacks.
    echo -e "\n ########### Running Bearer ########### \n"
    bearer_output="reports/$repo_name/tool_outputs/${repo_name}_bearer.json" 
    touch $bearer_output
    chmod 666 $bearer_output
    time docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bearer-config.yml:/bearer-config.yml -v $(pwd)/configs/bearer-rules:/rules bearer/bearer:latest-amd64 scan /src --config-file /bearer-config.yml -f json --output /$bearer_output
    echo -e "Bearer: time taken is above.\n"
}

generate_report

#repo_name=$(basename $1)
mkdir -p reports/$repo_name/consolidated_reports/{raw,final}

echo -e "\n ########### Generating Consolidated Reports ########### \n"
python3 upload_reports_to_defectdojo.py $repo_name reports/$repo_name/tool_outputs/ reports/$repo_name/consolidated_reports/raw

python3 generate_final_report.py reports/$repo_name/consolidated_reports/raw/ reports/$repo_name/consolidated_reports/final/
mv reports/$repo_name/consolidated_reports/final/findings.csv reports/$repo_name/consolidated_reports/final/${repo_name}-findings.csv

echo
echo "Final report is available at reports/$repo_name/consolidated_reports/final/${repo_name}-findings.csv"
#!/bin/bash

if ! syft --version 2>&1 >/dev/null
then
    echo "syft could not be found, installing"
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi

if ! grype --version 2>&1 >/dev/null
then
    echo "grype could not be found, installing"
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi

echo "Enter sudo password, so that the execution wont be blocked"
sudo ls > /dev/null 2>&1
devsecops_folder_path=$(realpath .)

generate_report() {
    local repo_path=$1
    repo_name=$(basename ${repo_path})
    # echo $repo_name
    
    cd $repo_path
    local_branch_name=$(git branch --show-current)
    remote_tacking_branch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
    latest_commit_id=$(git rev-parse --short HEAD)
    cd -
    # echo ${repo_name}_${latest_commit_id}
    repo_name=$(date +%d-%b-%Y)_${repo_name}_${latest_commit_id}
    echo $repo_name

    mkdir -p reports/$repo_name/{sbom,tool_outputs}

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

    # false; then #
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

    # echo "-- Supply Chain Security report is at reports/$repo_name/${repo_name}_supply_chain.csv"

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

# for repo_path in $1* ; do
#     if [ -d "$repo_path" ]; then
#         # $d is a directory
#         # echo "$repo_path"
        
#         generate_report $repo_path
#     fi
# done

generate_report $1

#repo_name=$(basename $1)
mkdir -p reports/$repo_name/consolidated_reports/{raw,final}

echo -e "\n ########### Generating Consolidated Reports ########### \n"
python3 upload_reports_to_defectdojo.py $repo_name reports/$repo_name/tool_outputs/ reports/$repo_name/consolidated_reports/raw

python3 generate_final_report.py reports/$repo_name/consolidated_reports/raw/ reports/$repo_name/consolidated_reports/final/
mv reports/$repo_name/consolidated_reports/final/findings.csv reports/$repo_name/consolidated_reports/final/${repo_name}-findings.csv

echo
echo "Final report is available at reports/$repo_name/consolidated_reports/final/${repo_name}-findings.csv"
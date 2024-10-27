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

devsecops_folder_path=$(pwd)

generate_report() {
    local repo_path=$1
    repo_name=$(basename ${repo_path})
    echo $repo_name
    
    cd $repo_path
    local_branch_name=$(git branch --show-current)
    remote_tacking_branch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
    latest_commit_id=$(git rev-parse --short HEAD)
    cd -
    
    mkdir -p reports/$repo_name/sbom reports/$repo_name/tool_outputs

    # Supply Chain Analysis
    echo -e "\n ########### Running Supply Chain Analysis ########### \n"
    syft scan dir:$repo_path -q -c configs/syft.yaml -o cyclonedx-json=reports/$repo_name/sbom/${repo_name}_${latest_commit_id}_sbom_cyclonedx.json
    # syft scan dir:$repo_path -q -o json > reports/$repo_name/sbom/${repo_name}_${latest_commit_id}_sbom.json
    grype sbom:reports/$repo_name/sbom/${repo_name}_${latest_commit_id}_sbom_cyclonedx.json -q -o json=reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_grype.json
    python3 create-csv-from-vuln-json.py reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_grype.json reports/$repo_name/${repo_name}_${latest_commit_id}_supply_chain.csv

    if [ -f $repo_path/requirements.txt ]; then
        licensecheck_output=$(pwd)/reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_python_licensecheck.csv
        license_finder_output_path_relative=reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_python_license_finder.csv

        cd $repo_path/

        time licensecheck -u 'requirements:requirements.txt;requirements_optional.txt' -f csv -o $licensecheck_output

        license_finder_columns="name version licenses approved package_manager summary install_path"
        time docker run --rm -v $PWD:/scan -v $devsecops_folder_path/reports/:/reports -v $devsecops_folder_path/configs/:/configs licensefinder/license_finder /bin/bash -lc "cd /scan && pip install -r requirements.txt && license_finder report --decisions-file=/configs/LicenseFinder/dependency_decisions.yml --format=csv --columns=$license_finder_columns | tail -n +2 | tee /$license_finder_output_path_relative"

        cd -
        echo -e "${license_finder_columns// /,}\n$(cat $license_finder_output_path_relative)" | sudo tee $license_finder_output_path_relative
    fi

    if [[ $? -ne 0 ]]; then
        cd $devsecops_folder_path
        exit 1
    fi

    if [ -f $repo_path/package.json ]; then
        license_finder_output_path_relative=reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_npm_license_finder.csv
        
        cd $repo_path/

        license_finder_columns="name version licenses approved package_manager summary install_path"
        time docker run --rm -v $PWD:/scan -v $devsecops_folder_path/reports/:/reports -v $devsecops_folder_path/configs/:/configs licensefinder/license_finder /bin/bash -lc "cd /scan && npm install && license_finder report --decisions-file=/configs/LicenseFinder/dependency_decisions.yml --format=csv --columns=$license_finder_columns | tail -n +2 | tee /$license_finder_output_path_relative"

        cd -
        echo -e "${license_finder_columns// /,}\n$(cat $license_finder_output_path_relative)" | sudo tee $license_finder_output_path_relative
    fi

    if [[ $? -ne 0 ]]; then
        cd $devsecops_folder_path
        exit 2
    fi

    echo "-- Supply Chain Security report is at reports/$repo_name/${repo_name}_${latest_commit_id}_supply_chain.csv"

    # Bandit is an open-source SAST tool designed specifically for Python applications.
    echo -e "\n ########### Running Bandit ########### \n"
    echo $repo_path
    time docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bandit.yaml:/bandit.yaml ghcr.io/pycqa/bandit/bandit -c /bandit.yaml -q -r /src -f json -o /reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_bandit.json

    # Horusec is an open-source tool that performs a static code analysis to identify security flaws during development.
    # Current languages for analysis are C#, Java, Kotlin, Python, Ruby, Golang, Terraform, Javascript, Typescript, Kubernetes, PHP, C, HTML, JSON, Dart, Elixir, Shell, and Nginx.
    echo -e "\n ########### Running Horusec ########### \n"
    time docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v $repo_path:/src -v $(pwd)/reports:/reports horuszup/horusec-cli:v2.9.0-beta.3 horusec start -p /src -P $repo_path -i="**/node_modules/**, **/venv/**, **/tests/**, **db.sqlite3**" -o json -O /reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_horusec.json

    # Bearer is a static application security testing (SAST) tool that scans your source code and analyzes your data flows to discover, filter, and prioritize security and privacy risks.
    # Currently supports JavaScript, TypeScript, Ruby, and Java stacks.
    echo -e "\n ########### Running Bearer ########### \n"
    bearer_output="reports/$repo_name/tool_outputs/${repo_name}_${latest_commit_id}_bearer.json" 
    touch $bearer_output
    chmod 666 $bearer_output
    time docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bearer-config.yml:/bearer-config.yml -v $(pwd)/configs/bearer-rules:/rules bearer/bearer:latest-amd64 scan /src --config-file /bearer-config.yml -f json --output /$bearer_output
}

# for repo_path in $1* ; do
#     if [ -d "$repo_path" ]; then
#         # $d is a directory
#         # echo "$repo_path"
        
#         generate_report $repo_path
#     fi
# done

generate_report $1

# repo_name=$(basename $1)
# for ouput_path in reports/$repo_name/tool_outputs/*.json ; do
#     if [ -f "$ouput_path" ]; then
#         echo "Uploading to defect dojo output_path: $ouput_path"
#         python3 upload_reports_to_defectdojo.py $ouput_path
#     fi
# done
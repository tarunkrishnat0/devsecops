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

generate_report() {
    local repo_path=$1
    repo_name=$(basename ${repo_path})
    echo $repo_name
    mkdir -p reports/$repo_name/sbom reports/$repo_name/tool_outputs

    # Supply Chain Analysis
    echo -e "\n ########### Running Supply Chain Analysis ########### \n"
    syft scan dir:$repo_path -q -o cyclonedx-json > reports/$repo_name/sbom/${repo_name}_sbom_cyclonedx.json
    syft scan dir:$repo_path -q -o json > reports/$repo_name/sbom/${repo_name}_sbom.json
    grype sbom:reports/$repo_name/sbom/${repo_name}_sbom.json -q -o json > reports/$repo_name/tool_outputs/${repo_name}_grype.json
    python create-csv-from-vuln-json.py reports/$repo_name/tool_outputs/${repo_name}_grype.json reports/$repo_name/${repo_name}_supply_chain.csv
    echo "-- Supply Chain Security report is at reports/$repo_name/${repo_name}_supply_chain.csv"

    # Bandit is an open-source SAST tool designed specifically for Python applications.
    echo -e "\n ########### Running Bandit ########### \n"
    time docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bandit.yaml:/bandit.yaml ghcr.io/pycqa/bandit/bandit -c /bandit.yaml -q -r /src -f json -o /reports/$repo_name/tool_outputs/${repo_name}_bandit.json

    # Horusec is an open-source tool that performs a static code analysis to identify security flaws during development.
    # Current languages for analysis are C#, Java, Kotlin, Python, Ruby, Golang, Terraform, Javascript, Typescript, Kubernetes, PHP, C, HTML, JSON, Dart, Elixir, Shell, and Nginx.
    echo -e "\n ########### Running Horusec ########### \n"
    time docker run -v /var/run/docker.sock:/var/run/docker.sock -v $repo_path:/src -v $(pwd)/reports:/reports horuszup/horusec-cli:v2.9.0-beta.3 horusec start -p /src -P $(pwd) -i="**/node_modules/**, **/venv/**" -o json -O /reports/$repo_name/tool_outputs/${repo_name}_horusec.json

    # Bearer is a static application security testing (SAST) tool that scans your source code and analyzes your data flows to discover, filter, and prioritize security and privacy risks.
    # Currently supports JavaScript, TypeScript, Ruby, and Java stacks.
    echo -e "\n ########### Running Bearer ########### \n"
    bearer_output="reports/$repo_name/tool_outputs/${repo_name}_bearer.json" 
    touch $bearer_output
    chmod 666 $bearer_output
    echo "docker run --rm -v $repo_path:/src -v $(pwd)/reports:/reports -v $(pwd)/configs/bearer-config.yml:/bearer-config.yml -v $(pwd)/configs/bearer-rules:/rules bearer/bearer:latest-amd64 scan /src --config-file /bearer-config.yml -f json --output /$bearer_output"
}

# for repo_path in $1* ; do
#     if [ -d "$repo_path" ]; then
#         # $d is a directory
#         # echo "$repo_path"
        
#         generate_report $repo_path
#     fi
# done

generate_report $1

for ouput_path in reports/$repo_name/tool_outputs/* ; do
    if [ -f "$ouput_path" ]; then
        echo "Uploading to defect dojo output_path: $ouput_path"
        python upload_reports_to_defectdojo.py $ouput_path
    fi
done
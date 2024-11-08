import requests
import sys
import os
import json
from dotenv import load_dotenv
from pathlib import Path
from utils_defectdojo_selenium import download_findings_from_defectdojo, create_engagment_in_defectdojo

dotenv_path = Path('configs/env')
load_dotenv(dotenv_path=dotenv_path)

DEFECT_DOGO_URL = os.getenv('DEFECT_DOGO_URL')

scan_type = ''
scan_output_suffix = {
    '_gitleaks.json': 'Gitleaks Scan',
    '_njsscan.sarif': 'SARIF',
    '_semgrep.json': 'Semgrep JSON Report',
    '_bandit.json': 'Bandit Scan',
    '_bearer.json': 'Bearer CLI',
    '_horusec.json': 'Horusec Scan',
    '_grype.json': 'Anchore Grype',
}

url_auth_token = DEFECT_DOGO_URL +'/api/v2/api-token-auth/'
body_auth_token = { "username": os.getenv('DEFECT_DOJO_USER'), "password": os.getenv('DEFECT_DOJO_PASSWD') }

def get_auth_headers():
    response = requests.post(url_auth_token, data=body_auth_token)

    token=""
    if response.ok:
        token = json.loads(response.text)['token']
    else:
        print('Unable to get access token, exiting, ...')
        exit(1)

    # print(token)

    headers = {
        'Authorization': 'Token ' + token
    }
    return headers

url = DEFECT_DOGO_URL + '/api/v2/import-scan/'

def get_engagement_id(project_name, headers):
    all_engagement_details = requests.get(DEFECT_DOGO_URL + '/api/v2/engagements/?name=' + project_name, headers=headers)
    if all_engagement_details.ok:
        all_engagement_details_json = json.loads(all_engagement_details.text)
        count = all_engagement_details_json['count']
        if count == 1:
            engagment_id = all_engagement_details_json['results'][0]['id']
            print('engagment_id: %d' % engagment_id)
            return engagment_id
        else:
            print('engagement count: %d' % count)
            if count == 0:
                create_engagment_in_defectdojo(project_name)
                return get_engagement_id(project_name, headers)
            else:
                print('More than one engagements match with project name: ' + project_name)
                exit(2)
    else:
        print('engagement API failed')
        print(all_engagement_details.text)
        exit(3)

def upload_json_to_defectdojo(file_path, headers):
    # Iterate through files in the specified directory

    file_name = os.path.basename(file_path)

    scan_type=""
    project_name=""
    for suffix_format in scan_output_suffix:
        if file_name.endswith(suffix_format):
            scan_type = scan_output_suffix[suffix_format]
            project_name = os.path.basename(file_name).replace(suffix_format, "")

    if scan_type=="":
        print('Unable to get scan_type, exiting, ...')
        exit(1)

    # import re
    # project_name = re.sub("_[a-zA-Z0-9]+$", "", project_name)
    print('scan_type: ' + scan_type)
    print('project_name: ' + project_name)

    engagment_id = get_engagement_id(project_name, headers)

    data = {
        'active': True,
        'verified': True,
        'scan_type': scan_type,
        'minimum_severity': 'Low',
        'engagement': engagment_id,
        'deduplication_on_engagement': True,
        'version': '',
        'build_id': '',
        'branch_tag': '',
        'commit_hash': '',
    }

    files = {
        'file': open(file_path, 'rb')
    }

    response = requests.post(url, headers=headers, data=data, files=files)

    if response.status_code == 201:
        print('Scan results imported successfully')
    else:
        print(f'Failed to import scan results: {response.content}')
    print()

    return engagment_id

if __name__ == "__main__":
    project_name = sys.argv[1]
    outputs_folder_path = sys.argv[2]
    findings_download_path= sys.argv[3]
    headers = get_auth_headers()
    engagement_id=""
    for filename in os.listdir(outputs_folder_path):
        # Check if the file is a JSON file
        if filename.endswith('.json'):
            file_path = os.path.join(outputs_folder_path, filename)
            engagement_id = upload_json_to_defectdojo(file_path, headers)
    
    if engagement_id != "":
        download_findings_from_defectdojo(engagement_id, findings_download_path)

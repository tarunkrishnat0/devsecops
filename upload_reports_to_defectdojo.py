import requests
import sys
import os
import json
from dotenv import load_dotenv
from pathlib import Path
import re

dotenv_path = Path('configs/env')
load_dotenv(dotenv_path=dotenv_path)

DEFECT_DOGO_URL = os.getenv('DEFECT_DOGO_URL')

file_name = sys.argv[1]
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

for suffix_format in scan_output_suffix:
    if file_name.endswith(suffix_format):
        scan_type = scan_output_suffix[suffix_format]
        project_name = os.path.basename(file_name).replace(suffix_format, "")

project_name = re.sub("_[a-zA-Z0-9]+$", "", project_name)
print('scan_type: ' + scan_type)
print('project_name: ' + project_name)

url_auth_token = DEFECT_DOGO_URL +'/api/v2/api-token-auth/'
body_auth_token = { "username": os.getenv('DEFECT_DOJO_USER'), "password": os.getenv('DEFECT_DOJO_PASSWD') }

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

all_engagement_details = requests.get(DEFECT_DOGO_URL + '/api/v2/engagements/?name=' + project_name, headers=headers)
if all_engagement_details.ok:
    all_engagement_details_json = json.loads(all_engagement_details.text)
    if all_engagement_details_json['count'] == 1:
        engagment_id = all_engagement_details_json['results'][0]['id']
    else:
        print('engagement count: %d' % all_engagement_details_json['count'])
        print('More than one engagements match with project name: ' + project_name)
        exit(2)
else:
    print('engagement API failed')
    print(all_engagement_details.text)
    exit(3)

print('engagment_id: %d' % engagment_id)

# if file_name.endswith('_gitleaks.json'):
#     scan_type = 'Gitleaks Scan'
# elif file_name.endswith('_njsscan.sarif'):
#     scan_type = 'SARIF'
# elif file_name.endswith('_semgrep.json'):
#     scan_type = 'Semgrep JSON Report'
# elif file_name.endswith('_bandit.json'):
#     scan_type = 'Bandit Scan'
# elif file_name.endswith('_bearer.json'):
#     scan_type = 'Bearer CLI'
# elif file_name.endswith('_horusec.json'):
#     scan_type = 'Horusec Scan'


url = DEFECT_DOGO_URL + '/api/v2/import-scan/'

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
    'file': open(file_name, 'rb')
}

response = requests.post(url, headers=headers, data=data, files=files)

if response.status_code == 201:
    print('Scan results imported successfully')
else:
    print(f'Failed to import scan results: {response.content}')
print()
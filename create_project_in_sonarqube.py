import os
import requests
import json
import sys
from dotenv import load_dotenv
from pathlib import Path

dotenv_path = Path('configs/env')
load_dotenv(dotenv_path=dotenv_path)

SONAR_QUBE_URL = os.getenv('SONAR_QUBE_URL')
project_name=sys.argv[1]#"test-floww"

projects_details = requests.get(SONAR_QUBE_URL + '/api/projects/search?projects=' + project_name, auth=(os.getenv('DEFECT_DOJO_USER'), os.getenv('DEFECT_DOJO_PASSWD')))
if projects_details.ok:
    projects_details_json = json.loads(projects_details.text)
    count = projects_details_json['paging']['total']
    if count == 1:
        data={'project': project_name}
        # project_delete = requests.post(SONAR_QUBE_URL + '/api/projects/delete', data="project="+project_name, auth=(os.getenv('DEFECT_DOJO_USER'), os.getenv('DEFECT_DOJO_PASSWD')))
        project_delete = requests.post(SONAR_QUBE_URL + '/api/projects/delete', data=data, auth=(os.getenv('DEFECT_DOJO_USER'), os.getenv('DEFECT_DOJO_PASSWD')))
        print(project_delete.text)
    else:
        print('projects count: %d' % count)
    
data={'project': project_name, 'name': project_name}
project_create = requests.post(SONAR_QUBE_URL + '/api/projects/create', data=data, auth=(os.getenv('DEFECT_DOJO_USER'), os.getenv('DEFECT_DOJO_PASSWD')))
print(project_create.text)

# project_issues = requests.get(SONAR_QUBE_URL + '/api/issues/search?projects=' + project_name, auth=(os.getenv('DEFECT_DOJO_USER'), os.getenv('DEFECT_DOJO_PASSWD')))
# print(project_issues.text)

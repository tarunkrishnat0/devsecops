# Intro
- Tested on Ubuntu 24.04
- Create a virtual env and install the pip requirements.

Clone the dev branch with all submodules.
```sh
git clone --recursive -b dev git@github.com:tarunkrishnat0/devsecops.git
```

# Setting up third party tools

## Defect Dojo
### Setup
```sh
# Apply a patch that will fix bearer scan results import error
cd configs/django-DefectDojo/
git apply  ../django-DefectDojo.patch

# Building Docker images
./dc-build.sh

# Run the application (for other profiles besides postgres-redis see  
# https://github.com/DefectDojo/django-DefectDojo/blob/dev/readme-docs/DOCKER.md)
./dc-up-d.sh postgres-redis

# Obtain admin credentials. The initializer can take up to 3 minutes to run.
# Use docker compose logs -f initializer to track its progress.
docker compose logs initializer | grep "Admin password:" | tee defect_dojo_creds.txt
```

### Creating user for importing scan results
Create a user in defect dojo as per below details:
```
username: scan-importer
password: Scan-Importer09
role: API-Importer
```
Note: These creds should be same as `./config/env`

### Creating Product and engagments
- Create a product in defect dojo with name as per your need.
- Create engagements under the product with name as the repo folder name (that is given for scanning). Scan results of a repo are uploaded to the engagement that has same name as the folder name.

# Execution
```sh
time bash run-devsecops-analysis.sh /full/path/to/project/
```

# Scan Results
Scan results are stored under `./reports/` with same folder name as the project folder.
# Intro
- Tested on Ubuntu 24.04
- Create a virtual env and install the pip requirements.

Clone the dev branch with all submodules.
```sh
git clone --recursive -b dev https://github.com/tarunkrishnat0/devsecops.git
```

# Pre-requisites
- [ ] [Install Docker using apt](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
- [ ] [Add user to docker group](https://docs.docker.com/engine/install/linux-postinstall/)
- [ ] [Install Google Chrome from PPA](https://www.tecmint.com/install-chrome-ubuntu/)
- [ ] Install below packages
```sh
sudo apt update
sudo apt install -y vim git tmux htop iputils-ping rsyslog fontconfig unzip curl nano python3-dev python3-venv python3-virtualenv python3-pip libffi-dev gcc libssl-dev git net-tools sqlite-utils
```
- [ ] Create virtual env and install packages
```sh
# Change /path/to/devsecops to the locally cloned devsecops repo
cd /path/to/devsecops

virtualenv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

# Setting up third party tools

## Install Syft and Grype
```sh
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
```

## Licensecheck
Licensecheck has a [bug](https://github.com/FHPythonUtils/LicenseCheck/pull/94) that ignores requirements files of pip.
Edit the file `.venv/lib/python3.10/site-packages/licensecheck/get_deps.py` as shown in this [PR](https://github.com/FHPythonUtils/LicenseCheck/pull/94/files)

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
docker compose logs initializer | grep "Admin " | tee ../../defect_dojo_creds.txt
```

### Creating user for importing scan results
Login to defect dojo(http://localhost:8080/) with the credentials from `defect_dojo_creds.txt` and create a user as per below details:
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
source .venv/bin/activate
# Change the /full/path/to/project/ to the repo that you want to scan
time bash run-devsecops-analysis.sh /full/path/to/project/
```

# Scan Results
Scan results are stored under `./reports/` with same folder name as the project folder.
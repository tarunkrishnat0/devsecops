```sh
# Apply patches to submodules
git clone --recursive -b dev git@github.com:tarunkrishnat0/devsecops.git
cd configs/django-DefectDojo/
git apply  ../django-DefectDojo.patch

################ Defect Dojo #######################
# Building Docker images
./dc-build.sh

# Run the application (for other profiles besides postgres-redis see  
# https://github.com/DefectDojo/django-DefectDojo/blob/dev/readme-docs/DOCKER.md)
./dc-up-d.sh postgres-redis

# Obtain admin credentials. The initializer can take up to 3 minutes to run.
# Use docker compose logs -f initializer to track its progress.
docker compose logs initializer | grep "Admin password:"

```
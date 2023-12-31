PROJECT_ID=`gcloud config configurations list | grep True | awk '{print $4}'`
BUCKET_NAME=${PROJECT_ID}-bucket

export GOOGLE_CLOUD_KEYFILE_JSON="./account.json"
export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_CLOUD_KEYFILE_JSON

# CREATE SERVICE IAM Account
gcloud iam service-accounts create iam-serviceaccount --display-name "Account for CronJob"

# CREATE CREDENTIAL FILES FOR CronJob
gcloud iam service-accounts keys create account.json --iam-account iam-serviceaccount@${PROJECT_ID}.iam.gserviceaccount.com

#ATTACH OWNER POLICY
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:iam-serviceaccount@${PROJECT_ID}.iam.gserviceaccount.com --role roles/owner
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:iam-serviceaccount@${PROJECT_ID}.iam.gserviceaccount.com --role roles/kuberun.eventsControlPlaneServiceAgent

#CREATE CLOUD STORAGE IAM FOR CONTAINER
gcloud iam service-accounts create gcs-serviceaccount --display-name "Account for Container"
gcloud iam service-accounts keys create gcs.json --iam-account gcs-serviceaccount@${PROJECT_ID}.iam.gserviceaccount.com
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member serviceAccount:gcs-serviceaccount@${PROJECT_ID}.iam.gserviceaccount.com --role roles/storage.admin

#ENABLE EACH API ON GCP
gcloud services enable dns.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable deploymentmanager.googleapis.com

# Create Storage for Terraform state management.
gsutil mb gs://${BUCKET_NAME}

# REPLACE NEW PROJECT-ID INTO with dummy one from the terraform template file.
sed -i -e 's/PROJECT_ID/'${PROJECT_ID}'/g' main.tf
sed -i -e 's/PROJECT_ID/'${PROJECT_ID}'/g' variables.tf

# BUILD INFRASTRUCTURE
terraform init
terraform apply -auto-approve
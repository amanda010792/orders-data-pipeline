# orders-data-pipeline
Orders Data Pipeline Workshop Walkthrough 

## Pre-Requisites

- Sign up for Confluent Cloud at the [Confluent Cloud Start Page](https://www.confluent.io/get-started/). You will receive $400 in promotional credits to test with. 

## Running the workshop 

You can set up the workshop using the UI or using the terraform provider (this allows for automated setup and destruction). Instructions for both methods can be found below:      

### Run the workshop using the Confluent Terraform Provider 

#### Pre-Requisites

###### Download the CLI and login to Confluent Cloud

Download the CLI following the directions [here](https://docs.confluent.io/confluent-cli/current/install.html).     
Login to Confluent Cloud: 
```
confluent login --save
```
###### Ensure Terraform 0.14+ is installed

Install Terraform version manager [tfutils/tfenv](https://github.com/tfutils/tfenv)

Alternatively, install the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli?_ga=2.42178277.1311939475.1662583790-739072507.1660226902#install-terraform)

To ensure you're using the acceptable version of Terraform you may run the following command:
```
terraform version
```
Your output should resemble: 
```
Terraform v0.14.0 # any version >= v0.14.0 is OK
```

###### Create a Cloud API Key 

1. Open the Confluent Cloud Console
2. In the top right menu, select "Cloud API Keys"
3. Choose "Add Key" and select "Granular Access"
4. For Service Account, select "Create a New One" and name is <YOUR_NAME>-terraform-workshop-SA
5. Download your key
6. In the top right menu, select "Accounts & Access", select "Access" tab
7. Click on the organization and select "Add Role Assignment" 
8. Select the account you created (service account) and select "Organization Admin". Click Save

###### Download this repo

```
git clone https://github.com/amanda010792/orders-data-pipeline
cd orders-data-pipeline
```

#### Set up the Workshop Resources

In the setup of the workshop you will be provisioning the following resources: 
- An environment 
- A Kafka cluster 
- A ksqlDB cluster 
- A topic called 'orders' 
- A Datagen Source connector to simulate mock data in the topic you created 
- Necessary service accounts, API keys and ACLs. 

```
cd configurations
```

Set terraform variables 
```
export TF_VAR_confluent_cloud_api_key="<CONFLUENT_CLOUD_API_KEY>"
export TF_VAR_confluent_cloud_api_secret="<CONFLUENT_CLOUD_API_SECRET>" 
```

Install the confluent providers from the configuration.
```
terraform init
```

Apply terraform changes to deploy environment and required resources
```
terraform apply
```



### Run the Workshop using the Confluent Cloud Dashboard   

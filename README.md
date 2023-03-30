# orders-data-pipeline
Orders Data Pipeline Workshop Walkthrough 

## Workshop Overview

This workshop is meant to serve as an introduction to creating data pipelines in Confluent Cloud. 

![Workshop Overview](images/workshop_overview.png?raw=true)

Imagine you are a retail store that has both a brick and mortar presence and an ecommerce site. The different platforms where customers can place orders (online, in store and on the mobile application) generate order events into Kafka to be distributed to multiple downstream systems (such as reporting dashboards with the analytics team, the store associated with the order and the team responsible for supply chain management). With legacy pipelines, the integration between the order systems and the downstream systems was likely point-to-point and batch-oriented. With Kafka, all of our systems can be kept up to date with the latest information from our source systems.    

![Workshop Flow](images/workshop_flow.png?raw=true)

In the workshop today, we are going to be setting up a source connector that generates mock order data to a kafka topic called 'orders'. We will also be filtering the data and narrowing it down to a single zip code and storing that data in a topic (to be consumed by our various downstream systems). This data pipeline we've created can be consumed in a number of ways and at the end of the workshop setup we will explore some of those avenues (in an extra credit section).      

## Pre-Requisites

- Sign up for Confluent Cloud at the [Confluent Cloud Start Page](https://www.confluent.io/get-started/). You will receive $400 in promotional credits to test with. 

## Setting up the Workshop Resources 

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

#### Run the Workshop

#### Tear Down the Workshop

### Run the Workshop using the Confluent Cloud Dashboard   

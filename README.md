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

Once your resources are provisioned, it's time to create our streaming data pipeline. Navigate to the [https://confluent.cloud/](Confluent Cloud Dashboard) and log in. 

So far we have set up the following pieces of our data flow:     
![Current Data Flow](images/post_provisioning_setup.png?raw=true)

#### Manipulate Data using ksqlDB

##### Create a ksqlDB Stream using your topic
A stream is a partitioned, immutable, append-only collection that represents a series of historical facts. For example, the rows of a stream could model a sequence of financial transactions, like "Alice sent $100 to Bob", followed by "Charlie sent $50 to Bob". Once a row is inserted into a stream, it can never change. New rows can be appended at the end of the stream, but existing rows can never be updated or deleted.

Each row is stored in a particular partition. Every row, implicitly or explicitly, has a key that represents its identity. All rows with the same key reside in the same partition.

In the Confluent Cloud Dashboard in your Cluster UI, select ksqlDB and select your application
Select the "Editor" Tab in the application.      

We need to create a stream based on the orders topic. Enter the following query into the query editor and click "Run Query":     
```
CREATE STREAM orders WITH (
    KAFKA_TOPIC = 'orders',
    VALUE_FORMAT = 'AVRO'
);
```

##### Querying your ksqlDB data
Now that our orders data is imported into ksqlDB we can start mining and transforming it to derive insights from it. We can start by running a simple select statement to see the data existing in the topic: 
```
SELECT * 
FROM orders
EMIT CHANGES;
```

There are three kinds of queries in ksqlDB: persistent, push, and pull. Each gives you different ways to work with rows of events.

A push query is a form of query issued by a client that subscribes to a result as it changes in real-time. A good example of a push query is subscribing to a particular user's geographic location. The query requests the map coordinates, and because it's a push query, any change to the location is "pushed" over a long-lived connection to the client as soon as it occurs. This is useful for building programmatically controlled microservices, real-time apps, or any sort of asynchronous control flow.      

Push queries are expressed using a SQL-like language. They can be used to query either streams or tables for a particular key. Also, push queries aren't limited to key look-ups. They support a full set of SQL, including filters, selects, group bys, partition bys, and joins. Push queries will contain the command "EMIT CHANGES" to notify the ksqlDB query to remain continuously running.     

The query we ran above is a "Push Query" and is going to continue running until we terminate it by clicking "Stop".      

Our example today asks us to imagine we are fulfilling orders for a given store (or set of stores) in a specific zip code (imagine our . In the orders schema, zip code is a part of a nested field called address. In order to list the zip codes where we currently have orders coming in from, we can run a query to pull out just the zip code from our messages:     
```
SELECT address->zipcode 
FROM orders
EMIT CHANGES;
```

For our lab today, let's find a zip code to filter based on. To do this, we can run a slightly more complicated query: 
```
SELECT address->zipcode as zipcode, count(orderid)  
FROM orders
GROUP BY address->zipcode
HAVING count(orderid) >1
EMIT CHANGES;
```

The results of this query will show us zip codes that have more than one order. You can click on the blue arrow next to a record in your list and this will show you the zipcode and the current count of orders placed in that zip code: 

![Zipcodes Image A](images/zipcodesa.png?raw=true)
![Zipcodes Image B](images/zipcodesb.png?raw=true)

Choose the zip code in the record for the next query. Now that we have a feel for the type of data that is living in our topic, we can filter our records based on our chosen zip code. To do this, we will need to run the following query in our editor: 
```
SELECT * 
FROM orders
WHERE address->zipcode=<zipcode> 
EMIT CHANGES;
```

For example, since I chose zipcode 22703 I'd run the following query: 
```
SELECT 
  * 
FROM orders
WHERE address->zipcode=22703
EMIT CHANGES;
```

This query will continue to run until we terminate it. However, the query here is acting as a consumer and not writing the results to a topic. In order to write the results to a topic, we will have to create a stream using our select query. In the editor, run the following query (replacing zipcode with your chosen zipcode): 
```
CREATE STREAM orders_<zipcode> WITH (
  kafka_topic='orders_<zipcode>',
  value_format='AVRO'
) AS 
SELECT
  *
FROM orders
WHERE address->zipcode=<zipcode>
EMIT CHANGES;
```

For example, since I chose zipcode 22703 I'd run the following query: 
```
CREATE STREAM orders_22703 WITH (
  kafka_topic='orders_22703',
  value_format='AVRO'
) AS 
SELECT
  *
FROM orders
WHERE address->zipcode=22703
EMIT CHANGES;
```

Now, when you navigate to the "Topics" tab on the left-hand menu you'll see a topic with data for a specific zip code. 

#### Consume Data 

There are many ways to consume data from Confluent Cloud. You can use the CLI, client applications in a number of languages or use connectors to automatically extract data from your kafka topic and land it in a downstream data store.     

No matter how we choose to consume, we will need to generate a set of API keys to be used by our application: one for Schema Registry and one for our Kafka Cluster hosting the topic. 

##### Consume using the Confluent CLI 

Open a terminal and login to Confluent using the CLI: 
```
confluent login --save
```

List the environments in your organization: 
```
confluent environment list
```

Next to the "orders_workshop_env", copy the environment ID and run: 
```
confluent environment use <env_id>
```

List the available clusters in your environment by running: 
```
confluent kafka cluster list
```

Next to the "orders_workshop_cluster", copy the cluster ID and run: 
```
confluent kafka cluster use <cluster_id>
```

We need to create an api-key for the cli to use for the cluster. We will also need to tell the CLI to use the api-key. To do this, run: 
```
confluent api-key create --resource <cluster_id>
confluent api-key use <api-key> --resource <cluster_id>
```

We can now consume from the topic we created above using the CLI (with a signifier to tell the CLI to begin consumption from the beginning of the topic):
```
confluent kafka topic consume <filtered_topic_name> --from-beginning
```

The results returned do not come back in readable form. This is because our data is stored as AVRO data and our consumer has not connected to Schema Registry to recieve the schema associated with the topic. In order to fix this we first have to create a Schema Registry key.     
Navigate to your environment in the Confluent Cloud Dashboard and you'll see a section on the right hand side for Stream Governance: 
![Schema Registry UI](images/schema_registry_ui.png?raw=true)

Note the Stream Governance endpoint (you'll need this to consume using SR). Also, create a SR key by clicking "Add Key" under credentials. Download the key (you'll need this also to consume using SR).    

Now that we have what we need to connect the CLI consumer to SR, navigate back to your terminal and run the following command (replacing topic name with your filtered orders topic): 
```
confluent kafka topic consume <filtered_topic_name> --value-format avro --print-key --delimiter "-"  --from-beginning
```

The CLI will continue to run this consumer until you terminate it.      

##### Bonus: Consume using a client application or Kafka Connect

Let's imagine we had an application interested in consuming from the same topic. The Kafka Producer and Consumer APIs can be used to publish to and read from our Kafka topics. These can be embedded in our client application code to integrate our application layer and Kafka. There are a number of clients compatible with Confluent Cloud. Some resources to help you get started: 
- [https://docs.confluent.io/cloud/current/client-apps/config-client.html](Kafka Client Quickstart Documentation)
- [https://developer.confluent.io/get-started/](Confluent Developer Site Tutorial)
- [https://docs.confluent.io/cloud/current/cp-component/clients-cloud-config.html](Confluent Cloud Client Configuration Documentation)

What if you wanted to send data from either your raw orders topic or your filtered orders topic to a downstream system like a database, data warehouse or file system? We can use one of the prebuilt connectors for Confluent Cloud to send data in a no-code format. You can also choose to run Kafka Connect in a self-managed capacity. Some resources to help you get started: 
- [https://docs.confluent.io/cloud/current/connectors/index.html](Connect External Systems to Confluent Cloud - Documentation)
- [https://www.confluent.io/hub/](Confluent Hub of Connectors)
- [https://developer.confluent.io/learn-kafka/kafka-connect/intro/](Confluent Developer Site Overview and Tutorial)


#### Tear Down the Workshop

When using Terraform, tearing down the workshop is easy. Simply navigate to the configurations directory in your terminal and run the following command: 
```
terraform destroy
```

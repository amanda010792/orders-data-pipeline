# orders-data-pipeline Manual Setup
Orders Data Pipeline Workshop Walkthrough 

## Setting up the Workshop Resources

As a reminder, the lab flow for the workshop today is:      
![Workshop Flow](../images/workshop_flow.png?raw=true)

In order to set up our data pipeliine we will be do the following:  
- Create an Environment 
- Create a Kafka Cluster 
- Create a ksqlDB Cluster
- Create a Kafka topic called 'orders'
- Create a Datagen Source Connector to simulate mock data in the topic created
- Write ksqlDB Queries to transform our orders data in real time
- Set up a consumer to read from our transformed topics. 

#### Spin up Confluent Cloud Resources 

##### Create an Environment

Create an environment in Confluent Cloud for the workshop called "orders_workshop_env" following the steps outlined [here](https://docs.confluent.io/cloud/current/access-management/hierarchy/cloud-environments.html#add-an-environment). An environment contains Kafka clusters and deployed components such as Connect, ksqlDB, and Schema Registry. You can define multiple environments for a Organizations for Confluent Cloud, and there is no charge for creating or using additional environments. Different departments or teams can use separate environments to avoid interfering with each other.    

When the environment is created, select "Essentials -> Begin Configuration" and choose the cloud provider and region of your choice.   

##### Create a Cluster

Create a cluster in Confluent Cloud for the workshop called "orders_workshop_env" following the steps outlined [here](https://docs.confluent.io/cloud/current/clusters/create-cluster.html#create-clusters). You can create clusters using the Confluent Cloud Console, Confluent CLI, and REST API. For a description of cluster types and resource quotas for clusters, see [Confluent Cloud Features and Limits by Cluster Type and Service Quotas for Confluent Cloud](https://docs.confluent.io/cloud/current/quotas/index.html#service-quotas-for-ccloud). The cluster should have the following attributes: 
- Basic cluster in the cloud provider & region of your choice
- Single AZ setup      

##### Create a ksqlDB Cluster

Once the cluster is deployed, create a ksqlDB cluster (with global access & a size of 1 CSU) called "orders_workshop_ksql_cluster" following the steps outlined [here](https://docs.confluent.io/cloud/current/get-started/index.html#step-1-create-a-ksql-cloud-cluster-in-ccloud). ksqlDB is fully hosted on Confluent Cloud and provides a simple, scalable, resilient, and secure event streaming platform.   

##### Create a Kafka topic called 'orders' 

We are going to set up a topic called 'orders' as the backbone to bring our use case to life. 

We can create the orders topic by following the documentation [here](https://docs.confluent.io/cloud/current/client-apps/topics/manage.html#create-a-topic). An Apache Kafka® topic is a category or feed that stores messages. Producers send messages and write data to topics, and consumers read messages from topics. We will create each topic above with 1 partition to guarantee ordering across the entire topic.    

![Workshop Flow](../images/create_topic.png?raw=true)

##### Setup a Datagen Connector 

We need to populate our topic. We will do this by creating a Datagen connector to simulate order data being produced to our topic:      
- In the Confluent Cloud Dashboard in your cluster UI, select Connectors
- Click the "+ Add Connector" button
- Select the "Datagen Source" connector 
- Choose the "orders" topic & click continue
- For your Kafka Credentials, select "Global Access" and click "Generate API Key and Download". Click "Continue"
- For your output record value format select "AVRO"
- For your template, select "Orders"
- For sizing leave the default of 1 task selected & click "continue"
- Name your connector "orders_avro_datagen" and launch your connector. 

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

To tear down the workshop when set up manually follow the steps below: 

##### Delete ksqlDB Cluster 
- Navigate to your Cluster on the Confluent Cloud Dashboard 
- On the left-hand menu select "ksqlDB"
- You will see the option "Delete" for your ksqlDB cluster under actions. Click "Delete" & confirm the deletion

##### Delete Datagen Connector 
- Navigate to the "Connector" tab on the left-hand menu
- Click on your running Datagen connector 
- Navigate to the "Settings" tab for your connector
- In the footer you'll see an option to "Delete connector". Select this and confirm 

##### Delete Kafka Cluster
- On the left-hand menu navigate to Cluster Overview -> Cluster Settings 
- In the "General" tab of the Cluster Settings menu you'll see an option to "Delete Cluster" (might require you to scroll to see the option). Click this and Confirm the deletion. 



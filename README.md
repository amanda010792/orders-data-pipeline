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
- Download the CLI following the directions [here](https://docs.confluent.io/confluent-cli/current/install.html).     
- Login to Confluent Cloud: 
```
confluent login --save
```

## Setting up the Workshop Resources 

You can set up the workshop using the UI or using the terraform provider (this allows for automated setup and destruction). 

For directions on setting up manually, navigate to the [https://github.com/amanda010792/orders-data-pipeline/tree/main/manual-setup](manual-setup directory) of this repo. For directions on setting up in an automated fashion, navigate to the [https://github.com/amanda010792/orders-data-pipeline/tree/main/automated-setup](automated-serup directory) of this repo. 

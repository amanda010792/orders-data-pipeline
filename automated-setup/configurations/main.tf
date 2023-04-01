terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.38.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# spin up environment called "orders_workshop_env"
resource "confluent_environment" "orders_workshop_env" {
  display_name = "orders_workshop_env"
}

# spin up kafka cluster called "orders_workshop_cluster" in orders_workshop_env (created above)
resource "confluent_kafka_cluster" "orders_workshop_cluster" {
  display_name = "orders_workshop_cluster"
  availability = "SINGLE_ZONE"
  cloud        = "GCP"
  region       = "us-east4"
  basic {}

  environment {
    id = confluent_environment.orders_workshop_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "confluent_schema_registry_region" "sr_region" {
  cloud   = "GCP"
  region  = "us-central1"
  package = "ESSENTIALS"
}

resource "confluent_schema_registry_cluster" "essentials" {
  package = data.confluent_schema_registry_region.sr_region.package

  environment {
    id = confluent_environment.orders_workshop_env.id
  }

  region {
    id = data.confluent_schema_registry_region.sr_region.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# create a service account for ksqldb 
resource "confluent_service_account" "app-orders-service-account" {
  display_name = "app-orders-service-account"
  description  = "Service account to manage Orders Demo ksqlDB cluster"
}

# create a rolebinding for ksqldb service account (created above) to give it cluster admin access for the kafka cluster (created above)
resource "confluent_role_binding" "app-ksql-kafka-cluster-orders-role-binding" {
  principal   = "User:${confluent_service_account.app-orders-service-account.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.orders_workshop_cluster.rbac_crn
}

# create a rolebinding for ksqldb service account (created above) to give it access to the schema registry (created above)
resource "confluent_role_binding" "app-ksql-schema-registry-resource-owner" {
  principal   = "User:${confluent_service_account.app-orders-service-account.id}"
  role_name   = "ResourceOwner"
  crn_pattern = format("%s/%s", confluent_schema_registry_cluster.essentials.resource_name, "subject=*")

  lifecycle {
    prevent_destroy = false
  }
}

# create ksql cluster in env and cluster (created above) depending on the service account created above
resource "confluent_ksql_cluster" "orders_workshop_ksql_cluster" {
  display_name = "ksql_orders"
  csu          = 1
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  credential_identity {
    id = confluent_service_account.app-orders-service-account.id
  }
  environment {
    id = confluent_environment.orders_workshop_env.id
  }
  depends_on = [
    confluent_role_binding.app-ksql-kafka-cluster-orders-role-binding,
    confluent_role_binding.app-ksql-schema-registry-resource-owner,
    confluent_schema_registry_cluster.essentials
  ]
}

# create a service account called topic manager 
resource "confluent_service_account" "orders-topic-manager" {
  display_name = "orders-topic-manager"
  description  = "Service account to manage Kafka cluster topics"
}

# create a role binding for topic manager service account (created above) that has cloud cluster admin access to basic cluster (created above)
resource "confluent_role_binding" "topic-manager-kafka-cluster-orders" {
  principal   = "User:${confluent_service_account.orders-topic-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.orders_workshop_cluster.rbac_crn
}

# create an api key for the topic manager service account (created above) 
resource "confluent_api_key" "orders-topic-manager-kafka-api-key" {
  display_name = "orders-topic-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'orders-topic-manager' service account"
  owner {
    id          = confluent_service_account.orders-topic-manager.id
    api_version = confluent_service_account.orders-topic-manager.api_version
    kind        = confluent_service_account.orders-topic-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.orders_workshop_cluster.id
    api_version = confluent_kafka_cluster.orders_workshop_cluster.api_version
    kind        = confluent_kafka_cluster.orders_workshop_cluster.kind

    environment {
      id = confluent_environment.orders_workshop_env.id
    }
  }

  depends_on = [
    confluent_role_binding.topic-manager-kafka-cluster-orders
  ]
}

# create a topic called orders using the api key created above
resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  topic_name    = "orders"
  rest_endpoint = confluent_kafka_cluster.orders_workshop_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.orders-topic-manager-kafka-api-key.id
    secret = confluent_api_key.orders-topic-manager-kafka-api-key.secret
  }
}

# create a service account called "orders-connect-manager"
resource "confluent_service_account" "orders-connect-manager" {
  display_name = "orders-connect-manager"
  description  = "Service account to manage Kafka cluster"
}

# create a role binding to the orders-connect-manager service account (created above) to give it cluster admin access for basic cluster (created above)
resource "confluent_role_binding" "orders-connect-manager-kafka-cluster" {
  principal   = "User:${confluent_service_account.orders-connect-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.orders_workshop_cluster.rbac_crn
}

# create an api key for the orders-connect-manager service account (created above)
resource "confluent_api_key" "orders-connect-manager-kafka-api-key" {
  display_name = "orders-connect-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'orders-connect-manager' service account"
  owner {
    id          = confluent_service_account.orders-connect-manager.id
    api_version = confluent_service_account.orders-connect-manager.api_version
    kind        = confluent_service_account.orders-connect-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.orders_workshop_cluster.id
    api_version = confluent_kafka_cluster.orders_workshop_cluster.api_version
    kind        = confluent_kafka_cluster.orders_workshop_cluster.kind

    environment {
      id = confluent_environment.orders_workshop_env.id
    }
  }

  depends_on = [
    confluent_role_binding.orders-connect-manager-kafka-cluster
  ]
}

# create a service account called "orders-application-connector"
resource "confluent_service_account" "orders-application-connector" {
  display_name = "orders-application-connector"
  description  = "Service account for Datagen Connectors"
}

# create an api key tied to the orders-application-connector service account (created above)
resource "confluent_api_key" "orders-application-connector-kafka-api-key" {
  display_name = "orders-application-connector-kafka-api-key"
  description  = "Kafka API Key that is owned by 'orders-application-connector' service account"
  owner {
    id          = confluent_service_account.orders-application-connector.id
    api_version = confluent_service_account.orders-application-connector.api_version
    kind        = confluent_service_account.orders-application-connector.kind
  }
 managed_resource {
    id          = confluent_kafka_cluster.orders_workshop_cluster.id
    api_version = confluent_kafka_cluster.orders_workshop_cluster.api_version
    kind        = confluent_kafka_cluster.orders_workshop_cluster.kind

    environment {
      id = confluent_environment.orders_workshop_env.id
    }
  }
}

# created an ACL called "orders-application-connector-describe-on-cluster" that grants the orders-application-connector service account describe permission on the basic cluster (created above)
resource "confluent_kafka_acl" "orders-application-connector-describe-on-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.orders-application-connector.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.orders_workshop_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.orders-connect-manager-kafka-api-key.id
    secret = confluent_api_key.orders-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "orders-application-connector-write-on-orders" that grants the orders-application-connector service account write permission on the orders topic (created above)
resource "confluent_kafka_acl" "orders-application-connector-write-on-transactions" {
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.orders-application-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.orders_workshop_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.orders-connect-manager-kafka-api-key.id
    secret = confluent_api_key.orders-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "orders-application-connector-create-on-data-preview-topics" that grants the orders-application-connector service account create permission on the preview topics 
resource "confluent_kafka_acl" "orders-application-connector-create-on-data-preview-topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "data-preview"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.orders-application-connector.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.orders_workshop_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.orders-connect-manager-kafka-api-key.id
    secret = confluent_api_key.orders-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "orders-application-connector-write-on-data-preview-topics" that grants the orders-application-connector service account write permission on the preview topics 
resource "confluent_kafka_acl" "orders-application-connector-write-on-data-preview-topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "data-preview"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.orders-application-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.orders_workshop_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.orders-connect-manager-kafka-api-key.id
    secret = confluent_api_key.orders-connect-manager-kafka-api-key.secret
  }
}

# create a connector called "orders_source" that creates a datagen connector called "DatagenSourceConnector_orders" using the orders quickstart of datagen and writes to the orders topic (depends on acls above)
resource "confluent_connector" "orders_source" {
  environment {
    id = confluent_environment.orders_workshop_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.orders_workshop_cluster.id
  }

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "DatagenSourceConnector_orders"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.orders-application-connector.id
    "kafka.topic"              = confluent_kafka_topic.orders.topic_name
    "output.data.format"       = "AVRO"
    "quickstart"               = "ORDERS"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.orders-application-connector-describe-on-cluster,
    confluent_kafka_acl.orders-application-connector-write-on-transactions,
    confluent_kafka_acl.orders-application-connector-create-on-data-preview-topics,
    confluent_kafka_acl.orders-application-connector-write-on-data-preview-topics,
  ]
}


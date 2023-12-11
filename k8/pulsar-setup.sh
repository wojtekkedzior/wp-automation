#/bin/bash

function createTestTopics() {
  local cluster=$1
  local partitions=$2

  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic t/ns/mercury -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic t/ns/venus   -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic t/ns/earth   -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic t/ns/mars    -p ${partitions}"
}

function multiCluster() {
  echo "Installing multiple Pulsar clusters"
  # initialize the cluster metadata from the first Pulsar cluster which is plite1 in this case. This populates the configuration store and lists the plit2 Pulsar cluster as the geo-replication destination. 
  # Note that the --zookeeper parameter refers to the zookeeper for the plite1 cluster
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar initialize-cluster-metadata --cluster primary --zookeeper primary-zookeeper.default.svc.cluster.local:2181 --configuration-store my-zookeeper.default.svc.cluster.local:2185  --web-service-url http://primary-broker.default.svc.cluster.local:8080 --broker-service-url pulsar://primary-broker.default.svc.cluster.local:6650"

  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar initialize-cluster-metadata --cluster backup --zookeeper backup-zookeeper.default.svc.cluster.local:2181 --configuration-store my-zookeeper.default.svc.cluster.local:2185  --web-service-url http://backup-broker.default.svc.cluster.local:8080 --broker-service-url pulsar://backup-broker.default.svc.cluster.local:6650"

  echo "initialize-cluster-metadata is done."

  # the word 'create' is confusing here as the Pulsar clusters have already been created. These steps rather make each cluster aware of each other. Note that the cluster name used here must match
  # what is is the value.yaml for each Pulsar cluster eg clusterName: plite-1.
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://backup-broker.default.svc.cluster.local:6650 --url http://backup-broker.default.svc.cluster.local:8080 backup"
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://primary-broker.default.svc.cluster.local:6650 --url http://primary-broker.default.svc.cluster.local:8080 primary"
  echo "cluster are married"

  # check whether the clusters are showing up correctly
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"  
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"

  echo "setting up the primary cluster"
  # the tenant, namespace and topics all need to be created on both Pulsar clusters.  No idea what happens if you increase the number of partitions on the primary cluster, but don't apply that change on the replication cluster.  It's possible 
  # that Pulsar will create the new partitions and just normal topics, which will not be accessible when trying to consume from the partitioned topic. 
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin    tenants create t    --admin-roles my-admin-role --allowed-clusters primary,backup"
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create t/ns --bundles 4"
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-clusters t/ns --clusters primary,backup"
  echo "primary cluster is ready"

  # on backup: 
  echo "setting up the primary cluster" 
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants    create t    --admin-roles my-admin-role --allowed-clusters primary,backup"
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create t/ns --bundles 4"
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-clusters t/ns --clusters primary,backup"
  # kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces remove-auto-subscription-creation t/ns"
  echo "backup cluster is ready"

  createTestTopics "primary-toolset-0" 2
  kubectl exec -i primary-toolset-0 -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create t/ns/sun"

  # kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-subscription -s sub t/ns/sun"

  echo "topics in primary"
  kubectl exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics list t/ns"
  echo "topics in backup"
  kubectl exec -i backup-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics list t/ns"

  # TODO remove subscription auto-create
  
  echo "multi pulsar cluster installed and setup" 
}

function singleCluster {
  kubectl  exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants create t"
  kubectl  exec -i primary-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create t/ns"
  #  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-retention t/ns --size 2M --time 1m"

  createTestTopics "primary-toolset-0" 8

  echo "single pulsar cluster installed and setup" 
}
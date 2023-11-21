#/bin/bash

function createTestTopics() {
  local cluster=$1
  local partitions=$2

  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mercury -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/venus   -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/earth   -p ${partitions}"
  kubectl exec -i ${cluster} -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mars    -p ${partitions}"
}

function multiCluster() {
  echo "Installing multiple pulsar clusteres"
  # initialize the cluster metadata from the first Pulsar cluster which is plite1 in this case. This populates the configuration store and lists the plit2 Pulsar cluster as the geo-replication destination. 
  # Note that the --zookeeper parameter refers to the zookeeper for the plite1 cluster
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar initialize-cluster-metadata --cluster pulsar --zookeeper pulsar-zookeeper.default.svc.cluster.local:2181 --configuration-store my-zookeeper.default.svc.cluster.local:2185  --web-service-url http://pulsar-broker.default.svc.cluster.local:8080 --broker-service-url pulsar://pulsar-broker.default.svc.cluster.local:6650"
  
  #TODO: does an initialize-cluster-metadata need to be called for the second cluster too? 

  # todo might not be needed any more as the there is already a wait-for the proxies after the cluster has been installed
  # sleep 30
  echo "global cluster is done."

  # the word 'create' is confusing here as the Pulsar clusters have already been created. These steps rather make each cluster aware of each other.  From plite1 add plite-2 and from plite2 add plite-1. #note that the cluster name used here must match
  # what is is the value.yaml for each Pulsar cluster eg clusterName: plite-1.
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://plite2-broker.default.svc.cluster.local:6650 --url http://plite2-broker.default.svc.cluster.local:8080 plite2"
  # sleep 5
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://pulsar-broker.default.svc.cluster.local:6650 --url http://pulsar-broker.default.svc.cluster.local:8080 pulsar"
  echo "cluster are married"
  # sleep 3  
  # check whether the clusters are showing up correctly
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"  
  # sleep 3
  echo "in between cluster listing"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"

  echo "setting up cluster named "pulsar"" 
  # the tenant, namespace and topics all need to be created on both Pulsar clusters.  No idea what happens if you increase the number of partitions on the primary cluster, but don't apply that change on the replication cluster.  It's possible 
  # that Pulsar will create the new partitions and just normal topics, which will not be accessible when trying to consume from the partitioned topic. 
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants    create wojtekt --admin-roles my-admin-role --allowed-clusters pulsar,plite2"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns --bundles 4"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-clusters wojtekt/wojtekns --clusters pulsar,plite2"
  echo "cluster "pulsar" is ready"

  # on plite2: 
  echo "setting up cluster plite2" 
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants    create wojtekt --admin-roles my-admin-role --allowed-clusters pulsar,plite2"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns --bundles 4"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-clusters wojtekt/wojtekns --clusters pulsar,plite2"
  # kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces remove-auto-subscription-creation wojtekt/wojtekns"
  echo "cluster plite2 is ready"

  createTestTopics "pulsar-toolset-0" 2
  kubectl exec -i pulsar-toolset-0 -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create wojtekt/wojtekns/sun"


  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-subscription -s sun wojtekt/wojtekns/sun"


  echo "topics in primary"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics list wojtekt/wojtekns"
  echo "topics in backup"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics list wojtekt/wojtekns"

  # TODO remove subscription auto-create
}

function singleCluster {
  echo "installing a single pulsar cluster..."  
 
  # todo might not be needed any more as the there is already a wait-for the proxies after the cluster has been installed
  # sleep 40

  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants create wojtekt"
  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns"
  #  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-retention wojtekt/wojtekns --size 2M --time 1m"

  createTestTopics "pulsar-toolset-0" 8

  echo "single pulsar cluster installed" 
}




# kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics terminate wojtekt/wojtekns/sun "
# kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics delete  wojtekt/wojtekns/sun "

# kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics terminate wojtekt/wojtekns/sun"
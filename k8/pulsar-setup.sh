#/bin/bash

function multiCluster() {
  echo "Installing multiple pulsar clusteres"
  # initialize the cluster metadata from the first Pulsar cluster which is plite1 in this case. This populates the configuration store and lists the plit2 Pulsar cluster as the geo-replication destination. 
  # Note that the --zookeeper parameter refers to the zookeeper for the plite1 cluster
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar initialize-cluster-metadata --cluster plite12 --zookeeper pulsar-zookeeper.default.svc.cluster.local:2181 --configuration-store my-zookeeper.default.svc.cluster.local:2185  --web-service-url http://pulsar-broker.default.svc.cluster.local:8080 --broker-service-url pulsar://plite1-pulsar-broker.default.svc.cluster.local:6650"
  
  sleep 30
  echo "global cluster is done."

  # the word 'create' is confusing here as the Pulsar clusters have already been created. These steps rather make each cluster aware of each other.  From plite1 add plite-2 and from plite2 add plite-1. #note that the cluster name used here must match
  # what is is the value.yaml for each Pulsar cluster eg clusterName: plite-1.
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://plite2-pulsar-broker.default.svc.cluster.local:6650 --url http://plite2-pulsar-broker.default.svc.cluster.local:8080 plite2"
  sleep 5
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters create --broker-url pulsar://pulsar-broker.default.svc.cluster.local:6650 --url http://pulsar-broker.default.svc.cluster.local:8080 pulsar"
  echo "cluster are married"
  sleep 3  
  # check whether the clusters are showing up correctly
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"  
  sleep 3
  echo "in between cluster listing"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin clusters list"
  
  echo "setting up cluster on plite2" 

  # the tenant, namespace and topics all need to be created on both Pulsar clusters.  No idea what happens if you increase the number of partitions on the primary cluster, but don't apply that change on the replication cluster.  It's possible 
  # that Pulsar will create the new partitions and just normal topics, which will not be accessible when trying to consume from the partitioned topic. 
  # on plite1:
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants create wojtekt --admin-roles my-admin-role --allowed-clusters pulsar,plite2"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns --bundles 4"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-clusters wojtekt/wojtekns --clusters pulsar,plite2"
  # kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/wojtektopic1 -p 2"

  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mercury -p 2"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/venus -p 2"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/earth -p 2"
  kubectl exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mars -p 2"

  echo "cluster on plite2 is ready"
  # on plite2: 
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants    create wojtekt --admin-roles my-admin-role --allowed-clusters pulsar,plite2"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns --bundles 4"
  # kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics     create-partitioned-topic wojtekt/wojtekns/wojtektopic1 -p 2"

  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mercury -p 2"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/venus -p 2"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/earth -p 2"
  kubectl exec -i plite2-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mars -p 2"

  echo  "topics set up"
}

function singleCluster {
  echo "installing a single pulsar cluster..."  
 
  sleep 40

  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants create wojtekt"
  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns"
  #  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/wojtektopic -p 4"
  #  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces set-retention wojtekt/wojtekns --size 2M --time 1m"

  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mercury -p 8"
  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/venus -p 8"
  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/earth -p 8"
  kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/mars -p 8"

  echo "single pulsar cluster installed" 
}




#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-perf produce persistent://wojtekt/wojtekns/wojtektopic --rate 5000 --size 5120 --test-duration 15"

#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-perf consume persistent://wojtekt/wojtekns/wojtektopic & /pulsar/bin/pulsar-perf produce persistent://wojtekt/wojtekns/wojtektopic --rate 100000 --size 5120"

#   /pulsar/bin/pulsar-perf produce wojtekt/wojtekns/wojtektopic --rate 1 --size 1024
#   /pulsar/bin/pulsar-perf consume persistent://wojtekt/wojtekns/wojtektopic

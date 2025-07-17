#!/bin/bash

# List of CRDs to check
CRD_LIST=(
  "agents.agent.k8s.elastic.co"
  "apmservers.apm.k8s.elastic.co"
  "authorizationpolicies.security.istio.io"
  "beats.beat.k8s.elastic.co"
  "cloudeventsources.eventing.keda.sh"
  "clustercloudeventsources.eventing.keda.sh"
  "clustertriggerauthentications.keda.sh"
  "destinationrules.networking.istio.io"
  "elasticmapsservers.maps.k8s.elastic.co"
  "elasticsearchautoscalers.autoscaling.k8s.elastic.co"
  "elasticsearches.elasticsearch.k8s.elastic.co"
  "enterprisesearches.enterprisesearch.k8s.elastic.co"
  "envoyfilters.networking.istio.io"
  "gateways.networking.istio.io"
  "grafanaalertrulegroups.grafana.integreatly.org"
  "grafanacontactpoints.grafana.integreatly.org"
  "grafanadashboards.grafana.integreatly.org"
  "grafanadatasources.grafana.integreatly.org"
  "grafanafolders.grafana.integreatly.org"
  "grafananotificationpolicies.grafana.integreatly.org"
  "grafananotificationtemplates.grafana.integreatly.org"
  "grafanas.grafana.integreatly.org"
  "istiooperators.install.istio.io"
  "kafkabridges.kafka.strimzi.io"
  "kafkaconnectors.kafka.strimzi.io"
  "kafkaconnects.kafka.strimzi.io"
  "kafkamirrormaker2s.kafka.strimzi.io"
  "kafkamirrormakers.kafka.strimzi.io"
  "kafkanodepools.kafka.strimzi.io"
  "kafkarebalances.kafka.strimzi.io"
  "kafkas.kafka.strimzi.io"
  "kafkatopics.kafka.strimzi.io"
  "kafkausers.kafka.strimzi.io"
  "kibanas.kibana.k8s.elastic.co"
  "logstashes.logstash.k8s.elastic.co"
  "peerauthentications.security.istio.io"
  "proxyconfigs.networking.istio.io"
  "requestauthentications.security.istio.io"
  "scaledjobs.keda.sh"
  "scaledobjects.keda.sh"
  "scheduledsparkapplications.sparkoperator.k8s.io"
  "serviceentries.networking.istio.io"
  "servicemonitors.monitoring.coreos.com"
  "sidecars.networking.istio.io"
  "sparkapplications.sparkoperator.k8s.elastic.co"
  "stackconfigpolicies.stackconfigpolicy.k8s.elastic.co"
  "strimzipodsets.core.strimzi.io"
  "telemetries.telemetry.istio.io"
  "triggerauthentications.keda.sh"
  "virtualservices.networking.istio.io"
  "wasmplugins.extensions.istio.io"
  "workloadentries.networking.istio.io"
  "workloadgroups.networking.istio.io"
)

# Fetch installed CRDs
INSTALLED_CRDS=$(kubectl get crd -o jsonpath='{.items[*].metadata.name}')

# Check for each CRD in the list
for crd in "${CRD_LIST[@]}"; do
  if echo "$INSTALLED_CRDS" | grep -q "$crd"; then
    echo "⚠️  WARNING: The CRD '$crd' is already installed in your cluster. Reinstallation will occur during the JFrog ML Helm chart installation."
  fi
done
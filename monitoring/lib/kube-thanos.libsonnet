local t = import 'github.com/thanos-io/kube-thanos/jsonnet/kube-thanos/thanos.libsonnet';

local commonConfig = {
  config+:: {
    local cfg = self,
    namespace: 'monitoring',
    // renovate: datasource=docker depName=quay.io/thanos/thanos
    version: 'v0.37.2',
    image: 'quay.io/thanos/thanos:' + cfg.version,
    imagePullPolicy: 'IfNotPresent',
    objectStorageConfig: {
      name: 'thanos-objectstorage',
      key: 'thanos.yaml',
    },
  },
};

function(params={}) {
  local cfg = commonConfig.config + params,

  local store = t.store(cfg {
    replicas: 1,
    serviceMonitor: true,
    resources: {
      limits: {
        memory: '2Gi',
      },
      requests: {
        cpu: '100m',
        memory: '256Mi',
      },
    },
  }),
  store: store {
    networkPolicy: {
      kind: 'NetworkPolicy',
      apiVersion: 'networking.k8s.io/v1',
      metadata: {
        name: $.store.config.name,
        namespace: $.store.config.namespace,
        labels: $.store.config.commonLabels,
      },
      spec: {
        podSelector: {
          matchLabels: $.store.config.podLabelSelector,
        },
        egress: [{}],  // Allow all outside egress to connect to object storage
        ingress: [{
          from: [{
            namespaceSelector: {
              matchLabels: {
                'kubernetes.io/metadata.name': $.store.config.namespace,
              },
            },
            podSelector: {
              matchLabels: {
                'app.kubernetes.io/name': 'thanos-query',
              },
            },
          }],
        }],
        policyTypes: ['Egress'],
      },
    },
  },

  query: t.query(cfg {
    replicas: 1,
    replicaLabels: ['prometheus_replica', 'rule_replica'],
    serviceMonitor: true,
    stores: [store.storeEndpoint, 'dnssrv+_grpc._tcp.prometheus-parca-analytics-thanos-sidecar.%s.svc.cluster.local' % cfg.namespace],
    resources: {
      limits: {
        memory: '1Gi',
      },
      requests: {
        cpu: '100m',
        memory: '128Mi',
      },
    },
  }) + {
    networkPolicy: {
      kind: 'NetworkPolicy',
      apiVersion: 'networking.k8s.io/v1',
      metadata: {
        name: $.query.config.name,
        namespace: $.query.config.namespace,
        labels: $.query.config.commonLabels,
      },
      spec: {
        podSelector: {
          matchLabels: $.query.config.podLabelSelector,
        },
        egress: [{
          to: [
            {
              namespaceSelector: {
                matchLabels: {
                  'kubernetes.io/metadata.name': 'parca-analytics',
                },
              },
            },
            {
              namespaceSelector: {
                matchLabels: {
                  'kubernetes.io/metadata.name': 'kube-system',
                },
              },
            },
          ],
        }],
      },
    },
  },
}

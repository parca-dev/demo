local pa = import 'github.com/parca-dev/parca-agent/deploy/lib/parca-agent/parca-agent.libsonnet';

local defaults = {
  namespace: 'parca',
  // renovate: datasource=docker depName=ghcr.io/parca-dev/parca-agent
  version: 'v0.36.0',
  image: 'ghcr.io/parca-dev/parca-agent:' + self.version,
  stores: ['parca.%s.svc.cluster.local:7070' % self.namespace],
  insecure: true,
  insecureSkipVerify: true,
  logLevel: 'debug',
  resources: {
    limits: {
      cpu: '100m',
      memory: '1Gi',
    },
    requests: {
      cpu: '10m',
      memory: '1Gi',
    },
  },
  podMonitor: true,
};

function(params={})
  local config = defaults + params;

  pa(config) {
    daemonSet+: {
      spec+: {
        template+: {
          spec+: {
            priorityClassName: 'system-node-critical',
          },
        },
      },
    },

    networkPolicy: {
      apiVersion: 'networking.k8s.io/v1',
      kind: 'NetworkPolicy',
      metadata: {
        name: $.config.name,
        namespace: $.config.namespace,
        labels: $.config.commonLabels,
      },
      spec: {
        egress: [{}],
        ingress: [{
          from: [
            {
              namespaceSelector: {
                matchLabels: {
                  'kubernetes.io/metadata.name': 'monitoring',
                },
              },
              podSelector: {
                matchLabels: {
                  'app.kubernetes.io/name': 'prometheus',
                },
              },
            },
          ],
          ports: [{
            port: 'http',
          }],
        }],
        podSelector: $.daemonSet.spec.selector,
        policyTypes: [
          'Egress',
          'Ingress',
        ],
      },
    },
  }

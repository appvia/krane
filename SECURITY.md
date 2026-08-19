# Security Policy

## Reporting a Vulnerability

Please contact security@appvia.io

## The dashboard is unauthenticated

`krane dashboard` serves everything Krane has learned about a cluster's RBAC to
anyone who can reach its port, and it binds to `0.0.0.0` by default so that it
is reachable through a Service when running in a cluster. It has no
authentication, and the Helm chart does not expose it.

Options for restricting access:

- reach it with `kubectl port-forward` rather than exposing the Service;
- apply a NetworkPolicy. The chart labels the pod `network/krane: "true"` and
  ships a policy using that label;
- put an authenticating proxy in front of it;
- pass `-b 127.0.0.1` when running locally, so it is not reachable from the
  network.

## RBAC data is treated as untrusted input

Object names come from the cluster and can contain anything a Kubernetes name
allows. The dashboard renders them as text, never as markup: `v-html` is
prohibited by a lint rule, tooltips are built as text nodes, and the server
sends a Content-Security-Policy of `default-src 'self'`.

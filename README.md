# rbacvis - Kubernetes RBAC static analysis & visualisation tool

Author::  Marcin Ciszak (marcin.ciszak@appvia.io)

Copyright:: Copyright (c) 2018 Appvia

License:: mit, see LICENSE.txt

## Links

* https://github.com/appvia/rbacvis

## Install

```
./bin/setup
```

## Examples

### Run report

1. To run report against running cluster you must provide kubectl context 
```
./bin/rbacvis report -k <context> -c <cluster-name>
```

1. To run report against local RBAC yaml files, provide directory path
```
./bin/rbacvis report -d <directory> -c <cluster-name>
```
NOTE: rbacvis expects the following files to be present (psp.yaml, roles.yaml, clusterroles.yaml, rolebindings.yaml, clusterrolebindings.yaml)

### Dashboard

To see RBAC tree and associated findings run the following command to start UI for given cluster name
```
./bin/rbacvis dashboard -c <cluster-name>
```

## Tests 

```
bundle exec rspec
```

## Contributing


{{ source "common.ikt" }}

echo # Set up infrakit.  This assumes Docker has been installed
{{ $infrakitHome := `/infrakit` }}
mkdir -p {{$infrakitHome}}/configs
mkdir -p {{$infrakitHome}}/logs
mkdir -p {{$infrakitHome}}/plugins

{{/* $something are local variables inside this template file */}}
{{ $dockerImage := `infrakit/devbundle:dev` }}

# dockerMounts {{ $dockerMounts := `-v /var/run/docker.sock:/var/run/docker.sock -v /infrakit:/infrakit ` }}
# dockerEnvs   {{ $dockerEnvs := `-e INFRAKIT_HOME=/infrakit -e INFRAKIT_PLUGINS_DIR=/infrakit/plugins `  }}
# {{ $clusterName := var `vars/cluster/name` }}
# {{ $clusterSize := var `vars/cluster/size` }}
# {{ $clusterProvider := var `vars/cluster/provider` }}

# Cluster {{ $clusterName }} size is {{ $clusterSize }} running on {{ $clusterProvider }}

echo "Cluster {{ $clusterName }} size is {{ $clusterSize }} running on {{ $clusterProvider }}"
echo "alias infrakit='docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit'" >> /root/.bashrc

alias infrakit='docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit'

echo "Starting up infrakit  ######################"
docker run -d --restart always --name infrakit -p 24864:24864 {{ $dockerMounts }} {{ $dockerEnvs }} \
       -e INFRAKIT_AWS_STACKNAME={{ $clusterName }} \
       -e INFRAKIT_AWS_METADATA_POLL_INTERVAL=300s \
       -e INFRAKIT_AWS_METADATA_TEMPLATE_URL=https://raw.githubusercontent.com/infrakit/examples/master/latest/metadata/aws/export.ikt \
       -e INFRAKIT_AWS_NAMESPACE_TAGS=infrakit.scope={{ $clusterName }} \
       -e INFRAKIT_MANAGER_BACKEND=swarm \
       -e INFRAKIT_VARS_TEMPLATE={{var `vars/infrakit/config/root`}}/vars.json \
       -e INFRAKIT_ADVERTISE={{ var `/local/swarm/manager/logicalID` }}:24864 \
       -e INFRAKIT_TAILER_PATH=/var/log/cloud-init-output.log \
       -e INFRAKIT_GROUP_POLL_INTERVAL=30s \
       {{ $dockerImage }} \
       infrakit plugin start manager group vars aws combo swarm time tailer ingress kubernetes

sleep 5

{{ if eq (var `/local/swarm/manager/logicalID`) (var `/cluster/swarm/join/ip`) }}
echo "This is here only on first node."
{{ else }}
# Need time for leadership to be determined.
sleep 10
{{ end }}

echo "Rendering a view of the config groups.json for debugging."
docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit template {{var `vars/infrakit/config/root`}}/groups.json

#Try to commit - this is idempotent but don't error out and stop the cloud init script!
echo "Commiting to infrakit $(docker run --rm {{$dockerMounts}} {{$dockerEnvs}} {{$dockerImage}} infrakit manager commit {{var `vars/infrakit/config/root`}}/groups.json)"

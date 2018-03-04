# Setup Hortoniabank demo on HDP 2.6.4 sandbox
# Reset Ambari admin password, SSH in as root and run below:
# curl -sSL https://raw.githubusercontent.com/abajwa-hw/masterclass/master/ranger-atlas/setup_sandbox.sh | sudo -E sh

#Ambari admin password - replace with your own
export ambari_pass=BadPass#1

#Choose password for Zeppelin users
export zeppelin_pass=BadPass#1

#choose kerberos realm
export kdc_realm=HWX.COM

export host=$(hostname -f)


#make sure Ambari is up
while ! echo exit | nc localhost 8080; do echo "waiting for Ambari to come up..."; sleep 10; done


#detect name of cluster
output=`curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari'  http://${host}:8080/api/v1/clusters`
cluster_name=`echo $output | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p'`


####### Configure cluster for demo

#stop Flume, oozie, spark2 and put in maintenance mode
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop FALCON via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/FLUME
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop OOZIE via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/OOZIE
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop SPARK2 via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/SPARK2
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Flume maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "ON"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/FLUME
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"OOZIE maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "ON"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/OOZIE
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"SPARK2 maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "ON"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/SPARK2


#make sure kafka, hbase, ambari infra, atlas, HDFS are out of maintenance mode
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Remove Kafka from maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "OFF"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/KAFKA
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Remove Hbase from maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "OFF"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/HBASE
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Remove Ambari Infra from maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "OFF"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/AMBARI_INFRA
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Remove Atlas from maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "OFF"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/ATLAS
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Remove HDFS from maintenance mode"}, "Body": {"ServiceInfo": {"maintenance_state": "OFF"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/HDFS

## Ranger config changes

#Enable kafka plugin for Ranger 
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-env -k ranger-kafka-plugin-enabled -v Yes
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-kafka-plugin-properties -k ranger-kafka-plugin-enabled -v Yes

#enable Audits for Ranger
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-env -k xasecure.audit.destination.solr -v true

#enable other plugin audits
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-hdfs-audit -k xasecure.audit.destination.solr -v true
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-atlas-audit -k xasecure.audit.destination.solr -v true
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-kafka-audit -k xasecure.audit.destination.solr -v true
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-hbase-audit -k xasecure.audit.destination.solr -v true

#Ranger tagsync mappings
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hdfs.instance.hdp.ranger.service -v ${cluster_name}_hadoop
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hive.instance.hdp.ranger.service -v ${cluster_name}_hive
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hbase.instance.hdp.ranger.service -v ${cluster_name}_hbase
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.kafka.instance.hdp.ranger.service -v ${cluster_name}_kafka
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.atlas.instance.hdp.ranger.service -v ${cluster_name}_atlas
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.knox.instance.hdp.ranger.service -v ${cluster_name}_knox
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.yarn.instance.hdp.ranger.service -v ${cluster_name}_yarn
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.tag.instance.hdp.ranger.service -v tags


#restart Ranger
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop RANGER via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/RANGER
sleep 10
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start RANGER via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/RANGER
sleep 30

#curl  -u admin:${ambari_pass} -H "X-Requested-By: ambari" -X POST  -d '{"RequestInfo":{"command":"RESTART","context":"Restart all required services","operation_level":"host_component"},"Requests/resource_filters":[{"hosts_predicate":"HostRoles/stale_configs=true"}]}' http://localhost:8080/api/v1/clusters/${cluster_name}/requests
#sleep 20


#wait until ranger comes up
while ! echo exit | nc localhost 6080; do echo "waiting for Ranger to come up..."; sleep 10; done


#Start Kafka, HBase, Ambari infra, Atlas
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start KAFKA via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/KAFKA
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start HBASE via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/HBASE
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Ambari infra via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/AMBARI_INFRA
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Atlas via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/ATLAS



#Change Hive doAs setting and enable audits
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.server2.enable.doAs  -v true
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c ranger-hive-audit -k xasecure.audit.destination.solr -v true

#restart Hive

curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop HIVE via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/HIVE
sleep 10
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start HIVE via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${host}:8080/api/v1/clusters/${cluster_name}/services/HIVE
sleep 30

#wait until hive come up
while ! echo exit | nc localhost 10000; do echo "waiting for hive to come up..."; sleep 10; done


#note needed: if collection missing, create it: https://community.hortonworks.com/articles/90168/modifying-ranger-audit-solr-config.html
#/usr/lib/ambari-infra-solr-client/solrCloudCli.sh --zookeeper-connect-string ${host}:2181/infra-solr --check-config --config-set ranger_audits
#/usr/lib/ambari-infra-solr-client/solrCloudCli.sh --zookeeper-connect-string  ${host}:2181/infra-solr --upload-config --config-dir /usr/hdp/current/ranger-admin/contrib/solr_for_audit_setup/conf --config-set ranger_audits 
#/usr/lib/ambari-infra-solr-client/solrCloudCli.sh --zookeeper-connect-string ${host}:2181/infra-solr --create-collection --collection ranger_audits --config-set ranger_audits --shards 1 --replication 1 --max-shards 1 --retry 5 --interval 10


####### Start HortoniaBank demo setup


#download hortonia scripts
cd /tmp
git clone https://github.com/abajwa-hw/masterclass  

cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./04-create-os-users.sh    

#also need anonymous user for kafka Ranger policy
useradd ANONYMOUS    

users="kate_hr ivanna_eu_hr joe_analyst sasha_eu_hr john_finance mark_bizdev jermy_contractor diane_csr log_monitor"
groups="hr analyst us_employee eu_employee finance business_dev contractor csr etluser"
ambari_url="http://${host}:8080/api/v1"

for user in ${users}; do
  echo "adding user ${user} to Ambari"
  curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d "{\"Users/user_name\":\"${user}\",\"Users/password\":\"${ambari_pass}\",\"Users/active\":\"true\",\"Users/admin\":\"false\"}" ${ambari_url}/users 
done 

#create groups in Ambari
for group in ${groups}; do
  curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d "{\"Groups/group_name\":\"${group}\"}" ${ambari_url}/groups
done

#HR group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members


#analyst group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"analyst"}' ${ambari_url}/groups/analyst/members

#us_employee group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members

#eu_employee group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members

#finance group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"john_finance", "MemberInfo/group_name":"finance"}' ${ambari_url}/groups/finance/members

#bizdev group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"mark_bizdev", "MemberInfo/group_name":"business_dev"}' ${ambari_url}/groups/business_dev/members

#contractor group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"jermy_contractor", "MemberInfo/group_name":"contractor"}' ${ambari_url}/groups/contractor/members

#csr group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"diane_csr", "MemberInfo/group_name":"csr"}' ${ambari_url}/groups/csr/members

#csr group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"log_monitor", "MemberInfo/group_name":"etluser"}' ${ambari_url}/groups/etluser/members
	


#add groups to Hive views
curl -u admin:${ambari_pass} -i -H "X-Requested-By: blah" -X PUT ${ambari_url}/views/HIVE/versions/1.5.0/instances/AUTO_HIVE_INSTANCE/privileges \
   --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'

curl -u admin:${ambari_pass} -i -H 'X-Requested-By: blah' -X PUT ${ambari_url}/views/HIVE/versions/2.0.0/instances/AUTO_HIVE20_INSTANCE/privileges \
   --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'




#pull latest notebooks
curl -sSL https://raw.githubusercontent.com/hortonworks-gallery/zeppelin-notebooks/master/update_all_notebooks.sh | sudo -E sh 

#make sure HDFS is up
while ! echo exit | nc localhost 50070; do echo "waiting for HDFS to come up..."; sleep 10; done

sudo -u zeppelin hdfs dfs -rmr /user/zeppelin/notebook/*
sudo -u zeppelin hdfs dfs -put /usr/hdp/current/zeppelin-server/notebook/* /user/zeppelin/notebook/

#disable anonymous login and create Hortonia users
cat << EOF > /tmp/zeppelin-env.json
{
  "properties": {
    "shiro_ini_content": "\n [users]\n admin = ${zeppelin_pass},admin\n ivanna_eu_hr = ${zeppelin_pass}, admin\n diane_csr = ${zeppelin_pass}, admin\n joe_analyst = ${zeppelin_pass}, admin\n \n \n [main]\n sessionManager = org.apache.shiro.web.session.mgt.DefaultWebSessionManager\n cacheManager = org.apache.shiro.cache.MemoryConstrainedCacheManager\n securityManager.cacheManager = \$cacheManager\n cookie = org.apache.shiro.web.servlet.SimpleCookie\n cookie.name = JSESSIONID\n cookie.httpOnly = true\n sessionManager.sessionIdCookie = \$cookie\n securityManager.sessionManager = \$sessionManager\n securityManager.sessionManager.globalSessionTimeout = 86400000\n shiro.loginUrl = /api/login\n \n [roles]\n role1 = *\n role2 = *\n role3 = *\n admin = *\n \n [urls]\n /api/version = anon\n #/** = anon\n /** = authc\n \n"
  }
}
EOF

/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${host} --port 8080 --cluster ${cluster_name} -a set -c zeppelin-shiro-ini -f /tmp/zeppelin-env.json
sleep 5


#make sure YARN up
while ! echo exit | nc localhost 8088; do echo "waiting for YARN to come up..."; sleep 10; done

#kill any previous Hive/tez apps to clear queue
for app in $(yarn application -list | awk '$2==hive && $3==TEZ && $6 == "ACCEPTED" || $6 == "RUNNING" { print $1 }')
do 
	yarn application -kill  "$app"
done


#make sure Ranger up
while ! echo exit | nc localhost 6080; do echo "waiting for Ranger to come up..."; sleep 10; done

## update ranger to support deny policies
ranger_curl="curl -u admin:admin"
ranger_url="http://${host}:6080/service"


${ranger_curl} ${ranger_url}/public/v2/api/servicedef/name/hive \
  | jq '.options = {"enableDenyAndExceptionsInPolicies":"true"}' \
  | jq '.policyConditions = [
{
	  "itemId": 1,
	  "name": "resources-accessed-together",
	  "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesAccessedTogetherCondition",
	  "evaluatorOptions": {},
	  "label": "Resources Accessed Together?",
	  "description": "Resources Accessed Together?"
},{
	"itemId": 2,
	"name": "not-accessed-together",
	"evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesNotAccessedTogetherCondition",
	"evaluatorOptions": {},
	"label": "Resources Not Accessed Together?",
	"description": "Resources Not Accessed Together?"
}
]' > hive.json

${ranger_curl} -i \
  -X PUT -H "Accept: application/json" -H "Content-Type: application/json" \
  -d @hive.json ${ranger_url}/public/v2/api/servicedef/name/hive


sleep 10


cd /tmp/masterclass/ranger-atlas/Scripts/

			  
echo "import ranger Hive policies..."
< ranger-policies-enabled.json jq '.policies[].service = "'${cluster_name}'_hive"' > ranger-policies-apply.json
${ranger_curl} -X POST \
-H "Content-Type: multipart/form-data" \
-H "Content-Type: application/json" \
-F 'file=@ranger-policies-apply.json' \
		  "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hive"

echo "import ranger HDFS policies..." #to give hive access to /hive_data HDFS dir
< ranger-hdfs-policies.json jq '.policies[].service = "'${cluster_name}'_hadoop"' > ranger-hdfs-policies-apply.json
${ranger_curl} -X POST \
-H "Content-Type: multipart/form-data" \
-H "Content-Type: application/json" \
-F 'file=@ranger-hdfs-policies-apply.json' \
		  "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hdfs"

echo "import ranger kafka policies..." #  to give ANONYMOUS access to kafka or Atlas won't work
< ranger-kafka-policies.json jq '.policies[].service = "'${cluster_name}'_kafka"' > ranger-kafka-policies-apply.json
${ranger_curl} -X POST \
-H "Content-Type: multipart/form-data" \
-H "Content-Type: application/json" \
-F 'file=@ranger-kafka-policies-apply.json' \
		  "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=kafka"
		  



cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./01-atlas-import-classification.sh
#./02-atlas-import-entities.sh      ## this gives 500 error so moving to end
./03-update-servicedefs.sh

		
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
su hdfs -c ./05-create-hdfs-user-folders.sh
su hdfs -c ./06-copy-data-to-hdfs.sh

#make sure hive is up
while ! echo exit | nc localhost 10000; do echo "waiting for hive to come up..."; sleep 10; done

./07-create-hive-schema.sh
 		  

#enable kerberos

cd /tmp
git clone https://github.com/crazyadmins/useful-scripts.git
cd useful-scripts/ambari/
cat << EOF > ambari.props
CLUSTER_NAME=${cluster_name}
AMBARI_ADMIN_USER=admin
AMBARI_ADMIN_PASSWORD=${ambari_pass}
AMBARI_HOST=$(hostname -f)
KDC_HOST=$(hostname -f)
REALM=${kdc_realm}
KERBEROS_CLIENTS=$(hostname -f)
EOF

cat ambari.props
chmod +x setup_kerberos.sh 
./setup_kerberos.sh 


#make sure Atlas/Hive are up
while ! echo exit | nc localhost 21000; do echo "waiting for atlas to come up..."; sleep 10; done
while ! echo exit | nc localhost 10000; do echo "waiting for hive to come up..."; sleep 10; done


#Now that we enabled Kafka Ranger plugin (by enabling kerberos), import Atlas entities
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./02-atlas-import-entities.sh
# Need to do this twice due to bug: RANGER-1897 
# second time, the notification is of type ENTITY_UPDATE which gets processed correctly
./02-atlas-import-entities.sh
         

echo "Automated portion of setup is complete, next please create the tag repo in Ranger, associate with Hive and import tag policies"
echo "See https://github.com/abajwa-hw/masterclass/blob/master/ranger-atlas/README.md for more details"
echo "Once complete, see here for walk through of demo: https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html"


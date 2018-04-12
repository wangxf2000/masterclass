# Setup Hortoniabank demo on HDP 2.6.4 Cloudbreak
# Pre-reqs:
# HDP cluster with Hive/Ranger/Atlas already installed
# 1. Install Zeppelin if not already installed
# 2. Ranger admin user with known credentials (or create your own) e.g. ali/Hadoop123
#
# TODOs: kafka/hbase policies not created? LLAP?
#
# Steps:
# SSH in to Ambari node as root and run below:
# curl -sSL https://raw.githubusercontent.com/abajwa-hw/masterclass/master/ranger-atlas/setup_cdb.sh | sudo -E sh

#Ambari admin password - replace with your own
export ambari_pass=${ambari_pass:-BadPass#1} 

#Ranger admin user credentials - replace with your own
export ranger_admin_user=ali
export ranger_admin_password=Hadoop123


#Choose password for Zeppelin users
export zeppelin_pass=BadPass#1

#whether to enable Hive ACID/transactions
export enable_hive_acid=${enable_hive_acid:-true}   

#where to enable kerberos
export enable_kerberos=${enable_kerberos:-false}   

#choose kerberos realm (if kerberos enabled)
export kdc_realm=HWX.COM

export ambari_host=$(hostname -f)


echo "####### Detect hosts.."
#detect name of cluster
output=`curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari'  http://${ambari_host}:8080/api/v1/clusters`
export cluster_name=`echo $output | sed -n 's/.*"cluster_name" : "\([^\"]*\)".*/\1/p'`

export ranger_host=$(curl -u admin:${ambari_pass} -X GET http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/RANGER/components/RANGER_ADMIN|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

export hiveserver_host=$(curl -u admin:${ambari_pass} -X GET http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

export kafka_broker=$(curl -u admin:${ambari_pass} -X GET http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/KAFKA/components/KAFKA_BROKER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

export atlas_host=$(curl -u admin:${ambari_pass} -X GET http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/ATLAS/components/ATLAS_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

       	

#detect hive port from transport mode
hive_transport_mode=$(/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a get -c hive-site | grep  hive.server2.transport.mode | grep -Po ': "([a-zA-Z]+)'|grep -Po '([a-zA-Z]+)')
if [ ${hive_transport_mode} == "http" ]; then
     export hiveserver_port=10001
     export hiveserver_url="jdbc:hive2://${hiveserver_host}:${hiveserver_port}/;transportMode=http;httpPath=cliservice"
else
     export hiveserver_port=10000
     export hiveserver_url="jdbc:hive2://${hiveserver_host}:${hiveserver_port}/"     
fi


#ranger_curl="curl -u admin:${ambari_pass}"
ranger_curl="curl -u ${ranger_admin_user}:${ranger_admin_password}"
ranger_url="http://${ranger_host}:6080/service"

echo "Testing ranger credentials..."
if [ $(${ranger_curl} ${ranger_url}/public/v2/api/servicedef/name/hive | grep -Po 401) ]; then
    echo "Invalid combination of ranger user or pass for user: ${ranger_admin_user}"
    exit 1
else
    echo "Ranger credentials succeeded"
fi



#make sure Ambari is up
while ! echo exit | nc ${ambari_host} 8080; do echo "waiting for Ambari to come up..."; sleep 10; done



echo "####### Download demo script and create local users ..."
cd /tmp
git clone https://github.com/abajwa-hw/masterclass  





cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./04-create-os-users.sh    
useradd ANONYMOUS    
    
echo "####### Configure cluster for demo..."



echo # Ranger config changes

echo Enable kafka plugin for Ranger 
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-env -k ranger-kafka-plugin-enabled -v Yes
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-kafka-plugin-properties -k ranger-kafka-plugin-enabled -v Yes

echo Enable kafka plugin for Ranger 
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-env -k ranger-hbase-plugin-enabled -v Yes
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-hbase-plugin-properties -k ranger-hbase-plugin-enabled -v Yes


echo Ranger tagsync mappings
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hdfs.instance.cl1.ranger.service -v ${cluster_name}_hadoop
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hdfs.instance.hdp.ranger.service -v ${cluster_name}_hadoop
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hive.instance.hdp.ranger.service -v ${cluster_name}_hive
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.hbase.instance.cl1.ranger.service -v ${cluster_name}_hbase
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-tagsync-site -k ranger.tagsync.atlas.kafka.instance.cl1.ranger.service -v ${cluster_name}_kafka


echo Ranger setup Unix sync
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c ranger-ugsync-site -k ranger.usersync.source.impl.class -v org.apache.ranger.unixusersync.process.UnixUserGroupBuilder


echo stop Ranger
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop RANGER via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/RANGER
while echo exit | nc ${ranger_host} 6080; do echo "waiting for Ranger to go down..."; sleep 10; done
sleep 10

echo start Ranger
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start RANGER via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/RANGER


echo wait until ranger comes up
while ! echo exit | nc ${ranger_host} 6080; do echo "waiting for Ranger to come up..."; sleep 10; done


echo Change Hive doAs setting 
/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.server2.enable.doAs  -v true


if [ "${enable_hive_acid}" = true  ]; then
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-env -k hive_txn_acid -v on
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.support.concurrency -v true
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.compactor.initiator.on -v true
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.compactor.worker.threads -v 1
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.enforce.bucketing -v true
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.exec.dynamic.partition.mode -v nonstrict
	/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c hive-site -k hive.txn.manager -v org.apache.hadoop.hive.ql.lockmgr.DbTxnManager
fi


echo restart Hive

curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Stop HIVE via REST"}, "Body": {"ServiceInfo": {"state": "INSTALLED"}}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/HIVE
while echo exit | nc ${hiveserver_host} ${hiveserver_port}; do echo "waiting for Hive to go down..."; sleep 10; done
while echo exit | nc ${hiveserver_host} 50111; do echo "waiting for Hcat to go down..."; sleep 10; done
sleep 15
curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start HIVE via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://${ambari_host}:8080/api/v1/clusters/${cluster_name}/services/HIVE


echo wait until hive comes up
while ! echo exit | nc ${hiveserver_host} ${hiveserver_port}; do echo "waiting for Hive to come up..."; sleep 10; done



echo ###### Start HortoniaBank demo setup



users="kate_hr ivanna_eu_hr joe_analyst sasha_eu_hr john_finance mark_bizdev jermy_contractor diane_csr log_monitor"
groups="hr analyst us_employee eu_employee finance business_dev contractor csr etluser"
ambari_url="http://${ambari_host}:8080/api/v1"

for user in ${users}; do
  echo "adding user ${user} to Ambari"
  curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d "{\"Users/user_name\":\"${user}\",\"Users/password\":\"${ambari_pass}\",\"Users/active\":\"true\",\"Users/admin\":\"false\"}" ${ambari_url}/users 
done 

echo create groups in Ambari
for group in ${groups}; do
  echo "adding group ${group} to Ambari"
  curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d "{\"Groups/group_name\":\"${group}\"}" ${ambari_url}/groups
done

echo HR group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members


echo analyst group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"analyst"}' ${ambari_url}/groups/analyst/members

echo us_employee group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members

echo eu_employee group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members

echo finance group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"john_finance", "MemberInfo/group_name":"finance"}' ${ambari_url}/groups/finance/members

echo bizdev group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"mark_bizdev", "MemberInfo/group_name":"business_dev"}' ${ambari_url}/groups/business_dev/members

echo contractor group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"jermy_contractor", "MemberInfo/group_name":"contractor"}' ${ambari_url}/groups/contractor/members

echo csr group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"diane_csr", "MemberInfo/group_name":"csr"}' ${ambari_url}/groups/csr/members

echo csr group membership
curl -u admin:${ambari_pass} -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"log_monitor", "MemberInfo/group_name":"etluser"}' ${ambari_url}/groups/etluser/members
    


echo add groups to Hive views
curl -u admin:${ambari_pass} -i -H "X-Requested-By: blah" -X PUT ${ambari_url}/views/HIVE/versions/1.5.0/instances/AUTO_HIVE_INSTANCE/privileges \
   --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'

curl -u admin:${ambari_pass} -i -H 'X-Requested-By: blah' -X PUT ${ambari_url}/views/HIVE/versions/2.0.0/instances/AUTO_HIVE20_INSTANCE/privileges \
   --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'




echo pull latest notebooks
curl -sSL https://raw.githubusercontent.com/hortonworks-gallery/zeppelin-notebooks/master/update_all_notebooks.sh | sudo -E sh 

sudo -u zeppelin hdfs dfs -rmr /user/zeppelin/notebook/*
sudo -u zeppelin hdfs dfs -put /usr/hdp/current/zeppelin-server/notebook/* /user/zeppelin/notebook/

echo disable anonymous login and create Hortonia users
cat << EOF > /tmp/zeppelin-env.json
{
  "properties": {
    "shiro_ini_content": "\n [users]\n admin = ${zeppelin_pass},admin\n ivanna_eu_hr = ${zeppelin_pass}, admin\n log_monitor = ${zeppelin_pass}, admin\n joe_analyst = ${zeppelin_pass}, admin\n \n \n [main]\n sessionManager = org.apache.shiro.web.session.mgt.DefaultWebSessionManager\n cacheManager = org.apache.shiro.cache.MemoryConstrainedCacheManager\n securityManager.cacheManager = \$cacheManager\n cookie = org.apache.shiro.web.servlet.SimpleCookie\n cookie.name = JSESSIONID\n cookie.httpOnly = true\n sessionManager.sessionIdCookie = \$cookie\n securityManager.sessionManager = \$sessionManager\n securityManager.sessionManager.globalSessionTimeout = 86400000\n shiro.loginUrl = /api/login\n \n [roles]\n role1 = *\n role2 = *\n role3 = *\n admin = *\n \n [urls]\n /api/version = anon\n #/** = anon\n /** = authc\n \n"
  }
}
EOF

/var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host ${ambari_host} --port 8080 --cluster ${cluster_name} -a set -c zeppelin-shiro-ini -f /tmp/zeppelin-env.json
sleep 5


echo kill any previous Hive/tez apps to clear queue
for app in $(yarn application -list | awk '$2==hive && $3==TEZ && $6 == "ACCEPTED" || $6 == "RUNNING" { print $1 }')
do 
    yarn application -kill  "$app"
done


echo make sure Ranger up
while ! echo exit | nc ${ranger_host} 6080; do echo "waiting for Ranger to come up..."; sleep 10; done

echo update ranger to support deny policies



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

#TODO: Kafka repo not present even though plugin enabled
echo "import ranger kafka policies..." #  to give ANONYMOUS access to kafka or Atlas won't work
< ranger-kafka-policies.json jq '.policies[].service = "'${cluster_name}'_kafka"' > ranger-kafka-policies-apply.json
${ranger_curl} -X POST \
-H "Content-Type: multipart/form-data" \
-H "Content-Type: application/json" \
-F 'file=@ranger-kafka-policies-apply.json' \
          "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=kafka"


#TODO: Hbase repo not present even though plugin enabled          
echo "import ranger hbase policies..."
< ranger-hbase-policies.json jq '.policies[].service = "'${cluster_name}'_hbase"' > ranger-hbase-policies-apply.json
${ranger_curl} -X POST \
-H "Content-Type: multipart/form-data" \
-H "Content-Type: application/json" \
-F 'file=@ranger-hbase-policies-apply.json' \
         "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hbase"




cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
chmod +x *.sh

sed -i.bak "s/RANGER_ADMIN_USER=admin/RANGER_ADMIN_USER=${ranger_admin_user}/g" env_ranger.sh
sed -i.bak "s/RANGER_ADMIN_PASS=admin/RANGER_ADMIN_PASS=${ranger_admin_password}/g" env_ranger.sh

./01-atlas-import-classification.sh
#./02-atlas-import-entities.sh      ## this gives 500 error so moving to end
./03-update-servicedefs.sh

        
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
su hdfs -c ./05-create-hdfs-user-folders.sh
su hdfs -c ./06-copy-data-to-hdfs.sh

echo make sure hive is up
while ! echo exit | nc ${hiveserver_host} ${hiveserver_port}; do echo "waiting for hive to come up..."; sleep 10; done

#./07-create-hive-schema.sh
beeline -u ${hiveserver_url} -n hive -f data/HiveSchema.hsql

if [ "${enable_hive_acid}" = true  ]; then
  beeline -u ${hiveserver_url} -n hive -f data/TransSchema.hsql
fi

#untested on DPS
if [ "${enable_kerberos}" = true  ]; then           
	echo "Enabling kerberos..."

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

	echo "Creating users in KDC..."
	kadmin.local -q "addprinc -randkey joe_analyst/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey kate_hr/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey log_monitor/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey diane_csr/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey jermy_contractor/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey mark_bizdev/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey john_finance/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "addprinc -randkey ivanna_eu_hr/$(hostname -f)@${kdc_realm}"


	echo "Creating user keytabs..."
	kadmin.local -q "xst -k joe_analyst.keytab joe_analyst/$(hostname -f)@${kdc_realm}"    
	kadmin.local -q "xst -k log_monitor.keytab log_monitor/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k diane_csr.keytab diane_csr/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k jermy_contractor.keytab jermy_contractor/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k mark_bizdev.keytab mark_bizdev/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k john_finance.keytab john_finance/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k ivanna_eu_hr.keytab ivanna_eu_hr/$(hostname -f)@${kdc_realm}"
	kadmin.local -q "xst -k kate_hr.keytab kate_hr/$(hostname -f)@${kdc_realm}"

	mv *.keytab /etc/security/keytabs
fi


echo make sure Atlas/Hive are up
while ! echo exit | nc ${atlas_host} 21000; do echo "waiting for atlas to come up..."; sleep 10; done



echo "import Atlas entities"
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./02-atlas-import-entities.sh
# Need to do this twice due to bug: RANGER-1897 
# second time, the notification is of type ENTITY_UPDATE which gets processed correctly
./02-atlas-import-entities.sh




cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./08-create-hbase-kafka.sh

echo "Automated portion of setup is complete, next please create the tag repo in Ranger, associate with Hive and import tag policies"
echo "See https://github.com/abajwa-hw/masterclass/blob/master/ranger-atlas/README.md for more details"
echo "Once complete, see here for walk through of demo: https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html"

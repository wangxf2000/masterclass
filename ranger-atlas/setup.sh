#!/usr/bin/env bash
set -o xtrace

########################################################################
########################################################################
## variables



export HOME=${HOME:-/root}
export TERM=xterm

#overridable vars
export stack=${stack:-hdp}    #cluster name
export ambari_pass=${ambari_pass:-BadPass#1}  #ambari password
export ambari_services=${ambari_services:-HBASE HDFS MAPREDUCE2 PIG YARN HIVE ZOOKEEPER SLIDER AMBARI_INFRA TEZ RANGER ATLAS KAFKA SPARK ZEPPELIN}   #HDP services
export ambari_stack_version=${ambari_stack_version:-2.6}  #HDP Version
export host_count=${host_count:-skip}      #number of nodes, defaults to 1

#internal vars
export ambari_password="${ambari_pass}"
export cluster_name=${stack}
export recommendation_strategy="ALWAYS_APPLY_DONT_OVERRIDE_CUSTOM_VALUES"
export install_ambari_server=true
export deploy=true

## overrides
#export ambari_stack_version=2.6
#export ambari_repo=https://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.5.0.3/ambari.repo

export install_ambari_server ambari_pass host_count ambari_services
export ambari_password cluster_name recommendation_strategy

########################################################################
########################################################################
## 
cd

yum makecache
yum -y -q install git epel-release ntpd screen mysql-connector-java jq python-argparse python-configobj ack
curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/extras/deploy/install-ambari-bootstrap.sh | bash


########################################################################
########################################################################
## tutorial users
users="kate-hr ivana-eu-hr joe-analyst hadoop-admin compliance-admin hadoopadmin"
for user in ${users}; do
    sudo useradd ${user}
    printf "${ambari_pass}\n${ambari_pass}" | sudo passwd --stdin ${user}
    echo "${user} ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/99-masterclass
done
groups="hr analyst compliance us_employees eu_employees hadoop-users hadoop-admins"
for group in ${groups}; do
  groupadd ${group}
done
usermod -a -G hr kate-hr
usermod -a -G hr ivana-eu-hr
usermod -a -G analyst joe-analyst
usermod -a -G compliance compliance-admin
usermod -a -G us_employees kate-hr
usermod -a -G us_employees joe-analyst
usermod -a -G us_employees compliance-admin
usermod -a -G eu_employees ivana-eu-hr
usermod -a -G hadoop-admins hadoopadmin
usermod -a -G hadoop-admins hadoop-admin

########################################################################
########################################################################
## 
~/ambari-bootstrap/extras/deploy/prep-hosts.sh
~/ambari-bootstrap/ambari-bootstrap.sh

## Ambari Server specific tasks
if [ "${install_ambari_server}" = "true" ]; then

    sleep 30

    #Create users in Ambari
	for user in ${users}; do
	  echo "adding user ${user} to Ambari"
	  curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d "{\"Users/user_name\":\"${user}\",\"Users/password\":\"${ambari_pass}\",\"Users/active\":\"true\",\"Users/admin\":\"false\"}" http://localhost:8080/api/v1/users 
	done 

    #create groups in Ambari
	for group in ${groups}; do
	  curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d "{\"Groups/group_name\":\"${group}\"}" http://localhost:8080/api/v1/groups
	done

	#HR group membership
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"kate-hr", "MemberInfo/group_name":"hr"}' http://localhost:8080/api/v1/groups/hr/members
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"ivana-eu-hr", "MemberInfo/group_name":"hr"}' http://localhost:8080/api/v1/groups/hr/members

	#analyst group membership
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"joe-analyst", "MemberInfo/group_name":"analyst"}' http://localhost:8080/api/v1/groups/analyst/members

	#compliance group membership
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"compliance-admin", "MemberInfo/group_name":"compliance"}' http://localhost:8080/api/v1/groups/compliance/members

	#us_employees group membership
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"kate-hr", "MemberInfo/group_name":"us_employees"}' http://localhost:8080/api/v1/groups/us_employees/members
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"joe-analyst", "MemberInfo/group_name":"us_employees"}' http://localhost:8080/api/v1/groups/us_employees/members
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"compliance-admin", "MemberInfo/group_name":"us_employees"}' http://localhost:8080/api/v1/groups/us_employees/members

	#eu_employees group membership
	curl -iv -u admin:admin -H "X-Requested-By: ambari" -X POST -d '{"MemberInfo/user_name":"ivana-eu-hr", "MemberInfo/group_name":"eu_employees"}' http://localhost:8080/api/v1/groups/eu_employees/members



    
    ## add admin user to postgres for other services, such as Ranger
    cd /tmp
    sudo -u postgres createuser -U postgres -d -e -E -l -r -s admin
    sudo -u postgres psql -c "ALTER USER admin PASSWORD 'BadPass#1'";
    printf "\nhost\tall\tall\t0.0.0.0/0\tmd5\n" >> /var/lib/pgsql/data/pg_hba.conf
    systemctl restart postgresql

    ## bug workaround:
    sed -i "s/\(^    total_sinks_count = \)0$/\11/" /var/lib/ambari-server/resources/stacks/HDP/2.0.6/services/stack_advisor.py
    bash -c "nohup ambari-server restart" || true
    
    ambari_pass=admin source ~/ambari-bootstrap/extras/ambari_functions.sh
    until [ $(ambari_pass=BadPass#1 ${ambari_curl}/hosts -o /dev/null -w "%{http_code}") -eq "200" ]; do
        sleep 1
    done
    ambari_change_pass admin admin ${ambari_pass}

    yum -y install postgresql-jdbc
    ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar
    ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar

    cd ~/ambari-bootstrap/deploy

        ## various configuration changes for demo environments, and fixes to defaults
cat << EOF > configuration-custom.json
{
  "configurations" : {
    "core-site": {
        "hadoop.proxyuser.root.users" : "admin",
        "fs.trash.interval": "4320"
    },
    "hdfs-site": {
      "dfs.namenode.safemode.threshold-pct": "0.99"
    },
    "hive-site": {
        "hive.server2.enable.doAs" : "true",
        "hive.server2.transport.mode": "http",
        "hive.exec.compress.output": "true",
        "hive.merge.mapfiles": "true",
        "hive.server2.tez.initialize.default.sessions": "true",
        "hive.exec.post.hooks" : "org.apache.hadoop.hive.ql.hooks.ATSHook,org.apache.atlas.hive.hook.HiveHook",
        "hive.server2.tez.initialize.default.sessions": "true"
    },
    "mapred-site": {
        "mapreduce.job.reduce.slowstart.completedmaps": "0.7",
        "mapreduce.map.output.compress": "true",
        "mapreduce.output.fileoutputformat.compress": "true"
    },
    "yarn-site": {
        "yarn.acl.enable" : "true"
    },
    "ams-site": {
      "timeline.metrics.cache.size": "100"
    },
    "admin-properties": {
        "policymgr_external_url": "http://localhost:6080",
        "db_root_user": "admin",
        "db_root_password": "BadPass#1",
        "DB_FLAVOR": "POSTGRES",
        "db_user": "rangeradmin",
        "db_password": "BadPass#1",
        "db_name": "ranger",
        "db_host": "localhost"
    },
    "ranger-env": {
        "ranger_admin_username": "admin",
        "ranger_admin_password": "admin",
          "ranger-knox-plugin-enabled" : "No",
          "ranger-storm-plugin-enabled" : "No",
          "ranger-kafka-plugin-enabled" : "No",
        "ranger-hdfs-plugin-enabled" : "Yes",
        "ranger-hive-plugin-enabled" : "Yes",
        "ranger-hbase-plugin-enabled" : "Yes",
        "ranger-atlas-plugin-enabled" : "Yes",
        "ranger-yarn-plugin-enabled" : "Yes",
        "is_solrCloud_enabled": "true",
        "xasecure.audit.destination.solr" : "true",
        "xasecure.audit.destination.hdfs" : "true",
        "ranger_privelege_user_jdbc_url" : "jdbc:postgresql://localhost:5432/postgres",
        "create_db_dbuser": "true"
    },
    "ranger-admin-site": {
        "ranger.jpa.jdbc.driver": "org.postgresql.Driver",
        "ranger.jpa.jdbc.url": "jdbc:postgresql://localhost:5432/ranger",
	"ranger.servicedef.enableDenyAndExceptionsInPolicies": "true"
    },
    "ranger-hive-audit" : {
        "xasecure.audit.is.enabled" : "true",
        "xasecure.audit.destination.hdfs" : "true",
        "xasecure.audit.destination.solr" : "true",
        "xasecure.audit.destination.solr.zookeepers" : "localhost:2181/infra-solr"
    }
  }
}
EOF

    sleep 20
    ./deploy-recommended-cluster.bash

    if [ "${deploy}" = "true" ]; then

		cd ~
		sleep 20
		source ~/ambari-bootstrap/extras/ambari_functions.sh
		ambari_configs
		ambari_wait_request_complete 1
		cd ~
		sleep 30

		cd ~/
		git clone https://github.com/abajwa-hw/masterclass


		## update ranger to support deny policies
		ranger_curl="curl -u admin:admin"
		ranger_url="http://localhost:6080/service"

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


		## import ranger Hive policies
		< ranger-policies-enabled.json jq '.policies[].service = "'${cluster_name}'_hive"' > ranger-policies-apply.json
		${ranger_curl} -X POST \
		-H "Content-Type: multipart/form-data" \
		-H "Content-Type: application/json" \
		-F 'file=@ranger-policies-apply.json' \
				  "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hive"

		## import ranger HDFS policies
		< ranger-hdfs-policies.json jq '.policies[].service = "'${cluster_name}'_hadoop"' > ranger-hdfs-policies-apply.json
		${ranger_curl} -X POST \
		-H "Content-Type: multipart/form-data" \
		-H "Content-Type: application/json" \
		-F 'file=@ranger-hdfs-policies-apply.json' \
				  "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=hdfs"


		sleep 40


		## update zeppelin notebooks
		curl -sSL https://raw.githubusercontent.com/hortonworks-gallery/zeppelin-notebooks/master/update_all_notebooks.sh | sudo -E sh 
		host=$(hostname -f)

	  #update zeppelin configs by uncommenting admin user, enabling sessionManager/securityManager, switching from anon to authc
	  ${ambari_config_get} zeppelin-shiro-ini \
		| sed -e '1,4d' \
		-e "s/admin = admin, admin/admin = ${ambari_pass},admin/"  \
		-e "s/user1 = user1, role1, role2/ivana-eu-hr = ${ambari_pass}, admin/" \
		-e "s/user2 = user2, role3/compliance-admin = ${ambari_pass}, admin/" \
		-e "s/user3 = user3, role2/joe-analyst = ${ambari_pass}, admin/" \
		> /tmp/zeppelin-env.json

	  ${ambari_config_set}  zeppelin-shiro-ini /tmp/zeppelin-env.json
	  sleep 5
	  sudo curl -u admin:${ambari_pass} -H 'X-Requested-By: blah' -X POST -d "
{
   \"RequestInfo\":{
      \"command\":\"RESTART\",
      \"context\":\"Restart Zeppelin\",
      \"operation_level\":{
         \"level\":\"HOST\",
         \"cluster_name\":\"${cluster_name}\"
      }
   },
   \"Requests/resource_filters\":[
      {
         \"service_name\":\"ZEPPELIN\",
         \"component_name\":\"ZEPPELIN_MASTER\",
         \"hosts\":\"${host}\"
      }
   ]
}" http://localhost:8080/api/v1/clusters/${cluster_name}/requests  

	#kill any previous Hive/tez apps to clear queue
	for app in $(yarn application -list | awk '$2==hive && $3==TEZ && $6 == "ACCEPTED" || $6 == "RUNNING" { print $1 }')
	do 
		yarn application -kill  "$app"
	done


	cd ~/masterclass/ranger-atlas/HortoniaMunichSetup
	./01-atlas-import-classification.sh
	./02-atlas-import-entities.sh
	./03-update-servicedefs.sh
	./04-create-os-users.sh
	./05-create-hdfs-user-folders.sh
	./06-copy-data-to-hdfs.sh
	./07-create-hive-schema.sh

    fi
fi

echo "Done!"

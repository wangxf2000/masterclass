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
export enable_kerberos=${enable_kerberos:-true}      
export kdc_realm=${kdc_realm:-HWX.COM}      #KDC realm
export ambari_version="${ambari_version:-2.6.1.0}"   #Need Ambari 2.6.0+ to avoid Zeppelin BUG-92211



#internal vars
export ambari_password="${ambari_pass}"
export cluster_name=${stack}
export recommendation_strategy="ALWAYS_APPLY_DONT_OVERRIDE_CUSTOM_VALUES"
export install_ambari_server=true
export deploy=true

export host=$(hostname -f)
## overrides
#export ambari_stack_version=2.6
#export ambari_repo=https://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.5.0.3/ambari.repo

export install_ambari_server ambari_pass host_count ambari_services
export ambari_password cluster_name recommendation_strategy

########################################################################
########################################################################
## 
cd

yum makecache fast
yum -y -q install git epel-release ntp screen mysql-connector-java postgresql-jdbc jq python-argparse python-configobj ack
curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/extras/deploy/install-ambari-bootstrap.sh | bash


########################################################################
########################################################################
## tutorial users

#download hortonia scripts
cd /tmp
git clone https://github.com/abajwa-hw/masterclass  

cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./04-create-os-users.sh    

#also need anonymous user for kafka Ranger policy
useradd ANONYMOUS    


########################################################################
########################################################################
## 

#install MySql community rpm
sudo rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

#install Ambari
~/ambari-bootstrap/extras/deploy/prep-hosts.sh
~/ambari-bootstrap/ambari-bootstrap.sh

## Ambari Server specific tasks
if [ "${install_ambari_server}" = "true" ]; then

    sleep 30

    #Create users in Ambari before changing pass
    users="kate_hr ivanna_eu_hr joe_analyst sasha_eu_hr john_finance mark_bizdev jermy_contractor diane_csr log_monitor"
    groups="hr analyst us_employee eu_employee finance business_dev contractor csr etluser"
    ambari_url="http://localhost:8080/api/v1"
    
    for user in ${users}; do
      echo "adding user ${user} to Ambari"
      curl -u admin:admin -H "X-Requested-By: blah" -X POST -d "{\"Users/user_name\":\"${user}\",\"Users/password\":\"${ambari_pass}\",\"Users/active\":\"true\",\"Users/admin\":\"false\"}" ${ambari_url}/users 
    done 

    #create groups in Ambari
    for group in ${groups}; do
      curl -u admin:admin -H "X-Requested-By: blah" -X POST -d "{\"Groups/group_name\":\"${group}\"}" ${ambari_url}/groups
    done

    #HR group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"hr"}' ${ambari_url}/groups/hr/members
    

    #analyst group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"analyst"}' ${ambari_url}/groups/analyst/members

    #us_employee group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"kate_hr", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"joe_analyst", "MemberInfo/group_name":"us_employee"}' ${ambari_url}/groups/us_employee/members

    #eu_employee group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"ivanna_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"sasha_eu_hr", "MemberInfo/group_name":"eu_employee"}' ${ambari_url}/groups/eu_employee/members

    #finance group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"john_finance", "MemberInfo/group_name":"finance"}' ${ambari_url}/groups/finance/members

    #bizdev group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"mark_bizdev", "MemberInfo/group_name":"business_dev"}' ${ambari_url}/groups/business_dev/members

    #contractor group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"jermy_contractor", "MemberInfo/group_name":"contractor"}' ${ambari_url}/groups/contractor/members

    #csr group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"diane_csr", "MemberInfo/group_name":"csr"}' ${ambari_url}/groups/csr/members

    #csr group membership
    curl -u admin:admin -H "X-Requested-By: blah" -X POST -d '{"MemberInfo/user_name":"log_monitor", "MemberInfo/group_name":"etluser"}' ${ambari_url}/groups/etluser/members
        
    ## add admin user to postgres for other services, such as Ranger
    cd /tmp
    sudo -u postgres createuser -U postgres -d -e -E -l -r -s admin
    sudo -u postgres psql -c "ALTER USER admin PASSWORD 'BadPass#1'";
    printf "\nhost\tall\tall\t0.0.0.0/0\tmd5\n" >> /var/lib/pgsql/data/pg_hba.conf
    #systemctl restart postgresql
    service postgresql restart

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
        "hive.exec.compress.output": "true",
        "hive.merge.mapfiles": "true",
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
        "ranger-kafka-plugin-enabled" : "Yes",
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
        "ranger.audit.solr.zookeepers": "$(hostname -f):2181/infra-solr",
        "ranger.servicedef.enableDenyAndExceptionsInPolicies": "true"
    },
    "ranger-hive-audit" : {
        "xasecure.audit.is.enabled" : "true",
        "xasecure.audit.destination.hdfs" : "true",
        "xasecure.audit.destination.solr" : "true"
    }
  }
}
EOF

    sleep 40
    service ambari-server status
    curl -u admin:${ambari_pass} -i -H "X-Requested-By: blah" -X GET ${ambari_url}/hosts
    ./deploy-recommended-cluster.bash

    if [ "${deploy}" = "true" ]; then

        cd ~
        sleep 20
        source ~/ambari-bootstrap/extras/ambari_functions.sh
        ambari_configs
        ambari_wait_request_complete 1
        sleep 5
        
        #Needed due to BUG-91977: Blueprint bug in Ambari 2.6.0.0
        if ! nc localhost 6080 ; then
           echo "Ranger did not start. Restarting..."
   
           curl -u admin:${ambari_pass} -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start RANGER via REST"}, "Body": {"ServiceInfo": {"state": "STARTED"}}}' http://localhost:8080/api/v1/clusters/${cluster_name}/services/RANGER
           sleep 5
   
           echo "Starting all services..."
           curl -u admin:${ambari_pass} -i -H "X-Requested-By: blah" -X PUT -d  '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"'"${cluster_name}"'"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' http://localhost:8080/api/v1/clusters/${cluster_name}/services

           while ! echo exit | nc localhost 21000; do echo "waiting for services to start...."; sleep 10; done
           while ! echo exit | nc localhost 10000; do echo "waiting for hive to come up..."; sleep 10; done
           while ! echo exit | nc localhost 50111; do echo "waiting for hcat to come up..."; sleep 10; done           
        fi

        sleep 30

        
        #add groups to Hive views
        curl -u admin:${ambari_pass} -i -H "X-Requested-By: blah" -X PUT ${ambari_url}/views/HIVE/versions/1.5.0/instances/AUTO_HIVE_INSTANCE/privileges \
           --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'
        
        curl -u admin:${ambari_pass} -i -H 'X-Requested-By: blah' -X PUT ${ambari_url}/views/HIVE/versions/2.0.0/instances/AUTO_HIVE20_INSTANCE/privileges \
           --data '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"us_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"business_dev","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"eu_employee","principal_type":"GROUP"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]'

        #restart Atlas
       sudo curl -u admin:${ambari_pass} -H 'X-Requested-By: blah' -X POST -d "
{
   \"RequestInfo\":{
      \"command\":\"RESTART\",
      \"context\":\"Restart Atlas\",
      \"operation_level\":{
         \"level\":\"HOST\",
         \"cluster_name\":\"${cluster_name}\"
      }
   },
   \"Requests/resource_filters\":[
      {
         \"service_name\":\"ATLAS\",
         \"component_name\":\"ATLAS_SERVER\",
         \"hosts\":\"${host}\"
      }
   ]
}" http://localhost:8080/api/v1/clusters/${cluster_name}/requests  




        ## update zeppelin notebooks and upload to HDFS
        curl -sSL https://raw.githubusercontent.com/hortonworks-gallery/zeppelin-notebooks/master/update_all_notebooks.sh | sudo -E sh 
        sudo -u zeppelin hdfs dfs -rmr /user/zeppelin/notebook/*
        sudo -u zeppelin hdfs dfs -put /usr/hdp/current/zeppelin-server/notebook/* /user/zeppelin/notebook/

      #update zeppelin configs to include ivanna/joe/diane users
      /var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a get -c zeppelin-shiro-ini \
        | sed -e '1,2d' \
        -e "s/admin = admin, admin/admin = ${ambari_pass},admin/"  \
        -e "s/user1 = user1, role1, role2/ivanna_eu_hr = ${ambari_pass}, admin/" \
        -e "s/user2 = user2, role3/diane_csr = ${ambari_pass}, admin/" \
        -e "s/user3 = user3, role2/joe_analyst = ${ambari_pass}, admin/" \
        > /tmp/zeppelin-env.json


      /var/lib/ambari-server/resources/scripts/configs.py -u admin -p ${ambari_pass} --host localhost --port 8080 --cluster ${cluster_name} -a set -c zeppelin-shiro-ini -f /tmp/zeppelin-env.json
      sleep 5



      #restart Zeppelin
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


    while ! echo exit | nc localhost 21000; do echo "waiting for atlas to come up..."; sleep 10; done
    sleep 30

    # curl -u admin:${ambari_pass} -i -H 'X-Requested-By: blah' -X POST -d '{"RequestInfo": {"context" :"ATLAS Service Check","command":"ATLAS_SERVICE_CHECK"},"Requests/resource_filters":[{"service_name":"ATLAS"}]}' http://localhost:8080/api/v1/clusters/${cluster_name}/requests
    
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

  

    cd /tmp/masterclass/ranger-atlas/Scripts/
    # Needs to be done manually afterwards because Tag repo has to be manually created first          
    #echo "importing ranger Tag policies.."
    #< ranger-policies-tags.json jq '.policies[].service = "'${cluster_name}'_hive"' > ranger-policies-tags_apply.json
    #${ranger_curl} -X POST \
    #-H "Content-Type: multipart/form-data" \
    #-H "Content-Type: application/json" \
    #-F 'file=@ranger-policies-tags_apply.json' \
    #          "${ranger_url}/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType=tag"
                  
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
    sleep 40    
    
    cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
    ./01-atlas-import-classification.sh
    #./02-atlas-import-entities.sh      ## this gives 500 error so moving to end
    ./03-update-servicedefs.sh

            
    cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
    su hdfs -c ./05-create-hdfs-user-folders.sh
    su hdfs -c ./06-copy-data-to-hdfs.sh
    
    if [ "${enable_kerberos}" = true  ]; then
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
       fi
    
    #make sure Hive is up
    while ! echo exit | nc localhost 10000; do echo "waiting for hive to come up..."; sleep 10; done
    while ! echo exit | nc localhost 50111; do echo "waiting for hcat to come up..."; sleep 10; done

    sleep 30

    if [ "${enable_kerberos}" = true  ]; then
       kinit -kVt /etc/security/keytabs/rm.service.keytab rm/$(hostname -f)@${kdc_realm}
    fi

    #kill any previous Hive/tez apps to clear queue
    for app in $(yarn application -list | awk '$2==hive && $3==TEZ && $6 == "ACCEPTED" || $6 == "RUNNING" { print $1 }')
    do 
        yarn application -kill  "$app"
    done


    #import Hive data
    
    set +e
    cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
    if [ "${enable_kerberos}" = true  ]; then
       ./07-create-hive-schema-kerberos.sh
    else
       ./07-create-hive-schema.sh
    fi
    set -e

    #import Atlas entities 
    cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
    ./02-atlas-import-entities.sh
    # Need to do this twice due to bug: RANGER-1897 
    # second time, the notification is of type ENTITY_UPDATE which gets processed correctly
    ./02-atlas-import-entities.sh
    
                
    fi
fi

echo "Automated portion of setup is complete, next please create the tag repo in Ranger, associate with Hive and import tag policies"
echo "See https://github.com/abajwa-hw/masterclass/blob/master/ranger-atlas/README.md for more details"
echo "Once complete, see here for walk through of demo: https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html"
        

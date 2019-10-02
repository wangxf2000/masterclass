export ranger_password=${ranger_password:-admin123}
export atlas_pass=${atlas_pass:-admin}
export kdc_realm=${kdc_realm:-VPC.CLOUDERA.COM}
export cluster_name=${cluster_name:-cm}

yum install -y git jq
cd /tmp
git clone https://github.com/abajwa-hw/masterclass  
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
chmod +x *.sh
./04-create-os-users.sh  
#bug?
useradd rangerlookup




ranger_curl="curl -u admin:${ranger_password}"
ranger_url="http://localhost:6080/service"



${ranger_curl} -X POST -H "Content-Type: application/json" -H "Accept: application/json" ${ranger_url}/public/v2/api/roles  -d @- <<EOF
{
   "name":"Admins",
   "description":"",
   "users":[

   ],
   "groups":[
      {
         "name":"etl",
         "isAdmin":false
      }
   ],
   "roles":[

   ]
}
EOF



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


#Now **manually** import ranger policies


sudo -u hdfs hdfs dfs -mkdir -p /apps/hive/share/udfs/
sudo -u hdfs hdfs dfs -put /opt/cloudera/parcels/CDH/lib/hive/lib/hive-exec.jar /apps/hive/share/udfs/
sudo -u hdfs hdfs  dfs -chown -R hive:hadoop  /apps

#TODO change these files: rename hortonia
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
sudo -u hdfs ./05-create-hdfs-user-folders.sh
sudo -u hdfs ./06-copy-data-to-hdfs-dc.sh


sudo -u hive beeline  -n hive -f ./data/HiveSchema-dc.hsql
sudo -u hive beeline  -n hive -f ./data/TransSchema-dc.hsql



sed -i.bak "s/21000/31000/g" env_atlas.sh
sed -i.bak "s/localhost/$(hostname -f)/g" env_atlas.sh
sed -i.bak "s/ATLAS_PASS=admin/ATLAS_PASS=${atlas_pass}/g" env_atlas.sh

./01-atlas-import-classification.sh



./09-associate-entities-with-tags-dc.sh


echo "Creating users in KDC..."
kadmin.local -q "addprinc -randkey joe_analyst/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey kate_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey log_monitor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey diane_csr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey jermy_contractor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey mark_bizdev/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey john_finance/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey ivanna_eu_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "addprinc -randkey etl_user/$(hostname -f)@${kdc_realm}"


echo "Creating user keytabs..."
mkdir -p /etc/security/keytabs
cd /etc/security/keytabs
kadmin.local -q "xst -k joe_analyst.keytab joe_analyst/$(hostname -f)@${kdc_realm}"    
kadmin.local -q "xst -k log_monitor.keytab log_monitor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k diane_csr.keytab diane_csr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k jermy_contractor.keytab jermy_contractor/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k mark_bizdev.keytab mark_bizdev/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k john_finance.keytab john_finance/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k ivanna_eu_hr.keytab ivanna_eu_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k kate_hr.keytab kate_hr/$(hostname -f)@${kdc_realm}"
kadmin.local -q "xst -k etl_user.keytab etl_user/$(hostname -f)@${kdc_realm}" 
chmod +r *.keytab


-------------------------
#as joe
kinit -kt /etc/security/keytabs/joe_analyst.keytab joe_analyst/$(hostname -f)@VPC.CLOUDERA.COM
beeline

#masking
SELECT surname, streetaddress, country, age, password, nationalid, ccnumber, mrn, birthday FROM worldwidebank.us_customers limit 5

#prohibition
select zipcode, insuranceid, bloodtype from worldwidebank.ww_customers

#tag based deny (EXPIRED_ON)
select fed_tax from finance.tax_2015

#tag based deny (DATA_QUALITY)
select * from cost_savings.claim_savings limit 5


-------------------------

WORKAROUNDS:

-----------------------------
CM > Hive  >  ranger-hive-security.xml
ranger.plugin.hive.policy.rest.supports.policy.deltas=false 
ranger.plugin.hive.policy.rest.supports.tags.deltas=false


CM > Impala  >  ranger-impala-security.xm
ranger.plugin.hive.policy.rest.supports.policy.deltas=false 
ranger.plugin.hive.policy.rest.supports.tags.deltas=false

   
-----------------------------
WIP
KnoxUI (knoxui/knoxui) > sandbox > 

   <service>
      <role>ZEPPELINUI</role>
      <url>http://sv-worldwidebank-1.vpc.cloudera.com:8885</url>
   </service>
   <service>
      <role>ZEPPELINWS</role>
      <url>ws://sv-worldwidebank-1.vpc.cloudera.com:8885</url>
   </service>
   

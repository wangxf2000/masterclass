atlas_host=${atlas_host:-$(hostname -f)}
cluster_name=${cluster_name:-hdp}

atlas_curl="curl -u admin:admin"
atlas_url="http://${atlas_host}:21000/api/atlas"

##Tagging Hive Tables

#fetch guid for table hortoniabank.eu_countries@${cluster_name}
guid=$(curl  -u admin:admin  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_table?attr:qualifiedName=hortoniabank.eu_countries@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add REFERENCE_DATA tag
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"REFERENCE_DATA","values":{}}'


#fetch guid for table consent_master.eu_countries@${cluster_name}
guid=$(curl  -u admin:admin  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_table?attr:qualifiedName=consent_master.eu_countries@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add REFERENCE_DATA tag
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"REFERENCE_DATA","values":{}}'



#fetch guid for table consent_master.consent_data
guid=$(curl  -u admin:admin  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_table?attr:qualifiedName=consent_master.consent_data@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add REFERENCE_DATA tag
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"REFERENCE_DATA","values":{}}'


#fetch guid for table consent_master.consent_data_trans
guid=$(curl  -u admin:admin  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_table?attr:qualifiedName=consent_master.consent_data_trans@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add REFERENCE_DATA tag
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"REFERENCE_DATA","values":{}}'



	
## tag hive tables with attribute


#fetch guid for table cost_savings.claim_savings@${cluster_name}
guid=$(curl  -u admin:admin  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_table?attr:qualifiedName=cost_savings.claim_savings@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add DATA_QUALITY tag with score=0.51
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"DATA_QUALITY", "values":{"score": "0.51"}}'


#${atlas_curl} -H 'Accept: application/json' -H 'Content-Type: application/json' ${atlas_url}/v2/entity/guid/$guid | python -m json.tool | grep score

${atlas_curl} -H 'Accept: application/json' -H 'Content-Type: application/json' ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.mrn@h11223344 | jq '.entity.guid
"95848ce4-2c15-49da-a04e-24d3a1dcac58"

## Tagging Hive columns

#fetch guid for table claim.provider_summary.providername@${cluster_name}
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=claim.provider_summary.providername@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add VENDOR_PII tag with type=vendor
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"VENDOR_PII", "values":{"type": "vendor"}}'


#fetch guid for  finance.tax_2015.ssn
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=finance.tax_2015.ssn@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add FINANCE_PII tag with type=finance
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"FINANCE_PII", "values":{"type": "finance"}}'


#fetch guid for finance.tax_2015.fed_tax
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=finance.tax_2015.fed_tax@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add EXPIRES_ON tag with expiry_date=2016
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"EXPIRES_ON", "values":{"expiry_date": "2016-12-31T00:00:00.000Z"}}'


#fetch guid for hortoniabank.us_customers.ccnumber
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.ccnumber@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add PII tag with type=ccn
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"PII", "values":{"type": "ccn"}}'


#fetch guid for hortoniabank.us_customers.mrn
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.mrn@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add PII tag with type=MRN
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"PII", "values":{"type": "MRN"}}'


#fetch guid for hortoniabank.us_customers.nationalid
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.nationalid@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add PII tag with type=MRN
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"PII", "values":{"type": "ssn"}}'



#fetch guid for hortoniabank.us_customers.password
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.password@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add PII tag with type=Password
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"PII", "values":{"type": "Password"}}'


#fetch guid for hortoniabank.us_customers.emailaddress
guid=$(${atlas_curl}  ${atlas_url}/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=hortoniabank.us_customers.emailaddress@${cluster_name} | jq '.entity.guid'  | tr -d '"')

#add PII tag with type=Email
${atlas_curl} ${atlas_url}/entities/${guid}/traits \
-X POST -H 'Content-Type: application/json' \
--data-binary '{"jsonClass":"org.apache.atlas.typesystem.json.InstanceSerialization$_Struct","typeName":"PII", "values":{"type": "Email"}}'


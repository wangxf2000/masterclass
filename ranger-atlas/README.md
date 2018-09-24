# Ranger Atlas (Hortonia Bank)

## Demo overview

Demo overview can be found [here](https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html) 

## Versions tested

Tested with:
- [x] HDP 3.0.1 / Ambari 2.7.0.1
- [x] HDP 3.0.0 / Ambari 2.7.0.0


## Fresh install of HDP plus Hortoniabank demo

- Pre-reqs:
  - Launch a single vanilla Centos/RHEL 7.x VM (e.g. on local VM or openstack or cloud provider of choice) 
  - The VM should not already have any Ambari or HDP components installed (e.g. do NOT run script on HDP sandbox)
  - The VM requires 4 vcpus and ~32 GB RAM once all services are running and you execute a query, so m3.2xlarge size is recommended
  
- Login as root, (optionally [override any parameters](https://github.com/abajwa-hw/masterclass/blob/master/ranger-atlas/setup.sh#L14-L30)) and run setup.sh as below:
```
sudo su
cd
export enable_knox_sso_proxy=true
curl -sSL https://raw.githubusercontent.com/abajwa-hw/masterclass/master/ranger-atlas/setup.sh | sudo -E bash  
```

- This will run for about 30min. 


## Login details 

- Knox SSO crendentials: admin/BadPass#1
- Login urls:
  - https://yourhostname:8443/gateway/ui/ambari
  - https://yourhostname:8443/gateway/ui/ranger
  - https://yourhostname:8443/gateway/ui/atlas
  - https://yourhostname:8443/gateway/ui/yarn
  - https://yourhostname:8443/gateway/ui/yarnuiv2
  - https://yourhostname:8443/gateway/manager/admin-ui/
  - https://yourhostname:8443/gateway/ui/hdfs/?host=http://demo.hortonworks.com:50070
  - https://yourhostname:8443/gateway/ui/zeppelin/ 
  - https://yourhostname:8443/gateway/ui/nifi/ 



  ## Demo walkthrough
  
  - Detailed walkthrough of demo steps available [here](https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html)

  ## Other things to try
- Simulate users trying to randomly access Hive tables to generate more interesting audits
```
/tmp/masterclass/ranger-atlas/HortoniaMunichSetup/audit_simulator.sh
```

- Install Ranger Audits Banana dashboard to visuaize audits


  ## How does it work?
- The script basically:
  - uses [Ambari bootstrap](https://github.com/seanorama/ambari-bootstrap) to install Ambari, generate a blueprint and deploy HDP cluster that includes Ranger/Atlas
  - uses Ranger APIs to import service defs, create tag repo and import policies for HDFS/Hive/Hbase/Kafka
  - import tags into Atlas
  - imports sample Hive data (which also creates HDFS/Hive entities in Atlas)
  - [uses Atlas APIs to associate tags with Hive/Kafka/Hbase/HDFS entities](https://community.hortonworks.com/articles/189615/atlas-how-to-automate-associating-tagsclassificati.html)
  - import sample Nifi flow that reads tweets into HDFS
  - enables kerberos
  - enables SSO for Ambari/Ranger/Atlas/Zeppelin


  ## Troubleshooting

- While running script, beeline stuck at analyzing tables?
  - Check the YARN UI on port 8088: there is likely one job in RUNNING and one in ACCEPTED state. Kinit and kill the one in RUNNING state:
```
kinit -kVt /etc/security/keytabs/rm.service.keytab rm/$(hostname -f)@HWX.COM
yarn application -kill <application_id>
```

- Ranger audits not picking up tags?
  - Restart Ranger tagsync process via Ambari and re-try

- Interactive Hive/LLAP not starting? 
  - Ambari shows `The cluster is not started yet (InvalidACL); will retry`
  - Regenrate keytabs via Ambari and restart services. See [here](https://community.hortonworks.com/articles/125751/iop-v-425-to-hdp-v-26x-hsi-start-fails-with-error.html) for more info
  
- Zeppelin complains of `Prefix not found.`?
  - Zeppelin service was not restarted after enabled Interactive Hive. Restart Zeppelin via Ambari


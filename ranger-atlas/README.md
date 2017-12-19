# Ranger Atlas (Hortonia Bank)

## Demo overview

Demo overview can be found [here](https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html) 

## Setup - part 1

- Pre-reqs:
  - Launch a single vanilla Centos/RHEL 7.x VM (e.g. on local VM or openstack or cloud provider of choice) 
  - The VM should not already have any Ambari or HDP components installed (e.g. do NOT run script on HDP sandbox)
  - The VM requires 4 vcpus and ~17-18 GB RAM once all services are running and you execute a query, so m3.2xlarge size is recommended
  
- Login as root and run setup.sh as below:
```
sudo su
nohup curl -sSL https://raw.githubusercontent.com/abajwa-hw/masterclass/master/ranger-atlas/setup.sh | sudo -E bash  >/var/log/hdp_setup.log 2>&1 &
tail -f /var/log/hdp_setup.log
```

#### Troubleshooting 

- In case the script exits pre-maturely (after enabling kerberos but before creating Hive DBs and tables), just manually run below scripts to complete the setup.
```
sudo su
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup
./07-create-hive-schema-kerberos.sh

#import atlas entities
./02-atlas-import-entities.sh
# Need to do this twice due to bug: RANGER-1897
# second time, the notification is of type ENTITY_UPDATE which gets processed correctly
./02-atlas-import-entities.sh
```

Login details 
- Ambari port: 8080 login: admin/BadPass#1
- Ranger port: 6080 login: admin/admin
- Atlas port: 21000 login: admin/admin
- Zeppelin port: 9995 login: ivanna_eu_hr/BadPass#1 OR joe_analyst/BadPass#1 

## Setup - part 2

- Once script is complete, there are manual steps required to create tag service, associate with Hive service and import tag based policies 

- [ ] Create Tag Service
  - Open Ranger 
  - Click Access Manager -> Tag Based Policies
  - Click the + icon and create a service named 'tags'
    - ![](./media/screenshot-ranger-add-tag-service.png)

- [ ] Configure Hive for Tag based Policies
  - Open Ranger
  - Click Access Manager -> Resources Based Policies
  - Click ‘edit/pen’ icon next to the service’
  - [ ] Set ‘Select Tag Service’ to ‘tags’
    - ![](./media/screenshot-ranger-configure-hive-tag-service.png)

- [ ] Import tag based policies in Ranger
  - Download tag policies to your laptop from [here](./Scripts/ranger-policies-tags.json) (Make sure to download the 'Raw' file)
  - Open Ranger
  - Access Manager -> Tag based Policies
  - Click the import icon to import policies
  - Make sure to select the 'Override Policy' checkbox
  - Wait 30s
  

- [ ] Login to Zeppelin as end users (ivanna_eu_hr and joe_analyst) and run through demo Hive queries one by one in the prebuilt notebooks

  ## Demo walkthrough
  
  - Detailed walkthrough of demo steps available [here](https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html)

# Ranger Atlas (Hortonia Bank)

## Setup - part 1

- Launch a single vanilla Centos/RHEL 7.x VM (e.g. on local VM or cloud provider of choice or...) and run setup.sh
  - This should not already have any Ambari or HDP components installed (e.g. do NOT run on HDP sandbox)
```
sudo su
nohup curl -sSL https://raw.githubusercontent.com/abajwa-hw/masterclass/master/ranger-atlas/setup.sh | sudo -E bash  >/var/log/hdp_setup.log 2>&1 &
tail -f /var/log/hdp_setup.log
```
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
  - Download tag policies to your laptop from [here](./Scripts/ranger-policies-tags.json)
  - Open Ranger
  - Access Manager -> Tag based Policies
  - Click the import icon to import policies
  - Make sure to select the 'Override Policy' checkbox
  
- [ ] Import hdfs/hive entities into Atlas
```
cd /tmp/masterclass/ranger-atlas/HortoniaMunichSetup/
./02-atlas-import-entities.sh
```

  ## Demo walk through
  
  - Detailed walkthrough of demo steps available [here](https://community.hortonworks.com/articles/151939/hdp-securitygovernance-demo-kit.html)

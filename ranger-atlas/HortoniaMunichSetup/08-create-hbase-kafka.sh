echo "Creating Hbase tables..."
kinit -kt /etc/security/keytabs/hbase.service.keytab hbase/$(hostname -f)@HWX.COM

cat << EOF > /tmp/hbase.sh
create 'T_PRIVATE','cf1','cf2'
create 'T_FOREX','cf1','cf2'
list
exit
EOF


hbase shell /tmp/hbase.sh

echo "Creating Kafka topics..."

kinit -kt /etc/security/keytabs/log_monitor.keytab log_monitor/$(hostname -f)@HWX.COM


/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper $(hostname -f):2181 --replication-factor 1 --partition 1 --topic FOREX
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper $(hostname -f):2181 --replication-factor 1 --partition 1 --topic PRIVATE
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper $(hostname -f):2181 --list




cat << EOF > /tmp/forex.csv
UTC time,EUR/USD
2018-03-26T09:00:00Z,1.231
2018-03-26T10:00:00Z,1.232
2018-03-26T11:00:00Z,1.233
2018-03-26T12:00:00Z,1.231
2018-03-26T13:00:00Z,1.234
2018-03-26T14:00:00Z,1.230
2018-03-26T15:00:00Z,1.232
EOF


cat << EOF > /tmp/private.csv
123-45-67890
321-54-09876
800-60-32982
333-22-09873
222-98-21816
111-44-91021
999-11-56101
098-45-10927
EOF


echo "Publishing test data to Kafka topics..."
sleep 5

/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh --security-protocol SASL_PLAINTEXT --broker-list $(hostname -f):6667 --topic PRIVATE < /tmp/private.csv
/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh --security-protocol SASL_PLAINTEXT --broker-list $(hostname -f):6667 --topic FOREX <  /tmp/forex.csv


echo "Allowing Zeppelin to kinit as joe/ivanna.."
chown joe_analyst:hadoop /etc/security/keytabs/joe_analyst.keytab
chmod g+r /etc/security/keytabs/joe_analyst.keytab

chown ivanna_eu_hr:hadoop /etc/security/keytabs/ivanna_eu_hr.keytab
chmod g+r /etc/security/keytabs/ivanna_eu_hr.keytab


echo "Copying data to /hive_data dir in HDFS..."
hdfs dfs -mkdir -p /hive_data/claim/
hdfs dfs -mkdir -p /hive_data/cost_savings/
hdfs dfs -mkdir -p /hive_data/finance/tax_2009/
hdfs dfs -mkdir -p /hive_data/finance/tax_2010/
hdfs dfs -mkdir -p /hive_data/finance/tax_2015/
hdfs dfs -mkdir -p /hive_data/hortoniabank/eu_countries/
hdfs dfs -mkdir -p /hive_data/hortoniabank/us_customers/
hdfs dfs -mkdir -p /hive_data/hortoniabank/ww_customers/

hdfs dfs -put data/claims_provider_summary_data.csv /hive_data/claim/
hdfs dfs -put data/claim-savings.csv                /hive_data/cost_savings/
hdfs dfs -put data/tax_2009.csv                     /hive_data/finance/tax_2009/
hdfs dfs -put data/tax_2010.csv                     /hive_data/finance/tax_2010/
hdfs dfs -put data/tax_2015.csv                     /hive_data/finance/tax_2015/
hdfs dfs -put data/eu_countries.csv                 /hive_data/hortoniabank/eu_countries/
hdfs dfs -put data/us_customers_data.csv            /hive_data/hortoniabank/us_customers/
hdfs dfs -put data/ww_customers_data.csv            /hive_data/hortoniabank/ww_customers/

hdfs dfs -chown -R hive:hive /hive_data/


cat << EOF > /tmp/hbase.sh
create 'T_PRIVATE','cf1','cf2'
create 'T_FOREX','cf1','cf2'
list
EOF

echo "Creating Hbase tables..."
sudo -u hbase hbase shell /tmp/hbase.sh

echo "Creating Kafka topics..."
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

/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh --broker-list $(hostname -f):6667 --topic PRIVATE < /tmp/forex.csv
/usr/hdp/current/kafka-broker/bin/kafka-console-producer.sh --broker-list $(hostname -f):6667 --topic FOREX < /tmp/private.csv



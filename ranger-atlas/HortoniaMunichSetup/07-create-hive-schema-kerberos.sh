export kdc_realm=${kdc_realm:-HWX.COM}

kinit -kVt /etc/security/keytabs/hive.service.keytab hive/$(hostname -f)@${kdc_realm}
beeline -u "jdbc:hive2://localhost:10000/default;principal=hive/$(hostname -f)@${kdc_realm}" -f /tmp/masterclass/ranger-atlas/HortoniaMunichSetup/data/HiveSchema.hsql
kdestroy

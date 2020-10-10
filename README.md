# Auto Update Haproxy for Aurora Cluster events
Shell script to use as Cron job to monitor Aurora cluster and update HAproxy listener/endpoints
Includes functionality to maintain and build configuration for more than 1 cluster 

#Other Files in the Repo
  Apart from the 2 versions of the monitor_aurora korn shell reference script , included are sample configuration files for 
1. systemd unit file for HA-Proxy service (haproxy-2.0.14.service)
2. systemd unit file for pgbouncer (pgbouncer-1.13.service)
3. sample xinetd cofiguration for use with an external command (postgreschk_service_xinetd)
4. sample external check command script for HA-Proxy (postgreschk_service_xinetd , postgreschk )
5. directory with staging and registry which is a dependency for the script (monitor_haproxy)
6. IAM role sample json for the script to call rds apis (iam_ec2_role.json)


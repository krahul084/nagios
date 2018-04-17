#!/usr/bin/python
import os,sys

service = sys.argv[1]

check_service = "systemctl status %s |grep -i 'Active'" % service

service_status = os.popen(check_service).readline().split()[1]

if service_status == "active":
    print "OK-%s is Active" % service
    sys.exit(0)
elif service_status == "inactive":
    print "CRITICAL-%s is Inactive" % service
    sys.exit(2)
else:
    print "UNKNOWN-%s is Unknown" % service
    sys.exit(3)


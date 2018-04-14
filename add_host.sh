#Script to Add Nagios Hosts
read -p "Please enter the hostname:" host
read -p "Please enter the IP Address:" IP_ADDR
echo "Please verify the details entered:"
echo -e "HOSTNAME\t=\t$host"
echo  -e "IP Address\t=\t$IP_ADDR"
read -p "Do you wish to proceed with the details[Y/y]" confirmation
if [ $confirmation == "y" ] || [ $confirmation == "Y" ]; then
  echo -e "Connecting and Installing client on remote host,\n Please enter credentials to proceed further!"
  scp -rp /tmp/nagios/nrpe_client/nrpe_instal.sh user@$IP_ADDR:/tmp/ && echo "Transfer of script complete" && ssh -t user@$IP_ADDR 'sudo /tmp/nrpe_instal.sh'

  if [ $? -eq 0 ]; then
    echo "Now configuring the Nagios Client on Server"
    sed "/yourhost$/s/yourhost/$host/"  /usr/local/nagios/etc/servers/default > /usr/local/nagios/etc/servers/$host.cfg && sed -i  "/IP_ADDR$/s/IP_ADDR/$IP_ADDR/" /usr/local/nagios/etc/servers/$host.cfg 
    systemctl reload nagios.service && echo "Host-$host Added to Nagios Monitoring!" && exit 3
    echo "Adding Failed" && exit 2
  else
    echo "NRPE Client Configuration Failed, Please troubleshoot on client server!"
    exit 4
  fi
else
  echo "You have chosen not to take any action, quitting script execution"
  exit 1
fi



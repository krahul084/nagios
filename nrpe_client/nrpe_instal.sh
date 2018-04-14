#!/bin/bash
#Script to install and configure nrpe in nagios client
nrpe_packages=( epel-release nrpe nagios-plugins-all )
services=( nrpe.service )
yum install -y pv >> /dev/null
#Function to install packages
install_packages() {
    packages=("$@")
    for i in "${packages[@]}"; do
      echo "Installing $i"
      is_installed=$(yum info $i| grep Repo | awk '{print $3 }' )
      if [ "$is_installed" != "installed" ]; then
          yum install -y "$i" | pv > /dev/null
          install_stat=$?
          if [ "$install_stat" -eq 0 ]; then
              echo "$i is installed"
              sleep 1
          else
              echo "Installation of $i failed!, Please take a moment to troubleshoot exiting with exit code-90"
              exit 90
          fi
      fi
    done
}

#Function to add the nagios server for host 
add_nagios_server() {
    echo "Setting up Nagios Server for the host"; sleep 3
    sed -i '/^allowed/s/::1/54.218.75.204/' /etc/nagios/nrpe.cfg && echo "Setup Complete!"
    
}

#Starting the NRPE service
start_nrpe() {
    echo "Starting and Enabling NRPE on boot"
    systemctl start nrpe.service
    systemctl enable nrpe.service
}

#Checking the NRPE service 
check_services() {
    services=("$@")
    for serv in ${services[@]}; do
      echo "Checking Service $serv"
      is_running=$(systemctl status $serv |grep -i active | awk '{print $3}')
      if [ "$is_running" == "(running)" ]; then
        echo "$serv is running, Proceeding with further configuration"
        sleep 1
      else
         echo "$serv dead, please troubleshoot to proceed further exiting with exit code-91"
         exit 91
      fi
    done
}
#Staring the Script execution here

install_packages ${nrpe_packages[@]} &&  add_nagios_server && start_nrpe && check_services ${services[@]} && echo "NRPE Client Setup Complete!"

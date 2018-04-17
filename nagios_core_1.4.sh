#!/bin/bash
#script to install nagios core on centos 7
nagios_install_date=$(date +%m/%d_%T)
install_log_dir="/tmp/nagios_install/$nagios_install_date"
lamp_packages=( "httpd" "mariadb-server" "mariadb" "php" "php-mysql" "php-fpm" "elinks" )
build_dependencies=( gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel xinetd unzip )
lamp_services=( httpd mariadb )
nagios_services=( httpd nagios )
#script_utils=( pv dialog )
mkdir -p $install_log_dir
yum install -y pv >> $install_log_dir/nag_core_config_log 2> /dev/null

#Function to install the prerequisite packages
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

start_lamp() {
    systemctl start httpd.service
    systemctl enable httpd.service
    systemctl start mariadb
    systemctl restart httpd.service
}

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
    
nagios_user_config() {
    useradd nagios 2> /dev/null
    groupadd nagcmd 2> /dev/null
    usermod -a -G nagcmd nagios
    usermod -G nagcmd apache
    group_check_nagios=$(groups nagios | awk '{print $4}')
    group_check_apache=$(groups apache | awk '{print $4}')
    if [ $group_check_nagios == "nagcmd" ] && [ $group_check_apache == "nagcmd" ]; then
      echo "User Configuration for Nagios and Apache configuration completed!"
      sleep 1
    else
      echo "Problem with user configuration, Please troubleshoot exiting with exit code-92!"
      sleep 1
      exit 92
    fi
}

#Installing and Configuring Nagios Core
install_nagios_core() {
  core_download_url="https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.1.1.tar.gz"
  core_package="nagios-4.1.1.tar.gz"
  config_elements=( "commandmode" "init" "config" "webconf" )
  
  cd ~
  curl -L -O $core_download_url >> $install_log_dir/nag_core_config_log
  tar xvf $core_package >> $install_log_dir/nag_core_config_log
  cd nagios-*
  if [ $? -eq 0 ]; then
      echo "Configuring the Nagios-core install now"
      sleep 4
      ./configure --with-command-group=nagcmd >> $install_log_dir/nag_core_config_log
      echo "Please review the base configuration to proceed with the final compile"
      grep -A23 "^*** Configuration" $install_log_dir/nag_core_config_log
      sleep 4
      read -p "Please confirm to compile the above configuration(Y/N)" confirmation
      echo "Processing Compile it may take 5 minutes to complete!"
      if [ $confirmation == 'Y' ] || [ $confirmation == 'y' ]; then
      #Add a review option for proceeding with Compile

          make all |grep -i "*** Compile finished ***"
          if [ $? -eq 0 ]; then
	      make install >> $install_log_dir/nag_core_config_log
          else
              echo "make install failed"
              exit 201
          fi
          for config in ${config_elements[@]}; do
              echo "Configuring-$config"
              make install-$config >> $install_log_dir/nag_core_config_log
              if [ $? -eq 0 ]; then
                echo "***$config Complete***"
              else 
                echo "Please refer the installation log $install_log_dir/nag_core_config_log for troubleshooting"
                exit 95
              fi
          done
      else
          echo "Please reconfigure Nagios-Core! Now terminating script executing!"
          exit 96
      fi
  else
      echo "Package retrieval unsuccessful,exiting script execution"
      exit 97
  fi
}
install_plugins() {
    plugin_url="http://nagios-plugins.org/download/nagios-plugins-2.1.1.tar.gz"
    plugin_package="nagios-plugins-2.1.1.tar.gz"
    curl -L -O $plugin_url >> $install_log_dir/nrpe_plugin_log 
    tar xvf $plugin_package >> $install_log_dir/nrpe_plugin_log
    cd nagios-plugins-*
    if [ $? -eq 0 ]; then
        echo "Now Configuring the nagios-plugins, it may take 3 minutes"
        ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl >> $install_log_dir/nrpe_plugin_log 2> /dev/null
        for i in  "make" "make install"; do
          if [ $? -eq 0 ]; then
            $i >> $install_log_dir/nrpe_plugin_log 2> /dev/null
            echo " ****Execution of $i complete**** "
          else
            echo "Make of $i Failed!"
            exit 203
          fi
        done
        echo "Installation and Configuration of Plugins successful!" ; sleep 3
    fi
}

install_nrpe() {
    nrpe_url="http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz"  
    nrpe_package="nrpe-2.15.tar.gz"
    nrpe_make=( "all" "install" "install-xinetd" "install-daemon-config" )
 
    cd ~
    curl -L -O $nrpe_url >>  $install_log_dir/nrpe_config_log
    tar xvf $nrpe_package >> $install_log_dir/nrpe_config_log
    cd nrpe-*
    if [ $? -eq 0 ]; then
        echo "Configuring NRPE now"
        ./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu  >>  $install_log_dir/nrpe_config_log 2> /dev/null

        for comm in ${nrpe_make[@]}; do
          if [ $? -eq 0 ]; then  
            make $comm >> $install_log_dir/nrpe_config_log
            echo "Execution of make-$comm success!"
          else
            echo "Compile of NRPE failed!Exiting"
            exit 102
          fi
        done
    else
        "NRPE package retrieval failed"
        exit 103
    fi
    service xinetd restart >>  $install_log_dir/nrpe_config_log 2> /dev/null
    sleep 3
    echo "Installation of NRPE successful proceeding with nrpe configuration!"

    sed -i '/^#cfg_dir.*servers$/s/^#//' /usr/local/nagios/etc/nagios.cfg

    mkdir  /usr/local/nagios/etc/servers 2>  $install_log_dir/nrpe_config_log &&cp -rp nrpe_install/default /usr/local/nagios/etc/servers/
    check_nrpe=$(grep "nrpe$" /usr/local/nagios/etc/objects/commands.cfg |awk '{print $2}')
    if [ "$check_nrpe" != "check_nrpe" ]; then
        {
                  echo -e "define command{"
                  echo -e "\tcommand_name check_nrpe"
                  echo -e "\tcommand_line \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c \$ARG1$\n}"
                
        } >> /usr/local/nagios/etc/objects/commands.cfg
    fi

    echo "Please set the Nagios Web Console password:"
    sleep 3
    sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
    systemctl daemon-reload
    systemctl start nagios.service
    systemctl restart httpd.service
    chkconfig nagios on
    systemctl restart nagios.service
    systemctl restart httpd.service
}

#Checking and installing the prereqs
install_packages ${lamp_packages[@]}
install_packages ${build_dependencies[@]}


#Starting the LAMP services
start_lamp

#Checking the LAMP STARTUP
check_services ${lamp_services[@]}

#Nagios and Apache user configuration
nagios_user_config

if [ $? -eq 0 ]; then
  install_nagios_core
  verify_nagios_core=$(/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg |grep "Things look okay" | awk '{print $3}')
  if [ $verify_nagios_core == 'okay' ]; then
    install_plugins
    install_nrpe
    check_services ${nagios_services[@]}
  else
    echo "NRPE configuration Failed!,Please troubleshoot!"
  fi
else 
  echo "Prerequisites not setup properly"
  exit 98
fi





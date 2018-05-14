#! /bin/bash
# The LAMP and LNMP install script.

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

ipaddr=$(ip addr |egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' |egrep -v '^127' |head -n 1)
# color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# mysql
mysql_location=/usr/local/mysql
mysql_data_dir=/data/mysql
mysql=(
MySQL-5.5
MySQL-5.6
MySQL-5.7
MySQL-8.0
)

# apache
apache_location=/usr/local/apache24

# php version
php_location=/usr/local/php7
php=(
php-7.2
php-7.1
php-7.0
php-5.6
)

# nginx
nginx_location=/usr/local/nginx

# php-fpm
php_fpm_location=/usr/local/php-fpm

# website directory
web_root=/data/www

blank_line(){
    cat<<EOF





EOF
}

print_info(){
    clear
    cat<<EOF
+---------------------------------------------------------------------------+
|                                                                           |
|        Info:      The LAMP and LNMP install script.                       |
|        Author:    v.A1711_HW                                              |
|        Eamil      a1711_hw@xl78693.com                                    |
|        Blog:      https://blog.xl78693.com                                |
|                                                                           |
+---------------------------------------------------------------------------+
EOF
}

install_info(){
    blank_line
    echo -e "[${green}Info!${plain}] Start install ${1} server."
    sleep 2
}

tar_info(){
    echo
    echo -e "[${green}Info!${plain}] Decompressing ${1}.tar.gz"
    if [ ! -s ${1} ];then
        tar zxf ${1}.tar.gz
    else
        echo
        echo -e "[${yellow}Warning!${plain}] ${1} directory already exists."
    fi
}

complete_info(){
    echo
    echo -e "[${green}Info!${plain}] The ${1} server install success.${plain}"
}

uninstall_info(){
    echo
    echo -e "[${green}Info!${plain} The ${1} uninstall success!]"
}

check_ok(){
    if [ $? -ne 0 ];then
        echo
        echo -e "[${red}Error!${plain}] ${1} ${2} failed!"
        exit 1
    fi
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

yum_deppak(){
    if ! rpm -qa|grep -q "^${1}"
    then
        yum install -y ${1}
        check_ok ${1} install
    else
        echo
        echo -e "[${yellow}Warning!${plain}] ${1} already installed."
    fi
}

install_deppak(){
    blank_line
    echo -e "[${green}Info!${plain}] The relevant base package is being installed." 
    sleep 1
    for dep in epel-release wget psmisc vim-enhanced tar unzip make net-tools gettext gcc automake asciidoc xmlto libev-devel git c-ares-devel expat-devel openssl
    do
        yum_deppak ${dep}
    done
}

add_firewalld(){
    if ps -ef |grep -q firewalld && ! firewall-cmd --list-service |grep -q 'http\|https'
    then
        firewall-cmd --zone=public --permanent --add-service=http
        firewall-cmd --zone=public --permanent --add-service=https
        firewall-cmd --reload
    fi
}

get_mysql_ver(){
    while true
    do
        echo
        echo -e "Please select stream mysql version:"
        for ((i=1;i<=${#mysql[@]};i++ )); do
            hint="${mysql[$i-1]}"
            echo -e "${hint}"
        done
        read -p "Which mysql you'd select(Default: ${mysql[0]}):" mysql_pick
        [ -z "${mysql_pick}" ] && mysql_pick=1
        # Clear the return value of the previous step.
        expr ${mysql_pick} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo
            echo -e "[${red}Error!${plain}] Please enter a number."
            continue
        fi
        if [[ "${mysql_pick}" -lt 1 || "${mysql_pick}" -gt ${#mysql[@]} ]]; then
            echo
            echo -e "[${red}Error!${plain}] Please enter a number between 1 and ${#mysql[@]}"
            continue
        fi
        mysql_ver=${mysql[$mysql_pick-1]}
        echo
        echo "mysql version = ${mysql_ver}"
        break
    done
    mysql_last_ver=$(wget --no-check-certificate -qO- https://mirrors.tuna.tsinghua.edu.cn/mysql/downloads/${mysql_ver}/ |egrep -o '"mysql-[0-9].*[0-9]-linux-glibc.*-x86_64.tar.gz"'|awk -F '"' '{print $2}'|sort -nr|head -1|awk -F '.tar' '{print $1}')
    if [ -z ${mysql_last_ver} ];then
        echo
        echo -e "[${red}Error!${plain}] Get mysql version failed"
        exit 1
    fi
    mysql_link="https://mirrors.tuna.tsinghua.edu.cn/mysql/downloads/${mysql_ver}/${mysql_last_ver}.tar.gz"
}

get_apache_ver(){
    apr_ver=$(wget --no-check-certificate -qO- http://mirrors.gigenet.com/apache/apr/ |egrep -o '"apr-[0-9]{1,}.*.tar.gz"'|awk -F '"' '{print $2}'|awk -F '.tar' '{print $1}')

    apr_util_ver=$(wget --no-check-certificate -qO- http://mirrors.gigenet.com/apache/apr/ |egrep -o '"apr-util-.*.tar.gz"'|awk -F '"' '{print $2}'|awk -F '.tar' '{print $1}')

    httpd_ver=$(wget -qO-  http://mirrors.gigenet.com/apache/httpd |grep 'httpd-.*.tar.gz'|awk -F '"' '{print $8}'|sort -nr|head -1|awk -F '.tar' '{print $1}')
    if  [ -z ${apr_ver} ] && [ -z ${apr-util_ver} ] && [ -z ${httpd_ver} ];then
        echo
        echo -e "[${red}Error!${plain}] Get apache version failed"
        exit 1
    fi
    httpd_link="http://mirrors.gigenet.com/apache/httpd/${httpd_ver}.tar.gz"
    apr_link="http://mirrors.gigenet.com/apache/apr/${apr_ver}.tar.gz"
    apr_util_link="http://mirrors.gigenet.com/apache/apr/${apr_util_ver}.tar.gz"
}

get_php_ver(){
    while true
    do
        echo
        echo -e "Please select stream php version:"
        for ((i=1;i<=${#php[@]};i++ )); do
            hint="${php[$i-1]}"
            echo -e "${hint}"
        done
        read -p "Which php you'd select(Default: ${php[0]}):" php_pick
        [ -z "${php_pick}" ] && php_pick=1
        # Clear the return value of the previous step.
        expr ${php_pick} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo
            echo -e "[${red}Error!${plain}] Please enter a number."
            continue
        fi
        if [[ "${php_pick}" -lt 1 || "${php_pick}" -gt ${#php[@]} ]]; then
            echo
            echo -e "[${red}Error!${plain}] Please enter a number between 1 and ${#php[@]}"
            continue
        fi
        php_ver1=${php[$php_pick-1]}
        echo
        echo "php version = ${php_ver1}"
        break
    done
    php_ver=$(wget --no-check-certificate -qO- http://cn.php.net/distributions/ |grep -o "${php_ver1}.*.tar.gz" |awk -F '.tar' '{print $1}')
    php_link="http://cn.php.net/distributions/${php_ver}.tar.gz"
}

get_nginx_ver(){
    nginx_ver1=$(wget --no-check-certificate -qO- https://nginx.org/download/ |awk -F '>' '{print $2}' |egrep -o 'nginx-[0-9].*.tar.gz' |sort -n |awk -F '.' '{print $1}')

    nginx_ver=$(wget --no-check-certificate -qO- https://nginx.org/download/ |awk -F '>' '{print $2}' |egrep -o "${nginx_ver1}.*.tar.gz" |sort -n -t '.' -k 2 |tail -1 |awk -F '.tar' '{print $1}')
    if [ -z ${nginx_ver} ];then
        echo
        echo -e "[${red}Error!${plain}] Get nginx version failed"
        exit 1
    fi
    nginx_link="https://nginx.org/download/${nginx_ver}.tar.gz"
}

download(){
    local filename=${1}
    if [ -s ${filename} ]; then
        echo
        echo -e "[${green}Info!${plain}] ${filename} [found]"
    else
        echo
        echo -e "[${green}Info!${plain}] ${filename} not found, download now..."
        echo
        wget --no-check-certificate -c -O ${1} ${2}
        if [ $? -eq 0 ]; then
            echo
            echo -e "[${green}Info!${plain}] ${filename} download completed..."
            echo
        else
            echo
            echo -e "[${red}Error!${plain}] Failed to download ${filename}, please download it to ${cur_dir} directory manually and try again."
            exit 1
        fi
    fi
}

# mysql
conf_mysql(){
    # MySQL configuration file.
    if [ "${mysql_ver}" == "MySQL-5.5" ];then
        mem=$(free -m | awk '/Mem/ {print $2}')
        if [ ${mem} -gt "800" ] && [ ${mem} -lt "1000" ];then
            cp support-files/my-large.cnf /etc/my.cnf && sed -i "/^\[mysqld\]$/a\datadir = ${mysql_data_dir}" /etc/my.cnf
        elif [ ${mem} -gt "1500" ] && [ ${mem} -lt "2000" ];then
            cp support-files/my-huge.cnf /etc/my.cnf && sed -i "/^\[mysqld\]$/a\datadir = ${mysql_data_dir}" /etc/my.cnf
        elif [ ${mem} -gt "3000" ] && [ ${mem} -lt "4000" ];then
            cp support-files/my-innodb-heavy-4G.cnf /etc/my.cnf && sed -i "/^\[mysqld\]$/a\datadir = ${mysql_data_dir}" /etc/my.cnf
        fi
    else
        cat > /etc/my.cnf <<EOF
[mysqld]
innodb_buffer_pool_size = 128M
basedir = ${mysql_location}
datadir = ${mysql_data_dir}
port = 3306
server_id = 128
socket = /tmp/mysql.sock
join_buffer_size = 128M
sort_buffer_size = 2M
read_rnd_buffer_size = 2M
sql_mode=NO_ENGINE_SUBSTITUTTON,STRICT_TRANS_TABLES
EOF
    fi
}

install_mysql(){
    install_info mysql
    if [ -d ${mysql_location} ];then
        echo
        echo -e "[${yellow}Warning!${plain}] The mysql already installed."
        return
    fi
    rpm -qa |grep -q mysql && yum remove -y mysql

    # The installation depends on the software package.
    for mysql_dep in perl perl-devel libaio autoconf
    do
        yum_deppak ${mysql_dep}
    done

    cd /usr/local/src
    get_mysql_ver
    download ${mysql_last_ver}.tar.gz ${mysql_link}
    tar_info ${mysql_last_ver}
    mv ${mysql_last_ver} ${mysql_location}

    # Determine if the mysql user exists.
    id -u mysql >/dev/null 2>&1
    if [ $? -ne 0 ] ;then
        useradd -s /sbin/nologin mysql
    fi

    # Determine if the mysql data directory exists.
    [ ! -d ${mysql_data_dir} ] && mkdir -p ${mysql_data_dir}
    chown -R mysql:mysql ${mysql_data_dir}

    cd ${mysql_location}

    # MySQL initialization.
    ./scripts/mysql_install_db --user=mysql --datadir=${mysql_data_dir}
    check_ok mysql install

    # Copy the configuration file.
    [ -s /etc/my.cnf ] && mv /etc/my.cnf /etc/my.cnf.bak
    conf_mysql

    # Start mysql server.
    [ -s /etc/init.d/mysqld ] && mv /etc/init.d/mysqld /etc/init.d/mysqld.bak
    cp support-files/mysql.server /etc/init.d/mysqld
    sed -i "s#^datadir=#datadir=${mysql_data_dir}#g" /etc/init.d/mysqld
    chmod 755 /etc/init.d/mysqld
    chkconfig --add mysqld
    chkconfig mysqld on
    /etc/init.d/mysqld start
    check_ok mysql start

    # About the mysql service security configuration.
    echo "PATH=${PATH}:${mysql_location}/bin" > /etc/profile.d/mysql.sh
    source /etc/profile.d/mysql.sh
    echo
    read -p "Please enter the mysql server root password: " mysql_root_pass
    mysqladmin -uroot password "${mysql_root_pass}"
    mysql -uroot -p${mysql_root_pass} <<EOF
drop database if exists test;
delete from mysql.user where not (user='root');
delete from mysql.user where user='root' and password='';
delete from mysql.db where user='';
flush privileges;
exit
EOF
    complete_info mysql
}

# apache
conf_apache_php(){
    cp ${apache_location}/conf/httpd.conf ${apache_location}/conf/httpd.conf.bak
    sed -i 's/^#ServerName www.example.com:80/ServerName 0.0.0.0:80/g' ${apache_location}/conf/httpd.conf
    sed -i 's@^#Include conf/extra/httpd-vhosts.conf@Include conf/extra/httpd-vhosts.conf@g' ${apache_location}/conf/httpd.conf
    sed -i 's/Require all denied/Require all granted/g' ${apache_location}/conf/httpd.conf
    sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.htm index.php/g' ${apache_location}/conf/httpd.conf
    sed -i '/AddType .*.gz .tgz$/a\    AddType application\/x-httpd-php .php' ${apache_location}/conf/httpd.conf

    # The apache vhosts configuration
    cp ${apache_location}/conf/extra/httpd-vhosts.conf ${apache_location}/conf/extra/httpd-vhosts.conf.bak
    grep '^#' ${apache_location}/conf/extra/httpd-vhosts.conf >${apache_location}/conf/extra/httpd-vhosts.conf
    cat >>${apache_location}/conf/extra/httpd-vhosts.conf<<VHOSTS_CONF
<VirtualHost *:80>
    DocumentRoot "${web_root}/test"
    ServerName ${ipaddr}
</VirtualHost>
VHOSTS_CONF

    # php service test
    if [ ! -d ${web_root}/test ];then
        mkdir -p ${web_root}/test
    fi
    cat >${web_root}/test/index.php<<TEST
<?php
    echo "The php parsed successfully!";
?>
TEST
}

install_apr(){
    if [ ! -d /usr/local/apr ];then
        echo
        echo -e "${green}Info${plain}. Install apr..."
        cd /usr/local/src
        download ${apr_ver}.tar.gz ${apr_link}
        tar_info ${apr_ver}
        cd ${apr_ver}
        ./configure --prefix=/usr/local/apr
        check_ok apr configure
        make && make install
    else
        echo
        echo -e "[${yellow}Warning!${plain}] The apr already installed."
    fi
    if [ ! -d /usr/local/apr-util ];then
        echo
        echo -e "${green}Info${plain}. Install apr-util..."
        cd /usr/local/src
        download ${apr_util_ver}.tar.gz ${apr_util_link}
        tar_info ${apr_util_ver}
        cd ${apr_util_ver}
        ./configure --prefix=/usr/local/apr-util --with-apr=/usr/local/apr
        check_ok apr-util configure
        make && make install
    else
        echo
        echo -e "[${yellow}Warning!${plain}] The apr-util already installed."
    fi
}

install_apache(){
    install_info apache
    if [ ! -d ${apache_location} ];then
        get_apache_ver
        for apache_dep in pcre pcre-devel expat-devel openssl openssl-devel
        do
            yum_deppak ${apache_dep}
        done
        install_apr
        echo
        echo -e "${green}Info${plain}. Install apache..."
        cd /usr/local/src
        download ${httpd_ver}.tar.gz ${httpd_link}
        tar_info ${httpd_ver}
        cd ${httpd_ver}
        ./configure --prefix=${apache_location} \
        --with-apr=/usr/local/apr \
        --with-apr-util=/usr/local/apr-util \
        --with-ssl \
        --enable-so \
        --enable-mods-shared=mots
        check_ok apache configure
        make && make install
        conf_apache_php
    else
        echo
        echo -e "[${yellow}Warning!${plain}] The apache already installed."
        return
    fi
    add_firewalld
    complete_info apache
}

# php
conf_php(){
    [ -s ${php_location}/etc/php.ini ] && mv ${php_location}/etc/php.ini ${php_location}/etc/php.ini.bak
    cp php.ini-production ${php_location}/etc/php.ini
    sed -i '/;date.timezone =/a\date.timezone = Asia\/Shanghai' ${php_location}/etc/php.ini
    sed -i 's/expose_php = On/expose_php = Off/g' ${php_location}/etc/php.ini
    sed -i 's/disable_functions = /disable_functions = eval,assert,popen,passthru,escapeshellarg,escapeshellcmd,passthru,exec,system,chroot,scandir,chgrp,chown,escapeshellcmd,escapeshellarg,shell_exec,proc_get_status,ini_alter,ini_restore,dl,pfsockopen,openlog,syslog,readlink,symlink,leak,popepassthru,stream_socket_server,popen,proc_open,proc_close,phpinfo,fsocket,fsockopen/g' ${php_location}/etc/php.ini
}

install_php(){
    install_info php
    if [ ! -d ${mysql_location} ] || [ ! -d ${apache_location} ];then
        echo 
        echo -e "[${red}Error!${plain}] You must first install the MySQL service."
        exit 1
    elif [ -d ${php_location} ];then
        echo
        echo -e "[${yellow}Warning!${plain}] The php already installed."
        return
    fi

    for php_dep in libmcrypt-devel libxml2-devel libcurl-devel libpng-devel freetype-devel libtool-ltdl-devel perl-devel bzip2 bzip2-devel libjpeg-devel
    do
        yum_deppak ${php_dep}
    done

    cd /usr/local/src
    get_php_ver
    download ${php_ver}.tar.gz ${php_link}
    tar_info ${php_ver}

    cd ${php_ver}
    make clean
    ./configure --prefix=${php_location} \
    --with-apxs2=${apache_location}/bin/apxs  \
    --with-config-file-path=${php_location}/etc \
    --with-mysql=${mysql_location} \
    --with-pdo-mysql=${mysql_location} \
    --with-mysqli=${mysql_location}/bin/mysql_config \
    --with-libxml-dir \
    --with-gd \
    --with-jpeg-dir \
    --with-png-dir \
    --with-freetype-dir \
    --with-iconv-dir \
    --with-zlib-dir \
    --with-bz2 \
    --with-openssl \
    --with-gettext \
    --enable-soap \
    --enable-gd-native-ttf \
    --enable-mbstring \
    --enable-sockets \
    --enable-exif \
    --enable-bcmath
    
    check_ok php configure
    make
    check_ok php make
    make install
    check_ok php install
    cp php.ini-production ${php_location}/etc/php.ini
    conf_php
    complete_info php
    ${apache_location}/bin/apachectl start
    check_ok apache start
}

# nginx
conf_nginx(){
    [ -s ${nginx_location}/conf/nginx.conf ] && mv ${nginx_location}/conf/nginx.conf ${nginx_location}/conf/nginx.conf.bak

    cat > ${nginx_location}/conf/nginx.conf<<NGINX_CONF

NGINX_CONF

    mkdir ${nginx_location}/conf/vhosts
    cat > ${nginx_location}/conf/vhosts/test.conf<<VHOSTS_CONF
server
{
    listen 80;
    server_name ${ipaddr};
    root ${web_root}/test;
 
    location ~ \.php$
    {
        include fastcgi_params;
        fastcgi_pass unix:/tmp/php-test.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME ${web_root}/test$fastcgi_script_name;
    }
}
VHOSTS_CONF


    # website php service test
    if [ ! -d ${web_root}/test ];then
        mkdir -p ${web_root}/test
    fi
    cat >${web_root}/test/index.php<<TEST
<?php
    echo "The php parsed successfully!";
?>
TEST
}

install_nginx(){
    install_info nginx
    if [ -d ${nginx_location} ];then
        echo
        echo -e "[${yellow}Warning!${plain}] The nginx already installed."
        return
    fi
    for nginx_dep in pcre pcre-devel openssl openssl-devel
    do
        yum_deppak ${nginx_dep}
    done
    cd /usr/local/src
    get_nginx_ver
    download ${nginx_ver}.tar.gz ${nginx_link}
    tar_info ${nginx_ver}
    cd ${nginx_ver}

    ./configure --prefix=${nginx_location} \
    --with-http_ssl_module
    check_ok nginx configure
    make &&  make install
    check_ok nginx install
    conf_nginx
    chmod 755 /etc/init.d/nginx
    chkconfig --add nginx
    chkconfig nginx on
    if ps -ef |grep -q 'httpd'
    then
        killall httpd
    fi
    /etc/init.d/nginx start
    check_ok nginx start
    add_firewalld
    complete_info nginx
}

# php-fpm
conf_php_fpm(){
    [ -s ${php_fpm_location}/etc/php.ini ] && mv ${php_fpm_location}/etc/php.ini ${php_fpm_location}/etc/php.ini.bak
    cp php.ini-production ${php_fpm_location}/etc/php.ini
    sed -i '/;date.timezone =/a\date.timezone = Asia\/Shanghai' ${php_fpm_location}/etc/php.ini
    sed -i 's/expose_php = On/expose_php = Off/g' ${php_fpm_location}/etc/php.ini
    sed -i 's/disable_functions = /disable_functions = eval,assert,popen,passthru,escapeshellarg,escapeshellcmd,passthru,exec,system,chroot,scandir,chgrp,chown,escapeshellcmd,escapeshellarg,shell_exec,proc_get_status,ini_alter,ini_restore,dl,pfsockopen,openlog,syslog,readlink,symlink,leak,popepassthru,stream_socket_server,popen,proc_open,proc_close,phpinfo,fsocket,fsockopen/g' ${php_fpm_location}/etc/php.ini

    if [ -s ${php_fpm_location}/etc/php-fpm.conf.default ];then
        cp ${php_fpm_location}/etc/php-fpm.conf.default ${php_fpm_location}/etc/php-fpm.conf
        sed -i 's/\[global\]/a\include=php-fpm.d\/*.conf' ${php_fpm_location}//etc/php-fpm.conf
        sed -i 's/\[global\]/a\error_log = log\/php-fpm.log' ${php_fpm_location}//etc/php-fpm.conf
        sed -i 's/\[global\]/a\pid = run\/php-fpm.pid' ${php_fpm_location}//etc/php-fpm.conf
    else
        cat >${php_fpm_location}/etc/php-fpm.conf<<PHP_FPM
[global]
pid = run/php-fpm.pid
error_log = log/php-fpm.log
include=php-fpm.d/*.conf
PHP_FPM
    fi

    mkdir ${php_fpm_location}/etc/php-fpm.d/
    cat >${php_fpm_location}/etc/php-fpm.d/test.conf<<EOF
[test]
listen = /tmp/php-test.sock
listen.mode = 666
user = php-fpm
group = php-fpm
pm = dynamic
pm.max_children = 50
pm.start_servers = 20
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
rlimit_files = 1024
EOF
}

install_php_fpm(){
    install_info php-fpm
    if [ -d ${php_fpm_location} ];then
        echo
        echo -e "[${yellow}Warning!${plain}] The php-fpm already installed."
        return
    fi
    # The installation depends on the software package.
    for php_frm_dep in openssl-devel libcurl-devel libxml2-devel libjpeg-devel epel-release libmcrypt-devel libpng-devel freetype-devel libtool-ltdl-devel perl-devel bzip2 bzip2-devel
    do
        yum_deppak ${php_frm_dep}
    done

    # Determine if the php-fpm user exists.
    id -u php-fpm >/dev/null 2>&1
    if [ $? -ne 0 ] ;then
        useradd -s /sbin/nologin php-fpm
    fi

    cd /usr/local/src
    get_php_ver
    download ${php_ver}.tar.gz ${php_link}
    tar_info ${php_ver}
    cd ${php_ver}
    make clean
    ./configure \
    --prefix=${php_fpm_location} \
    --with-config-file-path=${php_fpm_location}/etc \
    --enable-fpm \
    --with-fpm-user=php-fpm \
    --with-fpm-group=php-fpm \
    --with-mysql=${mysql_location} \
    --with-pdo-mysql=${mysql_location}  \
    --with-mysqli=${mysql_location}/bin/mysql_config \
    --with-mysql-sock=/tmp/mysql.sock \
    --with-libxml-dir \
    --with-gd \
    --with-jpeg-dir \
    --with-png-dir \
    --with-freetype-dir \
    --with-iconv-dir \
    --with-zlib-dir \
    --enable-soap \
    --with-mcrypt \
    --enable-gd-native-ttf \
    --enable-ftp \
    --enable-mbstring \
    --enable-exif \
    --with-pear \
    --with-curl \
    --with-openssl

    check_ok php-fpm configure
    make
    check_ok php-fpm make
    make install
    check_ok php-fpm make_install
    conf_php_fpm
    cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    chmod 755 /etc/init.d/php-fpm
    chkconfig --add php-fpm
    chkconfig php-fpm on
    /etc/init.d/php-fpm start
    check_ok php-fpm start
    complete_info php-fpm
}

uninstall_mysql(){
    if ps -ef |grep -q 'mysqld'
    then
        /etc/init.d/mysqld stop >/dev/null 2>&1
    fi
    rm -rf ${mysql_location}
    rm -rf /data
    rm -rf /etc/my.cnf
    rm -rf /etc/init.d/mysqld
    rm -rf /etc/profile.d/mysql.sh
    [ -s /etc/my.cnf.bak ] && mv /etc/my.cnf.bak /etc/my.cnf
    echo
    echo -e "[${green}Info!${plain}] The mysql uninstall success!"
}

uninstall_apache(){
    if ps -ef |grep -q 'httpd'
    then
        ${apache_location}/bin/apachectl stop >/dev/null 2>&1
    fi
    rm -rf ${apache_location}
    rm -rf /usr/local/apr
    rm -rf /usr/local/apr-util
    rm -rf ${php_location}
    echo
    echo -e "[${green}Info!${plain}] The apache and php uninstall success!"
    echo
}

uninstall_nginx(){
    if ps -ef |grep -q 'nginx'
    then
        /etc/init.d/nginx stop >/dev/null 2>&1
    fi
    chkconfig --del nginx
    rm -rf /etc/init.d/nginx
    echo
    echo -e "[${green}Info!${plain} The nginx uninstall success!]"
    echo
}
uninstall_php_fpm(){
    if ps -ef |grep -q 'php-fpm'
    then
        /etc/init.d/php-fpm stop >/dev/null 2>&1
    fi
    chkconfig --del php-fpm
    rm -rf ${php_fpm_location}
    rm -rf /etc/init.d/php-fpm
    echo
    echo -e "[${green}Info!${plain} The php-fpm uninstall success!]"
    echo
}

install_lamp(){
    print_info
    disable_selinux
    install_deppak
    install_mysql
    install_apache
    install_php
    print_info
    echo
    echo "+---------------------------------------------------------------------------+"
    echo
    echo "       Your ip address           | ${ipaddr}"
    echo "       Mysql data dir            | ${mysql_data_dir}"
    echo "       Web root                  | ${web_root}"
    echo
    echo "+---------------------------------------------------------------------------+"
    echo
    echo -e "[${green}Info!${plain}] The lamp install success!"
    echo -e "[${green}Info!${plain}] Please visit your IP address in your browser."
    echo -e "[${green}Info!${plain}] Thanks for your use this script."
    blank_line
}

install_lnmp(){
    print_info
    disable_selinux
    install_deppak
    install_mysql
    install_nginx
    install_php_fpm
    print_info
    echo
    echo "+---------------------------------------------------------------------------+"
    echo
    echo "       Your ip address           | ${ipaddr}"
    echo "       Mysql data dir            | ${mysql_data_dir}"
    echo "       Web root                  | ${web_root}"
    echo
    echo "+---------------------------------------------------------------------------+"
    echo
    echo -e "[${green}Info!${plain}] The lnmp install success!"
    echo -e "[${green}Info!${plain}] Please visit your IP address in your browser."
    echo -e "[${green}Info!${plain}] Thanks for your use this script."
    blank_line
}

uninstall_lamp(){
    print_info
    blank_line
    uninstall_apache
    uninstall_mysql
    echo
    echo -e "[${green}Info!${plain}] The lnmp uninstall success!"
    echo -e "[${green}Info!${plain}] Thanks for your use this script."
    blank_line
}

uninstall_lnmp(){
    print_info
    blank_line
    uninstall_php_fpm
    uninstall_mysql
    uninstall_nginx
    echo
    echo -e "[${green}Info!${plain}] The lnmp uninstall success!"
    echo -e "[${green}Info!${plain}] Thanks for your use this script."
    blank_line
}


if [ $(id -u) != "0" ];then
    echo "Error: This script must be run as root!"
    exit 1
elif [ `cat /etc/redhat-release |awk -F '.' '{print $1}'|awk '{print $NF}'` -ne 7 ];then
    echo "You have to run script on CentOS 7"
    exit 1
fi


case ${1} in
    lamp|lnmp)
        install_${1}
        ;;
    uninstall_lamp|uninstall_lnmp)
        ${1}
        ;;
    *)
        echo
        echo -e "[${red}Error!${plain}] Please check your input syntax.Please run ${0} lamp|lnmp"
        echo
        ;;
esac

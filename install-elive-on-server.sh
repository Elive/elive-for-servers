#!/bin/bash
SOURCE="install-elive-on-server.sh"
#
# This tool should be run from a screen/tmux if possible, in order to avoid possible disconnections
#
# NEVER set -e, so traps are ignored!
#set -e
# ERR is catched too an inherited in parents, needed
set -E
# catch signals
set -o functrace
shopt -s extdebug
# avoid ! expansion
set +o histexpand
# verbose:
#set -x

# phpmyadmin must be configured manually to not install database
#export DEBIAN_FRONTEND=noninteractive
#TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true

get_args(){
    # options {{{

    args="$@"
    for arg in "$@"
    do
        case "$arg" in
            #"--disable-ipv6")
                #is_wanted_disable_ipv6=1
                #notimplemented
                #;;
            #"--enable-ipv6")
                #is_wanted_enable_ipv6=1
                #notimplemented
                #;;
            "--domain="*)
                domain="${arg#*=}"
                if [[ "$domain" = "yourdomain.com" ]] ; then
                    echo -e "E: --domain= must include YOUR domain used in your server" 1>&2
                    exit 1
                fi
                ;;
            "--user="*)
                buf="${arg#*=}"
                username="${buf%:*}"
                user_pass="${buf#*:}"
                ;;
            "--pass-root="*)
                pass_root="${arg#*=}"
                is_change_pass_root=1
                ;;
            "--pass-mariadb="*)
                pass_mariadb_root="${arg#*=}"
                ;;
            "--email="*)
                email_admin="${arg#*=}"
                ;;
            "--freespace-system")
                is_wanted_freespace=1
                ;;
            "--install=elive")
                is_wanted_elive=1
                ;;
            "--install=nginx")
                is_wanted_nginx=1
                is_extra_service=1
                ;;
            "--install=php")
                is_wanted_php=1
                is_extra_service=1
                ;;
            "--install=mariadb")
                is_wanted_mariadb=1
                is_extra_service=1
                ;;
            "--install=exim")
                is_wanted_exim=1
                is_extra_service=1
                notimplemented
                ;;
            "--install=wordpress")
                is_wanted_wordpress=1
                is_extra_service=1
                ;;
            "--install=all")
                # used for debug purposes, nobody is meant to want all
                is_wanted_wordpress=1
                is_wanted_exim=1
                is_wanted_elive=1
                is_wanted_fail2ban=1
                is_wanted_monit=1
                is_wanted_rootkitcheck=1
                is_wanted_vnstat=1
                is_wanted_swapfile=1
                #is_wanted_iptables=1
                ;;
            #"--install=phpmyadmin")
                #is_wanted_phpmyadmin=1
                #is_wanted_nginx=1
                #is_wanted_php=1
                #is_extra_service=1
                #notimplemented
                #;;
            "--install=monit")
                is_wanted_monit=1
                is_extra_service=1
                ;;
            "--install=fail2ban")
                is_wanted_fail2ban=1
                is_extra_service=1
                notimplemented
                ;;
            "--install=rootkitcheck")
                is_wanted_rootkitcheck=1
                ;;
            "--install=vnstat")
                is_wanted_vnstat=1
                notimplemented
                ;;
            "--install=swapfile")
                is_wanted_swapfile=1
                ;;
            "--install=iptables")
                is_wanted_iptables=1
                notimplemented
                ;;
            "--want-sudo-nopass")
                # use it at your own risk, not recommended (undocumented on purpose) , especially on servers
                is_wanted_sudo=1
                ;;
            "--help"|"-h")
                usage
                ;;
            "--force"|"-f")
                is_force=1
                ;;

        esac
    done

    if ((is_production)) ; then

        if ((is_extra_service)) ; then
            if ! el_confirm "Important: you wanted to install a service, this tool greatly improves your server by installing Elive features on it, but we cannot guarantee that the extra service will perfectly work in your server settings and with the wanted options, it should work without issues in new servers however. By other side if you can improve this tool to be more compatible for everyone you can send us a pull request, but do NOT report issues about the services. Do you want to continue?" ; then
                exit 1
            fi
        fi

        # alpha/beta version should report errors of this tool, betatesting phase
        if ((is_tool_beta)) && ((is_production)) ; then
            export EL_REPORTS=1
            export FORCE_REPORTS=1
        fi
    fi

    if [[ "$EL_DEBUG" -gt 2 ]] ; then
        echo -e "D: \$0 is $0" 1>&2
    fi
    if [[ "$0" = "/proc/self/fd/"* ]] || [[ "$0" = "/dev/fd/"* ]] ; then
        is_mode_curl=1
    fi

    # checks
    if [[ -z "$domain" ]] ; then
        # running from curl?
        if ((is_mode_curl)) ; then
            echo -e "What is the domain for your server?"
            read domain
            if ! el_confirm "domain is '$domain' and hostname is '$(hostname)', this machine is '$(hostname).$domain' this is correct?" ; then
                echo -e "Exiting..."
                exit
            fi
        else
            echo -e "E: Your 'domain' must be set:\n"
            usage
        fi
    fi

    # - arguments & features }}}
}

installed_set(){
    touch /etc/elive-server
    addconfig "Installed: $1" /etc/elive-server
    el_info "Installed ${1^^} ${2}"
}
installed_unset(){
    sed -i -e "/^Installed: ${1}$/d" /etc/elive-server
}
installed_check(){
    if grep -qs "^Installed: ${1}$" /etc/elive-server ; then
        echo -e "D: '$1' already set up, use --force to reinstall it" 2>&1
        return 0
    else
        return 1
    fi
}
installed_ask(){
    # force mdoe always want to install things when asking
    if ((is_force)) ;then
        return 0
    fi
    # do not install if already installed
    if installed_check "$1" ; then
        return 1
    else
        if ((is_production)) ; then
            # ask user if wants to install
            if el_confirm "$2" ; then
                return 0
            else
                return 1
            fi
        else
            # betatest mode always say yes
            return 0
        fi
    fi
}



addconfig(){
    # add a config entry, no matter what
    if [[ -e "$2" ]] ; then
        if ! grep -qs "^${1}$" "$2" ; then
            echo -e "${1}" >> "$2"
        fi
    else
        el_error "file '$2' doesn't exist"
        exit 1
    fi
}
changeconfig(){
    # change $1 conf to $2 value in $3 file
    # $1 = orig-string, $2 = change, $3 = file

    if [[ -e "$3" ]] ; then
        # if not already set
        if ! grep -qs "^${2}$" "$3" ; then
            if grep -qs "$1" "$3" ; then
                sed -i "s|${1}.*$|$2|g" "$3"
            else
                echo -e "$2" >> "$3"
            fi
        fi
    else
        el_error "file '$3' doesn't exist"
        exit 1
    fi
}


error_signal_trapped(){
    # cleanups
    rm -rf "$sources"

    #echo -e "\nE: Trapped error signal, continue? (simply logout)"
    # TODO: most failed installs is because apt install fails, try to catch the error message to a log file and report it
    echo -e "\n\nE: Trapped error signal, please verify what failed ^, then try to fix the script and do a pull request so we can have it updated and improved on: https://github.com/Elive/elive-for-servers\n"

    prepare_environment stop

    exit 1
}
trap "error_signal_trapped" ERR
#trap "exit_error" 1 2 3 6 9 11 13 14 15

prepare_environment(){
    case "$1" in
        start)
            if ! [[ "$( readlink -f "/usr/sbin/update-initramfs" )" = "/bin/true" ]] \
                && ! [[ -e "/usr/sbin/update-initramfs.orig" ]] ; then

            mv "/usr/sbin/update-initramfs" "/usr/sbin/update-initramfs.orig"
            ln -s /bin/true "/usr/sbin/update-initramfs"
            fi

            # stop processes that can annoy us
            for i in apt-daily-upgrade unattended-upgrades
            do
                service stop "$i" 1>/dev/null 2>&1 || true
            done
            ;;
        stop)
            if [[ -e /usr/sbin/update-initramfs.orig ]] ; then
                rm -f /usr/sbin/update-initramfs || true
                mv -f /usr/sbin/update-initramfs.orig /usr/sbin/update-initramfs || true
            fi

            if ((is_packages_installed)) ; then
                rm -f /boot/initrd.img* 2>/dev/null || true
                update-initramfs -k all -d -c || true
            fi

            # restart needed services
            for i in apt-daily-upgrade unattended-upgrades
            do
                service start "$i" 1>/dev/null 2>&1 || true
            done
            ;;
    esac
}


#===  FUNCTION  ================================================================
#          NAME:  el_confirm
#   DESCRIPTION:  ask (console) for confirmation
#    PARAMETERS:  question
#       RETURNS:  true | false
#===============================================================================
el_confirm(){
    # pre {{{
    local reply question flag_glob

    question="$1"

    # }}}
    # return answer {{{

    echo -en "\n$question [y/n]: "
    if [[ -n "$ZSH_VERSION" ]] ; then
        read reply
    else
        read -e reply
    fi

    case "$reply" in
        y|Y|Yes|YES|s|S)
            return  0
            ;;
        n|N|no|NO|nope)
            return  1
            ;;
        *)
            # repeat question until confirmation
            if el_confirm "$@" ; then
                return 0
            else
                return 1
            fi
            ;;
    esac

    # }}}
}

require_variables(){
    if ! el_check_variables "$@" ; then
        NOREPORTS=1 el_error "Needed variable is not set, function '${FUNCNAME[1]}'. See the --help to show the available options"
        exit 1
    fi
}


packages_install(){
    local package

    apt-get -qq clean
    apt-get -q update
    apt-get -qq autoremove

    if ! apt-get install $apt_options $@ ; then
        if ((is_production)) ; then
            echo -e "E: unable to install all packages in one shot, looping one to one..."
            for package in $@
            do
                apt-get install $apt_options $package
            done
        else
            echo -e "E: Something failed ^ installing packages: $@" 1>&2
            exit 1
        fi
    fi

    is_packages_installed=1
}
packages_remove(){
    local package

    if ! apt-get remove $apt_options $@ ; then
        if ((is_production)) ; then
            echo -e "E: unable to remove all packages in one shot, looping one to one..."
            for package in $@
            do
                apt-get remove $apt_options $package || ret="$?"
            done
        else
            echo -e "E: Something failed ^ removing packages: $@" 1>&2
            exit 1
        fi
    fi

    return $ret
}

sources_update_adapt(){
    sources="/root/elive-for-servers"
    templates="$sources/templates"

    rm -rf "$sources" 1>/dev/null 2>&1 || true
    cd "$( dirname "$sources" )"
    el_debug "Getting a git copy of elive-for-servers:"
    # zip mode? https://github.com/Elive/elive-for-servers/archive/refs/heads/main.zip
    git clone -q https://github.com/Elive/elive-for-servers.git "$sources"

    # check for updated tool | not works and not good to have
    #if ! ((is_mode_curl)) ; then
        #if [[ -s "$sources/install-elive-on-server.sh" ]] ; then
            #if [[ "$( diff "$0" "$sources/install-elive-on-server.sh" | wc -l )" -gt 4 ]] ; then
                ##if el_confirm "Seems like this tool has new updates from its git version, do you want to update it first?" ; then
                    #cp -f "$sources/install-elive-on-server.sh" "$0"

                    #el_warning "tool updated: running it again..."
                    #"$0" "$args"
                    #exit
                ##fi
            #fi
        #fi
    #fi

    # set the date of builded elive as the last commit date on the repo
    touch /etc/elive-version
    cd "$sources"
    changeconfig "^date-builded:" "date-builded: $( git log -1 --format=%cs )" /etc/elive-version


    el_debug "Replacing template conf files with your values:"
    cd "$templates"
    # TODO: search and replace in templates for all extra eliveuser, elivewp, ips, thana... etc, do a standard base templates system
    find "${templates}" -type f -exec sed -i "s|${previous_ip}|${domain_ip}|g" {} \;
    find "${templates}" -type f -exec sed -i "s|webmaster@elivecd.org|${email_admin}|g" {} \;
    zsh <<EOF
rename "s/elivecd.org/$domain/" ${templates}/**/*(.)
rename "s/hostdo1/${hostname}/" ${templates}/**/*(.)
EOF

    find "$templates" -type f -exec sed -i \
        -e "s|elivecd.org|${domain}|g" \
        -e "s|hostdo1|${hostname}|g" \
        "{}" \;

    if [[ -n "$username" ]] ; then
        zsh <<EOF
rename "s/elivewp@/${username}@/" ${templates}/**/*(.)
rename "s/elivewp/${username}/" ${templates}/**/*(.)
EOF
        find "$templates" -type f -exec sed -i "s|elivewp|${username}|g" "{}" \;
    fi

    if [[ -n "$email_admin" ]] ; then
        find "$templates" -type f -exec sed -i \
            -e "s|webmaster@elivecd.org|${email_admin}|g" \
            -e "s|hostmaster@elivecd.org|${email_admin}|g" \
            "{}" \;
    fi

    if [[ -n "$wp_webname" ]] ; then
        zsh <<EOF
rename "s/mywordpress.com/${wp_webname}/" ${templates}/**/*(.)
EOF
        find "$templates" -type f -exec sed -i "s|mywordpress.com|${wp_webname}|g" "{}" \;
    fi



    # checks
    #ack -i "elive" "$templates" || true
    #ack -i "thanatermesis" "$templates" || true
    #ack -i "hostdo1" "$templates" || true

    cd ~
}

install_templates(){
    local dir_prev
    dir_prev="$(pwd)"
    name="$1" ; shift
    dest="$1" ; shift

    require_variables "name|dest"

    sources_update_adapt

    if ! [[ -d "$templates/$name" ]] ; then
        el_error "Templates missing: '$name'. Service install unable to be completed"
        exit 1
    fi

    cd "${templates}/$name"
    find . -type f -o -type l -o -type p -o -type s | sed -e 's|^\./||g' | cpio -padu -- "${dest%/}"
    cd ~

    el_info "Installed template '$name'"
}



update_variables(){
    if [[ -z "$domain_ip" ]] ; then
        if [[ -x "$( which showmyip )" ]] ; then
            domain_ip="$( showmyip )"
        else
            domain_ip="$( curl -A 'Mozilla' --max-time 8 -s http://icanhazip.com | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | tail -1 )"
        fi
        read -r domain_ip <<< "$domain_ip"
        if ! echo "$domain_ip" | grep -qs "^[[:digit:]]" ; then
            echo -e "E: unable to get ip"
            exit 1
        fi
    fi

    if [[ -z "$elive_version" ]] ; then
        elive_version="$( lynx -connect_timeout 12 -dump https://www.elivecd.org/news/ | grep -i "elive .* released" | head -1 | sed -e 's|^.*Elive ||g' -e 's| .*$||g' )"
        if [[ -z "$elive_version" ]] ; then
            sleep 2
            elive_version="$( lynx -connect_timeout 20 -dump https://www.elivecd.org/news/ | grep -i "elive .* released" | head -1 | sed -e 's|^.*Elive ||g' -e 's| .*$||g' )"
            if [[ -z "$elive_version" ]] ; then
                echo -e "E: unable to get ip, please install 'lynx' first"
                exit 1
            fi
        fi
    fi

    if [[ -z "$php_version" ]] ; then
        if which php 1>/dev/null ; then
            php_version="$( php -i 2>&1 | grep -iE "^PHP Version => [[:digit:]]+\.[[:digit:]]+\." | sed -e 's|^.*=> ||g' | head -1 )"
            # get x.x from x.x.x version
            php_version="$( echo "$php_version" | awk -v FS="." '{print $1"."$2}' )"
        fi
    fi

    #ifconfig lo down
    #if ifconfig | grep -qs "inet6" ; then
        #has_ipv6=1
    #fi
    #ifconfig lo up

}

install_elive(){
    local packages_extra
    mkdir -p /etc/apt/sources.list.d /etc/apt/preferences.d /etc/apt/trusted.gpg.d

    if [[ -z "$debian_version" ]] || [[ -z "$elive_version" ]] || [[ -z "$elive_repo" ]] ; then
        echo -e "E: missing variables required"
    fi

    # we don't need these, so save some space and time
    sed -i 's/^deb-src /#&/' /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/aaa-elive.list

    # upgrade the system first
    apt-get -qq clean
    apt-get update
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        apt-get -q dist-upgrade $apt_options

    packages_install \
        gnupg wget curl
    #apt-get dist-upgrade $apt_options

    # add elive repo
    echo -e "$elive_repo" > /etc/apt/sources.list.d/aaa-elive.list
    if ((is_ubuntu)) ; then
        echo -e "Package:\t\t*\nPin:\t\t\trelease o=Elive\nPin-Priority:\t\t100\n\n" > /etc/apt/preferences.d/elive_priority.pref
    else
        echo -e "Package:\t\t*\nPin:\t\t\trelease o=Elive\nPin-Priority:\t\t1500\n\n" > /etc/apt/preferences.d/elive_priority.pref
    fi

    # elive repo key
    cd ~
    case "$debian_version" in
        # TODO: do a betatesting in BUSTER a dropplet to see if works good and complatible, so we need ot release it compatible
        buster)
            wget -q "http://main.elivecd.org/tmp/elive-key.gpg"
            cat elive-key.gpg | apt-key add -
            rm -f elive-key.gpg
            ;;
        bullseye)
            wget -q -O /etc/apt/trusted.gpg.d/elive-archive-bullseye-automatic.gpg "http://main.elivecd.org/tmp/elive-archive-bullseye-automatic.gpg"
            ;;
        *)
            # TODO: add a default message saying github collaboration
            echo -e "E: debian version '$debian_version' not supported"
            exit
            ;;
    esac


    # packages to install
    case "$debian_version" in
        #buster)
            #packages_extra="openntpd ntpdate $packages_extra"
            #;;
        bullseye|*)
            packages_extra="apt-transport-https $packages_extra"
            #if ! dpkg -l | grep -qsE "^ii .*(ntp|systemd-timesyncd)" ; then
                #packages_extra="ntp $packages_extra"
            #fi
            ;;
    esac

    mkdir -p "/etc/apt/apt.conf.d/"
    cat > "/etc/apt/apt.conf.d/temporal.conf" << EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
#Aptitude::Recommends-Important "false";
DSELECT::Clean always;
APT::Get::Clean always;
EOF

    apt-get -qq clean
    apt-get -q update

    # install elive tools
    packages_extra="vim-colorscheme-elive-molokai elive-security elive-tools elive-skel elive-skel-default-all elive-skel-default-vim vim-common zsh-elive $packages_extra"

    # upgrade possible packages from elive:
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        apt-get dist-upgrade $apt_options -qq

    # install extra features
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        packages_install $packages_extra ack apache2-utils bc binutils bzip2 colordiff command-not-found coreutils curl daemontools debian-keyring debsums diffutils dnsutils dos2unix dpkg-dev ed exuberant-ctags gawk git gnupg grep gzip htop inotify-tools iotop lsof lynx lzma ncurses-term net-tools netcat-openbsd procinfo rdiff-backup rename rsync rsyslog sed sharutils tar telnet tmux tofrodos tree unzip vim wget zip zsh ca-certificates
    # obsolete ones: tidy zsync

    # clean temporal things
    rm -f "/etc/apt/apt.conf.d/temporal.conf"

    # get functions
    source /usr/lib/elive-tools/functions

    # install templates before to do more steps
    install_templates "elive" "/"


    # TODO: in our elive server we have it, do we need it? (better: just check which packages we had installed that are not in the new/next server)
    #apt-get install -y imagemagick # note: it installs many dependencies, do we need it?

    update-command-not-found 2>/dev/null || true

    #mv /etc/apt/preferences.d/elive*pref "/tmp"
    #apt-get install --allow-downgrades -y zsh-elive
    #mv /tmp/elive*pref "/etc/apt/preferences.d/"


    # install manually dependencies if we cannot install the packages manually: TODO: document this
    #if [[ -d "/tmp/packages-to-expand_$(arch)" ]] ; then
        #for i in /tmp/packages-to-expand_$(arch)/*deb
        #do
            #dpkg -x "$i" /
        #done
    #fi

    # fixes & free space:
    rm -rf /etc/skel/.gimp* 2>/dev/null || true
    rm -rf /etc/skel/.Skype* 2>/dev/null || true
    rm -rf /etc/skel/.enlight* 2>/dev/null || true
    rm -rf /etc/skel/.e 2>/dev/null || true
    #sed -i -e '/mode-mouse/d' /etc/skel/.tmux.conf
    #sed -i -e '/status-utf8/d' /etc/skel/.tmux.conf

    # configure root user
    elive-skel user root
    addconfig "export PATH=\"~/packages/bin:\$PATH\"" "/root/.zshrc"
    addconfig "elive-logo-show --no-newline ; lsb_release -d -s ; echo ; echo\n" "/root/.zshrc"
    chsh -s /bin/zsh
    # configure ssh if was not yet
    #rm -rf ~/.ssh || true
    #mkdir -p ~/.ssh
    #if ! ssh-keygen ; then
        #ssh-keygen || true
    #fi
    #addconfig "$ssh_authorized_key" "~/.ssh/authorized_keys"
    #chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
    #if [[ -s ~/.ssh/authorized_keys ]] ; then
        #changeconfig "^PasswordAuthentication" "PasswordAuthentication no" /etc/ssh/sshd_config
    #fi
    #/etc/init.d/ssh restart

    # cronjobs
    if [[ -s /root/.crontab ]] ; then
        crontab /root/.crontab
    fi

    update_variables
    require_variables "debian_version|elive_version"

    # elive version conf
    cat > "/etc/elive-version" << EOF
elive-codename: eliveserver
elive-version: $elive_version
debian-version: $debian_version
date-builded:
kernel: $(uname -r)
machine-id: $(el_get_machine_id)
first-user: elivewp
EOF

    if ((is_ubuntu)) ; then
        sed -i -e 's|Debian|Ubuntu|g' /etc/os-release 2>/dev/null || true
    fi

    #apt-get install -y vim-common zsh-elive || bash # try if possible

    installed_set "elive"
}

install_user(){
    require_variables "username|DHOME"

    if [[ -d $DHOME/${username} ]] ; then
        NOREPORTS=1 el_warning "user $username already exist, not creating it..."
    else
        # fixes & free space:
        rm -rf /etc/skel/.gimp* 2>/dev/null || true
        rm -rf /etc/skel/.Skype* 2>/dev/null || true
        rm -rf /etc/skel/.enlight* 2>/dev/null || true
        rm -rf /etc/skel/.e 2>/dev/null || true
        #useradd -m -k /etc/skel -c "${username}" -s /bin/zsh "$username" -u 1001
        useradd -m -k /etc/skel -c "${username}" -s /bin/zsh "$username"

        adduser "$username" www-data
        adduser "$username" mail
        adduser "$username" users
        adduser "$username" adm
        #adduser "$username" Debian-exim
        #adduser "$username" docker

        if ((is_wanted_sudo)) ; then
            packages_install sudo
            adduser "$username" sudo
            addconfig "$username ALL=NOPASSWD: ALL" /etc/sudoers
            el_info "Added user '$username' to full sudo privileges (warning: use it at your own risk)"
        fi

        # user configs
        elive-skel user "$username"
        addconfig "export PATH=\"~/packages/bin:\$PATH\"" "$DHOME/${username}/.zshrc"
        addconfig "elive-logo-show --no-newline ; lsb_release -d -s ; echo ; echo " "$DHOME/${username}/.zshrc"
        chsh -s "/bin/zsh" "$username"

        rm -rf $DHOME/$username/.ssh 2>/dev/null || true
        rm -rf $DHOME/$username/.*.old 2>/dev/null || true

        cp -a /root/.ssh $DHOME/$username/
        chown -R $username:$username $DHOME/$username/.ssh

        # add the other users
        #if ! [[ -d $DHOME/elivemirror ]] ; then
            #useradd -m -k /etc/skel -c "elivemirror" -s /bin/zsh "elivemirror" -u 1003
            #elive-skel user "elivemirror"
        #fi
        # and so to the needed groups
        #for group in www-data mail users adm
        #do
            #for user in $username elivemirror
            #do
                #adduser "$user" "$group" || true
            #done
        #done

        changeconfig "first-user:" "first-user: ${username}" /etc/elive-version

        el_info "Created user '$username'"
    fi

}


install_nginx(){
    # TODO: make a system to verify incompatible services, like apache/lightttps/etc and same for email, to warn the user about these needs to be removed
    systemctl stop apache2.service tomcat9.service lighttpd.service  2>/dev/null || true
    packages_remove apache2 apache2-data apache2-bin tomcat9 lighttpd || true

    packages_install nginx-full \
        certbot letsencrypt \
        $NULL

    # enable ports
    if ((has_ufw)) ; then
        ufw allow 80/tcp
        ufw allow 443/tcp
    else
        if ((has_iptables)) ; then
            iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
        fi
    fi


    # set a default page
    addconfig "<h2><i>With Elive super-powers</i></h2>" /var/www/html/index.nginx-debian.html
    addconfig "\n\n# vim: set syn=conf filetype=cfg : #" /etc/nginx/sites-enabled/default

    if ! [[ -n "$email_admin" ]] ; then
        echo -e "Insert the admin email for your web server:"
        read email_admin
    fi

    install_templates "nginx" "/"

    # enable sites
    # TODO: implement with the templates system
    #ln -fs /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
    #ln -fs /etc/nginx/sites-available/www.${domain} /etc/nginx/sites-enabled/www.${domain} 2>/dev/null || true
    ##ln -fs /etc/nginx/sites-available/test.sandbox.${domain} /etc/nginx/sites-enabled/test.sandbox.${domain}
    #ln -fs /etc/nginx/sites-available/repository.${domain} /etc/nginx/sites-enabled/repository.${domain} 2>/dev/null || true
    ##ln -fs /etc/nginx/sites-available/collaborate.${domain} /etc/nginx/sites-enabled/collaborate.${domain}

    ##rm -f /etc/nginx/sites-enabled/default

    #
    # TODO: important note about groups: www-data: Some web browsers run as www-data. Web content should *not* be owned by this user, or a compromised web server would be able to rewrite a web site. Data written out by web servers, including log files, will be owned by www-data.


    systemctl restart nginx.service
    installed_set "nginx"
}

install_php(){
    # packages to install
    local packages_extra

    if ! ((is_ubuntu)) ; then
        case "$debian_version" in
            buster)
                packages_extra="php-gettext php-xmlrpc php-inotify php-zstd $packages_extra"
                ;;
            bullseye)
                packages_extra="php-xmlrpc php-tcpdf php-soap $packages_extra"

                # PHP 8+ can be selected optionally instead of the default version 7.4 from Debian:
                if ! el_confirm "PHP Version to select: You can optionally install a more recent version of PHP from alternative repository. But we do not recommend this, is better to stick at the debian default version for stability and security, also newer versions of php may be incompatible with your website / plugins / themes / code.\nUse the default version from Debian?" ; then
                    notimplemented
                    NOREPORTS=1 el_warning "Ignore error messages about apache and service restarts..."
                    sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                    sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
                fi
                ;;
            #impish)
                #packages_extra="$packages_extra"
                #;;
        esac
    fi

    # first install this one independently, because the buggy ubuntu wants to install apache if not
    packages_install php-fpm

    packages_install \
        php-common php-xml php-curl php-gd php-cli php-imap libphp-phpmailer libjs-cropper libphp-snoopy php-pclzip php-intl php-tidy php-pear \
        php php-bz2 php-mbstring php-phpseclib php-zip php-bcmath php-mysql php-json \
        composer \
        $packages_extra \
        $NULL

    # get php version
    update_variables
    require_variables "php_version"

    unset packages_extra
    if ! ((is_ubuntu)) ; then
        case "$php_version" in
            "7."*)
                packages_extra="php${php_version}-geoip $packages_extra"
                ;;
        esac

        packages_extra="php${php_version}-opcache php${php_version}-imagick $packages_extra"
    fi

    packages_install \
        $packages_extra

    # configure php default options
    changeconfig "default_charset =" "default_charset = \"UTF-8\"" /etc/php/$php_version/fpm/php.ini
    changeconfig "short_open_tag" "short_open_tag = \"Off\"" /etc/php/$php_version/fpm/php.ini
    changeconfig "post_max_size" "post_max_size = \"32M\"" /etc/php/$php_version/fpm/php.ini
    changeconfig "upload_max_filesize" "upload_max_filesize = \"32M\"" /etc/php/$php_version/fpm/php.ini


    # increase execution times to 4 min
    changeconfig "max_execution_time" "max_execution_time = \"240\"" /etc/php/$php_version/fpm/php.ini
    changeconfig "max_input_time" "max_input_time = \"240\"" /etc/php/$php_version/fpm/php.ini
    changeconfig "memory_limit" "memory_limit = \"320\"" /etc/php/$php_version/fpm/php.ini


    changeconfig "cgi.fix_pathinfo=1" "cgi.fix_pathinfo=0" /etc/php/$php_version/fpm/php.ini
    changeconfig "events.mechanism =" "events.mechanism = epoll" /etc/php/$php_version/fpm/php-fpm.conf

    #apt-get install -y php-apc
    #addconfig "apc.enabled=1" /etc/php/$php_version/fpm/conf.d/20-apc.ini
    #addconfig "apc.shm_size=128M" /etc/php/$php_version/fpm/conf.d/20-apc.ini
    #addconfig "apc.ttl=3600" /etc/php/$php_version/fpm/conf.d/20-apc.ini
    #addconfig "apc.user_ttl=7200" /etc/php/$php_version/fpm/conf.d/20-apc.ini
    #addconfig "apc.gc_ttl=3600" /etc/php/$php_version/fpm/conf.d/20-apc.ini
    #addconfig "apc.max_file_size=1M" /etc/php/$php_version/fpm/conf.d/20-apc.ini

    #apt-get install -y memcached php-memcache
    #service memcached restart
    #changeconfig "^-m 64" "-m 1024" /etc/memcached.conf # doens't works this entry with -
    #service memcached restart

    #addconfig "session.save_handler = memcache" /etc/php/$php_version/mods-available/memcache.ini
    #addconfig "session.save_path = \"tcp://localhost:11211\"" /etc/php/$php_version/mods-available/memcache.ini

    if [[ -s /etc/php/$php_version/fpm/pool.d/www.conf ]] ; then
        # enable monitoring state
        changeconfig ";ping" "ping.path = /ping" /etc/php/$php_version/fpm/pool.d/www.conf
        # make it more readable on vim
        addconfig "\n\n; vim: set filetype=dosini :" /etc/php/$php_version/fpm/pool.d/www.conf
        #cp /etc/php/$php_version/fpm/pool.d/www.conf /etc/php/$php_version/fpm/pool.d/www.${domain}.conf  # moved to static
        #mv /etc/php/$php_version/fpm/pool.d/www.conf /etc/php/$php_version/fpm/pool.d/www.template-demo.conf
    fi

    # enable ping path for monit monitoring process
    #changeconfig "ping.path =" "ping.path = /ping" /etc/php/$php_version/fpm/pool.d/www.${domain}.conf
    #changeconfig "^user =" "user = $username" /etc/php/$php_version/fpm/pool.d/www.${domain}.conf
    #changeconfig "^group =" "group = $username" /etc/php/$php_version/fpm/pool.d/www.${domain}.conf
    #changeconfig "; priority =" "priority = -10" /etc/php/$php_version/fpm/pool.d/www.${domain}.conf
    #changeconfig "listen =" "listen = 12$php_version.0.1:9000" /etc/php/$php_version/fpm/pool.d/www.${domain}.conf

    # improve sysctl
    addconfig "#If you use Unix sockets with PHP-FPM, you might encounter random 502 Bad Gateway errors with busy websites. To avoid this, we raise the max. number of allowed connections to a socket:" /etc/sysctl.conf
    addconfig "net.core.somaxconn = 4096" /etc/sysctl.conf

    if ((is_ubuntu)) ; then
        systemctl stop apache2.service 2>/dev/null || true
        packages_remove apache2 apache2-data apache2-bin || true
    fi

    systemctl restart php${php_version}-fpm.service
    systemctl restart nginx.service

    systemctl restart nginx.service
    installed_set "php"
}

install_mariadb(){
    # install service
    packages_install \
        mariadb-server mariadb-client \
        $NULL

    # set root password
    if [[ -z "$pass_mariadb_root" ]] ; then
        #if el_confirm "Do you want to set a root password for your DB?" ; then
            echo -e "Type your desired database root password and press Enter..."
            read pass_mariadb_root
        #fi
    fi

    if [[ -n "$pass_mariadb_root" ]] ; then
        #sed -i "s|^password = $|password = ${pass_mariadb_root}|g" /etc/mysql/debian.cnf
        #mysql -u root -p"$( grep password /etc/mysql/debian.cnf | sed -e 's|^.* = ||g' | head -1 )" -D mysql -e "update user set password=password('${pass_mariadb_root}') where user='root'"
        #mysql -u root -p"$( grep password /etc/mysql/debian.cnf | sed -e 's|^.* = ||g' | head -1 )" -D mysql -e "flush privileges"

        systemctl mariadb stop 1>/dev/null 2>&1 || true
        sleep 2

        # this ugly code needs to be made thanks to ubuntu that cannot close mysql process normally, dammit
        for i in mysqld mariadbd mysqld_safe mariadbd-safe ; do
            killall "$i" 1>/dev/null 2>&1 || true
        done
        sync ; sleep 5
        for i in mysqld mariadbd mysqld_safe mariadbd-safe ; do
            killall -9 "$i" 1>/dev/null 2>&1 || true
        done
        sync ; sleep 5

        case "$debian_version" in
            buster)
                mysqld_safe --skip-grant-tables &
                sleep 3
                #mysql -u root -D mysql -e "flush privileges; update mysql.user set password=password('${pass_mariadb_root}') where user='root'; flush privileges; update mysql.user set plugin='mysql_native_password' where user='root'; flush privileges;"
                mysql -u root -D mysql -e "flush privileges; update user set password=password('${pass_mariadb_root}') where user='root'; flush privileges; update user set plugin='mysql_native_password' where user='root'; flush privileges;"
                ;;
            bullseye|*)
                mariadbd-safe --skip-grant-tables &
                sleep 3
                mysql -u root -D mysql -e "flush privileges; SET PASSWORD FOR root@localhost = PASSWORD('${pass_mariadb_root}'); flush privileges;"
                ;;
        esac

        #mysql -u root -D mysql -e "update user set password=password('${pass_mariadb_root}') where user='root'"
        # make the user root being able to be used from the user (needed for backup-restore)
        #mysql -u root -D mysql -e "update user set plugin='mysql_native_password' where user='root'; flush privileges;"
        for i in mysqld mariadbd mysqld_safe mariadbd-safe ; do
            killall "$i" 1>/dev/null 2>&1 || true
        done
        sync ; sleep 5
        for i in mysqld mariadbd mysqld_safe mariadbd-safe ; do
            killall -9 "$i" 1>/dev/null 2>&1 || true
        done
        sync ; sleep 5

        wait
        systemctl restart mariadb.service 2>/dev/null || true

        el_info "Your MYSQL root Password will be '${pass_mariadb_root}'. KEEP IT SAFE and do not lose it!"
    else
        NOREPORTS=1 el_warning "password for your root DB not provided, you may want to run again and give a root password for your datbase server"
    fi

    installed_set "mariadb" "(mysql)"
}

install_wordpress(){
    # TODO: betatests
    pass_mariadb_root=dbpassroot
    wp_db_name=dbname
    wp_db_user=dbuser
    wp_db_pass=dbpass
    wp_webname=wp.thanatermesis.org
    username=elivewp

    if ! [[ -n "$wp_webname" ]] ; then
        echo -e "Website name for your website? (example: blog.yourdomain.com or www.eliverulez.org)"
        read wp_webname
    fi
    # dependencies {{{
    if ! installed_check "nginx" ; then
        install_nginx
    fi
    if ! installed_check "php" ; then
        install_php
    fi
    if ! installed_check "mariadb" ; then
        install_mariadb
    fi
    # image tool dependencies (shrink images)
    if ! [[ -e /var/lib/dpkg/info/webp.list ]] ; then
        packages_install \
            libjpeg-turbo-progs webp optipng pngquant gifsicle
    fi

    # }}}
    # create database {{{
    if ! [[ -n "$pass_mariadb_root" ]] ; then
        echo -e "Password of your Mariadb root user?"
        read pass_mariadb_root
    fi
    if ! [[ -n "$wp_db_name" ]] ; then
        echo -e "Database NAME for your wordpress?"
        read wp_db_name
    fi
    if ! [[ -n "$wp_db_user" ]] ; then
        echo -e "Database USER for your wordpress?"
        read wp_db_user
    fi
    if ! [[ -n "$wp_db_pass" ]] ; then
        echo -e "Database PASSWORD for your wordpress?"
        read wp_db_pass
    fi

    require_variables "wp_db_name|wp_db_user|wp_db_pass"

    mysql -u root -p"${pass_mariadb_root}" -e "CREATE USER IF NOT EXISTS ${wp_db_user}@localhost IDENTIFIED BY '${wp_db_pass}';"
    mysql -u root -p"${pass_mariadb_root}" -e "CREATE DATABASE IF NOT EXISTS ${wp_db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    #GRANT ALL PRIVILEGES ON ${wp_db_name}.* TO ${wp_db_user}@localhost IDENTIFIED BY '${wp_db_pass}' WITH GRANT OPTION;
    mysql -u root -p"${pass_mariadb_root}" -e "GRANT ALL ON ${wp_db_name}.* TO '${wp_db_user}'@'localhost' IDENTIFIED BY '${wp_db_pass}';"
    mysql -u root -p"${pass_mariadb_root}" -e "FLUSH PRIVILEGES;"

    el_info "Created Database '${wp_db_name}' with username '${wp_db_user}' and pass '${wp_db_pass}'. KEEP IT SAFE and do not lose it!"

    # }}}
    # create user if not exist {{{
    if ! [[ -n "$username" ]] ; then
        echo -e "Username you want to use for your Wordpress"
        read username
    fi
    require_variables "username"
    if ! [[ -d $DHOME/${username} ]] ; then
        install_user
    fi
    # cleanups
    if [[ -d "$DHOME/${username}/${wp_webname}" ]] ; then
        NOREPORTS=1 "The directory '${wp_webname}' in the '${username}' user's home directory already exists"
        if el_confirm "Do you want to permanently delete it?" ; then
            rm -rf "$DHOME/${username}/${wp_webname}"
        fi
    fi

    #su -c "bash -c 'mkdir -p "~/${wp_webname}" ; cd "~/${wp_webname}" '" "$username"
    su - "$username" <<EOF
bash -c '
set -e
set -E
#export PATH="$PATH"
cd ~

addconfig(){
    if [[ -e "\$2" ]] ; then
        if ! grep -qs "^\${1}\$" "\$2" ; then
            echo -e "\${1}" >> "\$2"
        fi
    else
        echo -e "E: file '\$2' doesn't exist"
        exit 1
    fi
}
changeconfig(){
    if [[ -e "\$3" ]] ; then
        # if not already set
        if ! grep -qs "^\${2}\$" "\$3" ; then
            if grep -qs "\$1" "\$3" ; then
                sed -i "s|\${1}.*\$|\$2|g" "\$3"
            else
                echo -e "\$2" >> "\$3"
            fi
        fi
    else
        echo -e "E: file '\$3' doesn't exist"
        exit 1
    fi
}
download_plugin(){
    local link filename
    link="\$( lynx -dump "https://wordpress.org/plugins/\$1/" | grep -i "downloads.wordpress.org.*zip" | sed -e "s|^.*http|http|g" | grep http )"
    if [[ -n "\$link" ]] ; then
        filename="\${link##*/}"
        wget "\$link"
        unzip "\$filename"
        rm -f "\$filename"
    fi
}

[[ -d "${wp_webname}" ]] && echo -e "\nE: directory ${wp_webname} already exist, for security remove it first manually" && exit 1
mkdir -p "${wp_webname}"
cd "${wp_webname}"
rm -f latest.tar.gz

wget -q https://wordpress.org/latest.tar.gz
tar xf latest.tar.gz
mv wordpress/* .

rm -f latest.tar.gz
rmdir wordpress

# download selected plugins & themes
set +e
cd wp-content/plugins/
download_plugin "404-error-monitor"
download_plugin "autoptimize"
download_plugin "better-wp-security"
download_plugin "block-bad-queries"
download_plugin "broken-link-checker"
download_plugin "classic-editor"
download_plugin "contact-form-7"
download_plugin "cookie-notice"
download_plugin "email-post-changes"
download_plugin "google-analytics-for-wordpress"
download_plugin "honeypot"
download_plugin "query-monitor"
download_plugin "redirection"
download_plugin "resmushit-image-optimizer"
download_plugin "search-exclude"
#download_plugin "w3-total-cache"
download_plugin "wp-super-cache"
download_plugin "wordpress-seo"
download_plugin "wp-search-suggest"
download_plugin "wp-youtube-lyte"

set -e
echo -e "\n\n\nPlugins installed:"
ls -1
echo

# configure wordpress
cd ~/
cd"${wp_webname}"
cat wp-config-sample.php | dos2unix > wp-config.php
sed -i -e "s|^define.*'DB_NAME'.*$|define( 'DB_NAME', '${wp_db_name}' );|g" wp-config.php
sed -i -e "s|^define.*'DB_USER'.*$|define( 'DB_USER', '${wp_db_user}' );|g" wp-config.php
sed -i -e "s|^define.*'DB_PASSWORD'.*$|define( 'DB_PASSWORD', '${wp_db_pass}' );|g" wp-config.php
#sed -i -e "s|^define.*'DB_HOST'.*$|define( 'DB_HOST', '${wp_db_name}' );|g" wp-config.php
#sed -i -e "s|^define.*'DB_CHARSET'.*$|define( 'DB_CHARSET', '${wp_db_name}' );|g" wp-config.php
#sed -i -e "s|^define.*'DB_COLLATE'.*$|define( 'DB_COLLATE', '${wp_db_name}' );|g" wp-config.php
echo -e "define('WP_MEMORY_LIMIT', '128M');" >> wp-config.php

'
EOF

    # }}}

    ufw allow 'Nginx Full'

    install_templates "wordpress" "/"

    # configure WP in nginx
    require_variables "php_version"
    changeconfig "fastcgi_pass" "fastcgi_pass unix:/run/php/php${php_version}-fpm.sock;" "/etc/nginx/sites-available/${wp_webname}"
    ln -s "/etc/nginx/sites-available/${wp_webname}" "/etc/nginx/sites-enabled/${wp_webname}"

    cp "/etc/php/$php_version/fpm/pool.d/www.conf" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "user =" "user = ${username}" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "group =" "group = ${username}" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "listen =" "listen = /run/php/php${php_version}-fpm.sock" "/etc/nginx/sites-available/${wp_webname}"
    #mv "/etc/php/$php_version/fpm/pool.d/www.conf" "/etc/php/$php_version/fpm/pool.d/www.conf.template"


    systemctl restart nginx.service php${php_version}-fpm.service mariadb.service

    is_installed_wordpress=1

}

install_fail2ban(){
    packages_install \
        fail2ban whois python3-pyinotify \
        nftables arptables ebtables

    installed_set "fail2ban"
}

install_exim(){
    systemctl stop  postfix.service  2>/dev/null || true
    packages_remove  postfix || true
    #apt-get install postfix postfix-pcre postfix-mysql procmail mailx
    # email alternative: exim4, howto by ikevin:  http://www.illux.org/howtos/resources/configurer-exim4-amavis-spamassassin-clamav-mysql/
    apt-get install -y exim4-daemon-heavy php-cli heirloom-mailx mutt gpgsm

    touch /etc/exim4/domains_master.conf
    touch /etc/exim4/domains_relay.conf
    touch /etc/exim4/users.conf
    rm -rf /etc/exim4/conf.d/ /etc/exim4/exim4.conf.template /etc/exim4/passwd.client /etc/exim4/update-exim4.conf.conf
    rm -rf /var/log/exim4/paniclog
    # everything else is already copied in /etc

    changeconfig "primary_hostname" "primary_hostname       = $hostnamefull" /etc/exim4/exim4.conf
    echo "$hostnamefull" > /etc/exim4/domains_master.conf
    echo "$hostnamefull" > /etc/mailname

    for i in ${domain_names}
    do
        /usr/local/sbin/exim_adddkim "${i}"
    done

    /usr/local/sbin/exim_adduser "no-reply@${domain}" "$email_noreply_pass"
    /usr/local/sbin/exim_adduser "no-reply@${hostnamefull}" "$email_noreply_pass"
    /usr/local/sbin/exim_adduser "root@${hostname}" "$email_noreply_pass"
    /usr/local/sbin/exim_adduser "root@${hostnamefull}" "$email_noreply_pass"

    chown -R root:Debian-exim /etc/exim4
    chmod -R g+r /etc/exim4/

    systemctl restart exim4.service 2>/dev/null || true


    #<ikevin> for mail, while dns are applyed (spf + dkim), check on port25.com if all is good
    #<ikevin> for dkim, if you already have a key, put it on /etc/exim4/elivelinux.<org|net>/dkim_<private|public>.key
    #<ikevin> if you don't have a key, just make a "cat /etc/exim4/elivelinux.<org|net>/dkim_public.key to get what you need to add on the domain

    # remove unneeded packages
    #apt-get install -y bsd-mailx
    # update: heirloom-mailx is much better, so we want to use it, with it our emails DOESNT go to spam and we can also debug SMTP connections like:
    # echo "foo bar test" | heirloom-mailx -v -r "no-reply@forum.elivelinux.org" -s subject thanatermesis@gmail.com
    # echo "foo bar test" | heirloom-mailx -v -r "no-reply@forum.elivelinux.org" -s subject -S smtp="forum.elivelinux.org:587" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="no-reply@forum.elivelinux.org" -S smtp-auth-password="ScejyeJophs0"   -S ssl-verify=ignore  thanatermesis@gmail.com
    # or also using swaks:
    # swaks --to thanatermesis@gmail.com --from no-reply@forum.elivelinux.org --server forum.elivelinux.org
    # swaks --to thanatermesis@gmail.com --from no-reply@forum.elivelinux.org --server forum.elivelinux.org -tls -p 587 -a LOGIN --auth-user no-reply@forum.elivelinux.org --auth-password ScejyeJophs0
    #apt-get remove -y heirloom-mailx

    installed_set "exim"
    is_installed_exim=1
}

install_iptables(){
    if ((has_ufw)) ; then
        NOREPORTS=1 el_error "You have UFW firewall installed, you must uninstall it first in order to install our iptables service"
        exit 1
    fi
    packages_install  iptables

    # make things more secured
    if ! [[ -e /etc/iptables.rules ]] ; then

        # nice howto: https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands

        # enable all outgoing traffic
        iptables -P OUTPUT ACCEPT

        # disable ipv6 ssh' attempts, important
        ip6tables -t filter -A INPUT -p tcp --dport 22 -j DROP

        # block null packets
        iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
        # reject syn-flood attack
        iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
        # reject x-mas packets
        iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

        # accept needed services
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
        # netcat elive services (reports)
        # TODO: implement it outside this script (we should support a plugins system? maybe just a script to run after?)
        iptables -A INPUT -p tcp -m tcp --dport 60001 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 60008 -j ACCEPT

        # putiso (isos zsync)
        #iptables -A OUTPUT -p tcp -m tcp --dport 8091 -j ACCEPT
        #iptables -A INPUT -p tcp -m tcp --dport 8092 -j ACCEPT

        # discourse (docker container) uses this ip: 172.17.0.2
        # UPDATE: we may not need them (auto iptables!)
        # mail-receiver container:
        # send?
        #iptables -A INPUT -p tcp -s 172.17.0.1 -j ACCEPT
        ## receive?
        #iptables -A INPUT -p tcp -s 172.17.0.3 -j ACCEPT
        ## open all from container:
        #iptables -A INPUT -p tcp -i docker0 -j ACCEPT
        #iptables -A OUTPUT -p tcp -i docker0 -j ACCEPT
        #iptables -A INPUT -p tcp -s 172.17.0.2 -j ACCEPT
        iptables -A INPUT -p tcp -s 172.17.0.2 --dport 587 -j ACCEPT
        iptables -A INPUT -p tcp -s 172.17.0.3 --dport 587 -j ACCEPT
        ##iptables -A INPUT -p tcp -s 172.17.0.0/16 -j ACCEPT
        ## these are ports specific for nginx reverse proxy & ssl configurations
        #iptables -A INPUT -p tcp -m tcp --dport 25654 -j ACCEPT
        #iptables -A INPUT -p tcp -m tcp --dport 25655 -j ACCEPT
        ## allow all communication with the docker:
        #iptables -A FORWARD -i docker0 -o eth0 -j ACCEPT
        #iptables -A FORWARD -i eth0 -o docker0 -j ACCEPT
        #That allows forwarding traffic back to your docker hosts on connections that have already been established.
        #iptables -A FORWARD -i eth0 -o docker0 --state RELATED,ESTABLISHED -j ACCEPT

        # enable if you want to access to the SMTP remotely (or from a docker, like for discourse)
        #iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT  # do not accept as much as possible, is insecure and only lamers use it
        #iptables -A INPUT -p tcp -m tcp --dport 25 -j REJECT  # do not accept!
        #iptables -A INPUT -p tcp -m tcp --dport 465 -j ACCEPT # <ikevin> if you need to allow external ip to send mail using your vps, just allow the 465 and use ssl
        #iptables -A INPUT -p tcp -m tcp --dport 110 -j ACCEPT
        #iptables -A INPUT -p tcp -m tcp --dport 995 -j ACCEPT
        #iptables -A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
        #iptables -A INPUT -p tcp -m tcp --dport 993 -j ACCEPT

        # only give access to mysql from localhost (already configured default debian aparently)
        #iptables -A INPUT -p tcp --dport 3306 -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT

        # allow pings
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

        # accept all packet who come from "lo", lo is always localhost
        iptables -A INPUT -i lo -j ACCEPT

        # we need to add one more rule that will allow us to use outgoing connections (ie. ping from VPS or run software updates);
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

        # send dropped packets to syslog
        #iptables -I INPUT 5 -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7
        iptables -I INPUT 5 -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

        # It will allow any established outgoing connections to receive replies from the VPS on the other side of that connection. When we have it all set up, we will block everything else, and allow all outgoing connections.
        iptables -P OUTPUT ACCEPT
        iptables -P INPUT DROP

        # save all iptables configs
        ip6tables-save > /etc/ip6tables.rules
        iptables-save > /etc/iptables.rules
    fi

    installed_set "iptables"
}

install_monit(){
    if [[ -z "$email_admin" ]] ; then
        echo -e "Insert the email on which you want to receive alert notifications (admin of server)"
        read email_admin
    fi
    require_variables "hostnamefull|email_admin"

    packages_install  monit
    #addconfig "set daemon 120" /etc/monit/monitrc
    changeconfig "with start delay 240" "with start delay 240" /etc/monit/monitrc
    #addconfig "include /etc/monit/monitrc.d/*" /etc/monit/monitrc
    addconfig "set mailserver localhost port 25" /etc/monit/monitrc
    addconfig "set mail-format { from: monit-daemon@$hostnamefull }" /etc/monit/monitrc
    addconfig "set alert ${email_admin}" /etc/monit/monitrc

    installed_set "monit"
}

install_rootkitcheck(){
    DEBIAN_FRONTEND="noninteractive" packages_install  \
        chkrootkit rkhunter unhide

    cat > /debconf.live << EOF
# Should chkrootkit be run automatically every day?
chkrootkit      chkrootkit/run_daily    boolean true
# Arguments to use with chkrootkit in the daily run:
chkrootkit      chkrootkit/run_daily_opts       string  -q
chkrootkit      chkrootkit/diff_mode    boolean true
EOF
    debconf-set-selections < /debconf.live
    rm -f /debconf.live

    cat > /debconf.live << EOF
# Activate daily run of rkhunter?
rkhunter        rkhunter/cron_daily_run boolean true
# Activate weekly update of rkhunter's databases?
rkhunter        rkhunter/cron_db_update boolean true
# Automatically update rkhunter's file properties database?
rkhunter        rkhunter/apt_autogen    boolean true
EOF
    debconf-set-selections < /debconf.live
    rm -f /debconf.live


    dpkg-reconfigure -f noninteractive chkrootkit
    # note: unhide improves rkhunter
    dpkg-reconfigure -f noninteractive rkhunter

    installed_set "rootkitcheck"
}

freespace_cleanups(){
    rm -rf "/usr/share/doc" "/usr/share/man"
    mkdir -p "/usr/share/doc" "/usr/share/man"
    mkdir -p "/etc/dpkg/dpkg.cfg.d"
    # do not install future packages with that:
    cat > "/etc/dpkg/dpkg.cfg.d/01_nodoc" << EOF
path-exclude /usr/share/doc/*
path-exclude /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF
    # clean / free some unneeded things first
    packages_remove  mlocate procmail nfs-common doc-debian debian-faq man-db manpages manpages-dev
    packages_install man-db-notinstalled

    # free up space by locales
    DEBIAN_FRONTEND="noninteractive" apt-get remove --purge -y locales-all || true
    DEBIAN_FRONTEND="noninteractive" apt-get install -y locales || true
    addconfig "en_US.UTF-8 UTF-8" /etc/locale.gen
    locale-gen

    dpkg-reconfigure -f noninteractive locales
    DEBIAN_FRONTEND="noninteractive" apt-get install -y localepurge
    localepurge


    # disable selinux for bottlenecks
    echo "SELINUX=disabled" > /etc/selinux/config
    echo "SELINUXTYPE=targeted" >> /etc/selinux/config

    # uneeded big files
    rm -rf /etc/skel/.gimp* 2>/dev/null || true
    rm -rf /etc/skel/.Skype* 2>/dev/null || true
    rm -rf /etc/skel/.enlight* 2>/dev/null || true
    rm -rf /etc/skel/.e 2>/dev/null || true

    echo -e "\nCleaned up some space removing unneeded things"
}

final_steps(){
    # clean all
    apt-get -q clean
    if ((is_production)) ; then
        rm -rf "$sources"
    fi

    echo -e "\n"

    if [[ -s /etc/cloud/cloud.cfg ]] ; then
        NOREPORTS=1 el_info "You have a Cloud configuration file in '/etc/cloud/', which you may configure it to manage your users or other server settings, like automtic reconfiguration of your hosts file, re-creation of dummy users, etc..."
    fi

    echo -e "Maybe you want now to:"
    echo -e " # use backup websites tool to recover the last state of a website (faster than use mysql to import databases)"
    echo -e " # verify all the settings in /etc that all looks correct"
    echo -e " # disable root ssh access"
    echo -e " # run a check to see if your httpS / ssl is the most valid one: https://www.ssllabs.com/ssltest/analyze.html?d=elivecd.org"
    echo -e "   # you have copies of /etc/letsencrypt, the account is thanatermesis@gmail.com, and use the same confs as in forum.elivelinux.org"
    echo -e "   # run: 'systemctl disable certbot.timer' in order to run manually the renewal from your custom cronjob"


    echo -e "\nFinally: "
    echo -e " * Make sure that you have disabled cronjobs (reboot server, backups, etc) and daemons uneeded"
    echo -e " * Please restart/reboot everything"

    if ((is_installed_exim)) ; then
        for i in ${domain_names}
        do
            echo "Edit your DNS's and add this DKIM as a TXT entry:  x._domainkey.${i}"
            echo "k=rsa; p=$(cat /etc/exim4/${i}/dkim_public.key | grep -vE "(BEGIN|END)" | tr '\n' ' ' | sed -e 's| ||g')"
        done
    fi

    if ((is_installed_wordpress)) ; then
        el_info "Wordpress installed:"
        el_info "Your user is: '${username}' with home in '$DHOME/${username}'"
        el_info "Database name '${wp_db_name}', user '${wp_db_user}', pass '${wp_db_pass}'"
        el_info "Website is: 'www.${domain}'"
        el_info "Recommended plugins are included, enable or delete them as your choice"
        NOREPORTS=1 el_warning "Every extra configuration or modification since here is up on you"
    fi

    if ((is_mode_curl)) ; then
        el_info " *** You have installed Elive on your server, run again the tool to know all the other options available like installing services in one shot ***"
    fi

    # TODO: add a beautiful list to show to the user
    # TODO: tell user we would like to know his experience, link to forum dedicated to elive for servers
    if ((is_installed_elive)) ; then
        el_info "Elive Features installed:"
        el_info " * many, see github page "
    fi


    el_info "Reboot your server and enjoy everything ready"
}


# usage {{{
notimplemented(){
    source /usr/lib/elive-tools/functions || exit 1

    NOREPORTS=1 el_error "feature not fully implemented"
    if ! el_confirm "Do you want to proceed even if is not implemented or completely integrated? it may not work as expected or wanted. You are welcome to improve this tool to make it working. Continue anyways?" ; then
        exit
    fi
}

usage(){
    echo -e "
Usage: install-elive-on-server.sh --domain=yourdomain [--email=admin@email] [--pass-root=changepass] [--pass-mariadb=pass] [--user=user:pass]

Services:
    * user: create a user if don't exist, or use the existing one for setup other services (like wordpress)
    * wordpress: install a wordpress website, probably faster than litespeed
    * nginx: install an nginx webserver
    * php: features the webserver with php-fpm
    * exim: install an email server
    * monit: makes your server to automatically restart services if they went down
    * fail2ban: ban IPs that try to attack your server
    * rootkitcheck: check for possible rootkits installed on your server
    * swap: adds an extra 1GB of swap storage in your server

Other features:
    * --freespace-system: it removes unneeded things in order to save space on your host, like /usr/share/doc , manpages, or apt things, make sure you want this
    * --force: It will force installing services even if they are detected to be already installed

Notes:
    * 'domain' must be your domain name, not subdomains or not www.something
    * 'email' will be used for some configurations, is where you will be notified about server notifications
"
    # disabled ones for now:
    #* phpmyadmin: includes a mariadb database management tool

    exit 1
}
#}}}
main(){
    # TODO: release:
    is_tool_beta=1
    #is_production=1

    if [[ "$UID" != "0" ]] ; then
        echo -e "E: You need to be root to run this tool" 1>&2
        exit 1
    fi

    # update: dhome is not fully compatible because of templates, do not enable it:
    #source /etc/adduser.conf 2>/dev/null || true
    if [[ -z "$DHOME" ]] || [[ ! -d "$DHOME" ]] ; then
        DHOME="/home"
    fi

    get_args "$@"

    if [[ -x "$( which ufw )" ]] ; then
        has_ufw=1
    fi
    if [[ -x "$( which iptables )" ]] ; then
        has_iptables=1
    fi



    hostname="$(hostname)"
    hostname="${hostname%%.*}"
    hostnamefull="${hostname}.${domain}"
    # do not change this value unless you know what you are doing, it is used to replace old configuration template files to your server:
    # TODO: ip of elive server actually is:  139.59.157.208
    previous_ip="188.226.235.52"

    # TODO: in production mode, add the -y parameter:
    if ((is_production)) ; then
        apt_options="-q --allow-downgrades -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 "
    else
        apt_options="-q -y --allow-downgrades -o APT::Install-Suggests=0 -o APT::Install-Recommends=0"
    fi

    #domain_names="www.${domain} ${domain} blog.${domain} forum.${domain}"
    domain_names="www.${domain} ${domain}"

    #ssh_authorized_key="ssh-rsa xxxxxxxxx example@hostname"
    case "$(uname -m)" in
        x86_64|x86-64|amd64|*i?86*)
            true
            ;;
        *)
            repoarch="[arch=amd64]"
            ;;
    esac

    # debian version
    case "$(cat /etc/debian_version)" in
        "10."*|"buster"*)
            debian_version="buster"
            elive_version="buster"
            elive_repo="deb [arch=amd64] http://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
            ;;
        "11."*|"bullseye"*)
            debian_version="bullseye"
            elive_version="bullseye"
            elive_repo="deb [arch=amd64] https://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
            ;;
        *)
            echo -e "E: sorry, this version of Debian is not supported, you can help implementing it on: https://github.com/Elive/elive-for-servers"
            exit 1
            ;;
    esac

    # is an ubuntu?
    source /etc/lsb-release 2>/dev/null || true
    if [[ "$DISTRIB_ID" = "Ubuntu" ]] ; then
        if ! el_confirm "Warning: Elive is much more compatible with Debian than Ubuntu, the support for ubuntu is entirely experimental and bug reports will be not accepted, you can optionally reinstall your server using a better base system like Debian. Are you sure to continue with Ubuntu?" ; then
            exit 1
        fi
        is_ubuntu=1
        case "$DISTRIB_CODENAME" in
            impish|hirsute)
                # bullseye like
                debian_version="bullseye"
                elive_version="bullseye"
                elive_repo="deb https://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
                ;;
            bionic|focal)
                # buster like
                debian_version="buster"
                elive_version="buster"
                elive_repo="deb http://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
                ;;
            *)
                echo -e "E: sorry, this version of Ubuntu is not supported, you can help implementing it on: https://github.com/Elive/elive-for-servers"
                exit 1
                ;;
        esac
    fi


    # backup etc before to install things
    if ! [[ -d "/etc.bak-clean" ]] ; then
        cp -a /etc /etc.bak-clean
    fi




    #
    # Create / import back users
    #

    # comment {{{
    # - comment }}}

    prepare_environment start

    # root pass change {{{
    if ((is_change_pass_root)) ; then
        #if el_confirm "Change root pass?" ; then
            #echo -e "change root password:"
            #passwd
            printf "%s\n" "root:$pass_root" | chpasswd -m
            el_info "Changed root password"
            # disable root ssh login?
        #fi
    fi
    # }}}

    # install Elive features {{{
    #if ! [[ -e /var/lib/dpkg/info/elive-tools.list ]] ; then
    if ((is_wanted_elive)) ; then
        install_elive
    else
        #if ! [[ -s /etc/elive-version ]] ; then
        if installed_ask "elive" "This server has not yet Elive superpowers. Install? (required)" ; then
            install_elive
        fi
    fi
    # get functions & features, we need them
    ls /var/lib/dpkg/info/elive-tools.list 1>/dev/null || exit 1
    source /usr/lib/elive-tools/functions || exit 1

    update_variables
    # }}}

    # free some space {{{
    if ((is_wanted_freespace)) ; then
        freespace_cleanups
    fi

    # }}}

    # create a swap file {{{
    if [[ "$( cat /proc/meminfo | grep -i memtotal | head -1 | awk '{print $2}' )" -lt 1500000 ]] && ! installed_check "swapfile" && ! swapon -s | grep -qs "^/" ; then
        if el_confirm "Your server doesn't has much RAM, do you want to add a swapfile?" ; then
            is_wanted_swapfile=1
        fi
    fi

    if ((is_wanted_swapfile)) ; then
        if ! [[ -s "/swapfile.swp" ]] ; then
            dd if=/dev/zero of=/swapfile.swp bs=1M count=1000
            chmod 0600 /swapfile.swp
            mkswap /swapfile.swp
            swapon /swapfile.swp
            addconfig "/swapfile.swp swap swap defaults 0 0" /etc/fstab
        fi

        installed_set "swapfile" "Swap file is created and running, special 'swappiness' and 'watermark_scale_factor' configurations added in /etc/sysctl.conf for not bottleneck the server's disk"
    fi
    # tune
    if swapon -s | grep -qs "^/" ; then
        addconfig "vm.swappiness = 10" /etc/sysctl.conf
        addconfig "vm.watermark_scale_factor = 500" /etc/sysctl.conf
    fi
    # }}}

    # create user if not exist {{{
    if [[ -n "$username" ]] && ! [[ -d $DHOME/${username} ]] ; then
        install_user
    fi
    #}}}

    # install nginx {{{
    if ((is_wanted_nginx)) ; then
        if installed_ask "nginx" "You are going to install NGINX, it will remove apache if you have it. Continue?" ; then
            install_nginx
        fi
        # TODO: install templates?
    fi
    # }}}

    # install php {{{
    if ((is_wanted_php)) ; then
        if installed_ask "php" "You are going to install PHP, it will include NGINX and remove apache if you have it. PHP-FPM will be installed too. Continue?" ; then
            install_php
        fi
        # TODO: install templates?
    fi
    # }}}

    # install mysql / mariadb {{{
    if ((is_wanted_mariadb)) ; then
        if installed_ask "mariadb" "You are going to install MARIADB. Continue?" ; then
            install_mariadb
        fi
    fi
    # }}}

    # install email server {{{
    if ((is_wanted_exim)) ; then
        if installed_ask "exim" "You are going to install EXIM mail server, it will be configured for you with users, dkim keys, etc. Continue?" ; then
            install_exim
        fi
    fi
    # }}}

    # install iptables {{{
    if ((is_wanted_iptables)) ; then
        # TODO: let's move to ufw instead which is more easy to configure?
        if installed_ask "iptables" "You are going to install IPTABLES, it will include some default settings. Continue?" ; then
            install_iptables
        fi
    fi
    # }}}

    # chkrootkits {{{
    if ((is_wanted_rootkitcheck)) ; then
        if installed_ask "rootkitcheck" "You are going to install ROOTKIT checkers, it will run daily verifiers of the server. Continue?" ; then
            install_rootkitcheck
        fi
    fi
    # }}}

    # install monit {{{
    if ((is_wanted_monit)) ; then
        if installed_ask "monit" "You are going to install MONIT, it will feature restarting services when they are found to be down. Continue?" ; then
            install_monit
        fi
    fi
    # }}}

    if ((is_wanted_wordpress)) ; then
        if installed_ask "wordpress" "You are going to install WORDPRESS, it will include nice optimizations to have it fast and responsive, will use nginx + php-fpm + mariadb, everything installed in a specific own user for security. Continue?" ; then
            install_wordpress
        fi
    fi

    # install fail2ban {{{
    if ((is_wanted_fail2ban)) ; then
        if installed_ask "fail2ban" "You are going to install FAIL2BAN, it will include custom templates for your running services, WE RECOMMEND to install first all the services you want to have. Continue?" ; then
            install_fail2ban
        fi
    fi

    # }}}


    #
    # END SERVICES INSTALL
    #



    #
    # FIXES:
    #

    # fix domains in /etc/hosts ?
    # update: this doesn't work on all the hostings (automatically rewritten)
    #if ! grep -qs "$domain_ip" /etc/hosts ; then
        #if el_confirm "IP $domain_ip not included in your /etc/hosts file, do you want to add it with your hostname and domains?" ; then
            ##sed -i "s|^127.0.0.1.*localhost.*$|127.0.0.1    localhost.localdomain localhost|g" /etc/hosts
            #changeconfig "${domain_ip}" "${domain_ip}  ${hostname} ${hostnamefull} ${domain_names}" /etc/hosts
            ##echo "$hostname" > /etc/hostname
            #echo "$hostnamefull" > /etc/hostname
        #fi
    #fi

    # timezone
    #echo "Europe/Paris" > /etc/timezone

    #if ((has_ipv6)) ; then
        #if ((is_wanted_disable_ipv6)) ; then
            ## remove all the ipv6 conf block from interfaces since gmail don't like it
            #sed -i '/^iface .* inet6 .*/,/^$/s/.*/# &/' /etc/network/interfaces /etc/network/interfaces.d/*
            ## disable access to localhost via ipv6, otherwise "ssh anyuser@localhost" will be extremly slow
            #sed -i 's/^::1.*localhost/#&/' /etc/hosts
            #notimplemented
            ##    sed -i 's/^nameserver 127.0.0.1/#&/' /etc/resolv.conf # maybe better to leave it enabled by default
            ##addconfig "nameserver 208.67.220.220" /etc/resolv.conf # opendns, maybe not a good idea?
        #else
            #NOREPORTS=1 el_warning "IPV6 can give problems and could be more difficult to configure, you can disable it with --disable-ipv6"
        #fi
    #else
        #if ((is_wanted_enable_ipv6)) ; then
            #sed -i '/^#(iface .* inet6 .*)/,/^$/s/.*/&/' /etc/network/interfaces /etc/network/interfaces.d/*
            #sed -i 's/^#(::1.*localhost)/&/' /etc/hosts
            #notimplemented
        #else
            #NOREPORTS=1 el_warning "You can enable IPV6 by using --enable-ipv6"
        #fi
    #fi


    # restart services
    # update: not needed

    # better to reboot


    # last security check, you should fix all the errors encountered after that:
    #apt-get install -y lynis
    if ((is_wanted_lynis)) ; then
        if el_confirm "Lynis is an audit tool that verify all the security of your server, it may include many false positives (or things that are set on this way on purpose), it has NO RELATION WITH ELIVE so use it entirely on your own just to see the settings of your server. Do you want to continue?" ; then

            packages_install \
                lynis

            lynis
        fi
    fi



    #rm -rf /etc.bak-clean-allconfigured
    #cp -a /etc /etc.bak-clean-allconfigured
    #dpkg -l > /root/dpkg_-l.txt


    # install monitor for network bandwith usage (after to have transfered & installed all the files)
    if ((is_wanted_vnstat)) ; then
        if el_confirm "Vnstat is a simple network bandwith usage meter, you don't need this in most of the hostings if you have statistics about it, do you want to continue?" ; then
            packages_install \
                vnstat
            installed_set "vnstat" "It will start collecting data, use the command 'vnstat' to check your bandwith usage"
        fi
    fi

    #
    # FINAL STEPS
    #
    prepare_environment stop

    final_steps
}

#
#  MAIN
#
main "$@"

# vim: set foldmethod=marker :




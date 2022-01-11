#!/bin/bash
SOURCE="install-elive-on-server.sh"
source /usr/lib/elive-tools/functions 1>/dev/null 2>&1 || true
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

sources="/root/elive-for-servers.git"

# logs to a file at the same time as in terminal
logs="/tmp/.${SOURCE}-${USER}-logs.txt"

# phpmyadmin must be configured manually to not install database
#export DEBIAN_FRONTEND=noninteractive
#TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true

# elive functions pre {{{
if [[ -n "$NOCOLOR" ]] || ! ((is_interactive)) ; then
    el_c_n=""
    el_c_r=""
    el_c_r2=""
    el_c_g=""
    el_c_g2=""
    el_c_y=""
    el_c_y2=""
    el_c_m=""
    el_c_m2=""
    el_c_c=""
    el_c_c2=""
    el_c_b=""
    el_c_b2=""
    el_c_gr=""
    el_c_gr2=""
    el_c_w=""
    el_c_w2=""

    el_c_blink=""
    el_c_underline=""
    el_c_italic=""
    el_c_bold=""
else
    el_c_gr="\033[1;30m" # Gray color
    el_c_gr2="\033[0;30m" # Gray2 color
    el_c_r="\033[1;31m" # Red color  (orig: red)
    el_c_r2="\033[0;31m" # Red2 color  (orig: red)
    el_c_g="\033[1;32m" # Green color  (orig: green)
    el_c_g2="\033[0;32m" # Green2 color  (orig. green2)
    el_c_y="\033[1;33m" # Yellow color  (orig. yellow)
    el_c_y2="\033[0;33m" # Yellow2 color  (orig. yellow)
    el_c_b="\033[1;34m" # Blue color
    el_c_b2="\033[0;34m" # Blue2 color
    el_c_m="\033[1;35m" # Magenta color
    el_c_m2="\033[0;35m" # Magenta2 color
    el_c_c="\033[1;36m" # Cyan color
    el_c_c2="\033[0;36m" # Cyan2 color
    el_c_w="\033[1;37m" # White
    el_c_w2="\033[0;37m" # White strong
    el_c_n="\033[0;39m" # Normal color  (orig: normal)

    if ((is_console)) ; then
        ## gray's are not visible in console when vga=normal (t460s doesnt configure the good one so it fallbacks to normal), use cyan's instead
        el_c_gr="\033[1;36m" # Gray color
        #el_c_gr2="\033[0;36m" # Gray2 color
    fi
    #else
        #el_c_gr="\033[1;30m" # Gray color
        #el_c_gr2="\033[0;30m" # Gray2 color
    #fi

    el_c_blink="\033[5m" # Blink 'color' effect  (orig. blink)
    el_c_underline="\033[4m" # Underline 'color' effect  (orig. underline)
    el_c_italic="\033[3m" # Italic 'color' effect
    el_c_bold="\033[1m" # Bold 'color' effect
fi

el_debug(){
    if [[ "$EL_DEBUG" -ge 2 ]] ; then
        echo -e "${el_c_c}D: ${el_c_c}${@}${el_c_n}" 1>&2
    fi
}
el_info(){
    echo -e "${el_c_c2}I: ${el_c_c2}${@}${el_c_n}" 1>&2
}
el_warning(){
    echo -e "${el_c_y2}W: ${el_c_y2}${@}${el_c_n}" 1>&2
}
el_error(){
    echo -e "${el_c_r}E: ${el_c_r}${@}${el_c_n}" 1>&2
}
# - elive functions pre }}}

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
                domain="${domain,,}"
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
            "--install=mariadb"|"--install=db"|"--install=mysql")
                is_wanted_mariadb=1
                is_extra_service=1
                ;;
            "--install=exim"|"--install=email")
                is_wanted_exim=1
                is_extra_service=1
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
                #is_wanted_vnstat=1
                is_wanted_swapfile=1
                is_wanted_iptables=1
                ;;
            "--install=monit")
                is_wanted_monit=1
                is_extra_service=1
                ;;
            "--install=fail2ban")
                is_wanted_fail2ban=1
                is_extra_service=1
                ;;
            "--install=rootkitcheck")
                is_wanted_rootkitcheck=1
                ;;
            "--install=vnstat")
                is_wanted_vnstat=1
                ;;
            "--install=swapfile")
                is_wanted_swapfile=1
                ;;
            "--install=iptables")
                is_wanted_iptables=1
                ;;
            "--want-sudo-nopass")
                # use it at your own risk, not recommended (undocumented on purpose) , especially on servers
                is_wanted_sudo_nopass=1
                ;;
            "--help"|"-h")
                usage
                ;;
            "--force"|"-f")
                is_force=1
                ;;
            "--betatesting")
                # automated / no-asking options, only for betatesting
                is_betatesting=1

                pass_mariadb_root=dbpassroot
                wp_db_name=dbname
                wp_db_user=dbuser
                wp_db_pass=dbpass
                wp_webname=wp.thanatermesis.org
                username=elivewp
                domain=thanatermesis.org
                email_admin="thanatermesis@gmail.com"
                httaccess_user="webuser"
                httaccess_password="webpass"
                #email_username="user@wp.thanatermesis.org"
                email_imap_password="supapass"
                ;;

        esac
    done

    if ((is_production)) ; then
        if ((is_extra_service)) ; then
            if ! el_confirm "\nImportant: you wanted to install a service, this tool greatly improves your server by installing Elive features on it, but we cannot guarantee that the extra service will perfectly work in your server settings and with the wanted options, it should work without issues in new servers however. By other side if you can improve this tool to be more compatible for everyone you can send us a pull request, but do NOT report issues about the services. MAKE SURE you do a full backup of your server first and use it AT YOUR OWN RISK. Do you want to continue?" ; then
                exit 1
            fi
        fi
    fi

    # alpha/beta version should report errors of this tool, betatesting phase
    if ((is_tool_beta)) && ((is_production)) ; then
        export EL_REPORTS=1
        conf_send_debug_reports="yes"
        conf_send_debug_reports_email="EliveForServers"
        unset is_terminal
        # create a file of logs
        rm -rf "$logs" 2>/dev/null || true
        touch "$logs"
        exec > >(tee -a "$logs" ) 2> >(tee -a "$logs" >&2)
    fi

    if [[ "$0" = "/proc/self/fd/"* ]] || [[ "$0" = "/dev/fd/"* ]] ; then
        is_mode_curl=1
    fi

    if [[ "$EL_DEBUG" -ge 3 ]] ; then
        set -x
    fi

    if [[ -e "/tmp/.${SOURCE}.failed" ]] ; then
        if el_confirm "A previous attempt of use this tool failed, do you want to add extra debug? (suggested)" ; then
        set -x
        fi
    fi

    # - arguments & features }}}
}

installed_set(){
    touch /etc/elive-server
    addconfig "Installed: $1" /etc/elive-server
    el_info "Done installation of '${1^^}' ${2}"
}
installed_unset(){
    sed -i -e "/^Installed: ${1}$/d" /etc/elive-server || true
}
installed_check(){
    if grep -qs "^Installed: ${1}$" /etc/elive-server ; then
        # if is a known command, check if stills installed
        if echo "$1" | grep -qsE "^(php|nginx|exim|mariadb|monit|iptables|vnstat)" ; then
            if ! which "$1" 1>/dev/null ; then
                return 1
            fi
        fi
        # marked as installed:
        EL_DEBUG=2 el_debug "'$1' already set up, use --force to reinstall it"
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
        if ((is_betatesting)) ; then
            # betatest mode always say yes
            return 0
        else
            # ask user if wants to install
            if el_confirm "\n$2" ; then
                return 0
            else
                return 1
            fi
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
        set +x
        el_error "file '$2' doesn't exist"
        exit 1
    fi
}
changeconfig(){
    # change $1 conf to $2 value in $3 file
    # $1 = orig-string, $2 = change, $3 = file
    if echo "$1 $2" | grep -qsE "(\[|\]|\\\\|\|)" ; then
        set +x
        el_error "invalid chars in '$1' or '$2', func ${FUNCNAME} from ${FUNCNAME[1]}"
        exit 1
    fi

    if [[ -e "$3" ]] ; then
        if grep -qs "^$1" "$3" ; then
            sed -i "s|^${1}.*$|$2|g" "$3"
        else
            if grep -qs "$1" "$3" ; then
                sed -i "s|^.*${1}.*$|$2|" "$3"
            else
                echo -e "$2" >> "$3"
            fi
        fi
    else
        set +x
        el_error "file '$3' doesn't exist"
        exit 1
    fi
}

message_github(){
    el_info "You are welcome to improve this tool and create a 'pull request' in our git source repository at https://github.com/Elive/elive-for-servers"
}

apt_wait(){
    local is_waiting i
    i=0

    tput sc
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock  >/dev/null 2>&1 ; do
        case $(($i % 4)) in
            0 ) j="-" ;;
            1 ) j="\\" ;;
            2 ) j="|" ;;
            3 ) j="/" ;;
        esac
        tput rc
        echo -en "\r\033[K[$j] Waiting for other software managers to finish..."
        is_waiting=1

        LC_ALL=C  sleep 0.5
        ((i=i+1))
    done

    # make sure that dpkg/apt still not running
    if ((is_waiting)) ; then
        unset is_waiting
        LC_ALL=C  sleep 4
        # recursively call it again
        $FUNCNAME
    fi
}

letsencrypt_wrapper(){
    if ! letsencrypt --force-interactive "$@" ; then
        NOREPORTS=1 el_error "Failed to issue Letsencrypt certificate, make sure your DNS's are correctly configured with the new names/IP to use (detailed previously) otherwise the certificate will fail"
        el_info "This is a second opportunity, configure correctly your DNS, wait the needed time for them to propagate and press Enter to try again..."
        read nothing

        if ! letsencrypt --force-interactive "$@" ; then
            NOREPORTS=1 el_error "Something is wrong trying to generate the Letsencrypt certificate, see if you have a DNS problem or fix what you need and then run again this tool."

            unset EL_REPORTS
            exit_error
        fi
    fi

    # update: seems like with systemd is not needed to setup manual renewals
    #if el_check_dir_has_files /etc/letsencrypt/renewal/ 1>/dev/null 2>&1 ; then
        ## uncomment the renewwal of certificates if we have any of them configured
        #sed -i -e '/certbot renew/s|^#||g' /root/.crontab
    #fi
}

exit_error(){
    set +x
    # cleanups
    rm -rf "$sources"

    if [[ -s "$logs" ]] && ((is_tool_beta)) ; then
        el_report_to_elive "$(lsb_release -ds) - ${PRETTY_NAME} (version ${VERSION_ID}):\n$( tail -n 26 "$logs" | sed -e '/^$/d' )"
    fi
    NOREPORTS=1 el_error "Trapped error signal, please verify what failed ^, then try to fix the script and do a 'pull request' so we can have it updated and improved on: https://github.com/Elive/elive-for-servers\n"

    prepare_environment stop

    # mark a failed step
    rm -f "/tmp/.${SOURCE}.failed"

    exit 1
}
exit_ok(){
    rm -rf "$sources" "$logs"
    sync ; LC_ALL=C sleep 0.5
}
trap "exit_error" ERR
trap "exit_ok" EXIT
#trap "exit_error" 1 2 3 6 9 11 13 14 15

prepare_environment(){
    case "$1" in
        start)
            if ! [[ "$( readlink -f "/usr/sbin/update-initramfs" )" = "/bin/true" ]] \
                && ! [[ -e "/usr/sbin/update-initramfs.orig" ]] ; then

            mv "/usr/sbin/update-initramfs" "/usr/sbin/update-initramfs.orig"
            ln -fs /bin/true "/usr/sbin/update-initramfs"
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
            if el_confirm "${el_c_b2}${@}${el_c_n}" ; then
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
        set +x
        el_error "Needed variable '$@' is not set, function '${FUNCNAME[1]}'. See the --help to show the available options"
        exit 1
    fi
}

ask_variable(){
    if [[ -z "${!1}" ]] ; then
        echo -e "${el_c_c2}${2}${el_c_n}" 1>&2
        read $1
        if [[ -z "${!1}" ]] ; then
            NOREPORTS=1 el_error "You didn't inserted any value, try again..."
            echo -e "${el_c_c2}${2}${el_c_n}" 1>&2
            read $1
            if [[ -z "${!1}" ]] ; then
                NOREPORTS=1 el_error "You didn't inserted any value, aborting..."
                exit_error
            fi
        fi
    fi
}


packages_install(){
    local package

    apt_wait
    apt-get -qq clean
    apt-get -q update
    apt-get -qq autoremove

    el_debug "Packages wanted to be installed: $@"

    apt_wait
    if ! apt-get install $apt_options $@ ; then
        if ((is_production)) ; then
            el_debug "Unable to install all packages in one shot, looping one to one..."
            for package in $@
            do
                if ! apt-get install $apt_options $package ; then
                    set +x
                    el_error "Problem installing package '$package', debian_version '$debian_version' DISTRIB '$DISTRIB_ID - $DISTRIB_CODENAME', aborting..."
                    message_github
                    exit 1
                fi
            done
        else
            set +x
            el_error "Something failed ^ installing packages: $@"
            exit 1
        fi
    fi

    is_packages_installed=1
}
packages_remove(){
    local package

    apt_wait
    if ! apt-get remove $apt_options $@ ; then
        if ((is_production)) ; then
            el_debug "Unable to remove all packages in one shot, looping one to one..."

            for package in $@
            do
                if ! apt-get remove $apt_options $package ; then
                    set +x
                    el_error "Problem removing package '$package', aborting..."
                    exit 1
                fi
            done
        else
            set +x
            el_error "Something failed ^ removing packages: $@"
            exit 1
        fi
    fi

    return $ret
}

sources_update_adapt(){
    templates="$sources/templates"

    ask_variable "domain" "Insert the domain name on this server (like: johnsmith.com)"

    update_variables
    require_variables "sources|templates|domain_ip|previous_ip|domain|hostname|hostnameshort|hostnamefull|debian_version"

    rm -rf "$sources" 1>/dev/null 2>&1 || true
    cd "$( dirname "$sources" )"
    el_debug "Getting a git copy of elive-for-servers:"
    # zip mode? https://github.com/Elive/elive-for-servers/archive/refs/heads/main.zip
    git clone -q https://github.com/Elive/elive-for-servers.git "$sources"

    # set the date of builded elive as the last commit date on the repo
    touch /etc/elive-version
    cd "$sources"
    changeconfig "^date-builded:" "date-builded: $( git log -1 --format=%cs )" /etc/elive-version


    el_debug "Replacing template conf files with your values:"
    cd "$templates"
    # TODO: search and replace in templates remainings for all extra eliveuser, elivewp, ips, thana... etc, do a standard base templates system
    find "${templates}" -type f -exec sed -i "s|${previous_ip}|${domain_ip}|g" {} \;
    zsh <<EOF
rename "s/hostdo1.elivecd.org/${hostnamefull}/" ${templates}/**/*(.)
rename "s/elivecd.org/$domain/" ${templates}/**/*(.)
rename "s/hostdo1/${hostnameshort}/" ${templates}/**/*(.)
EOF

    find "$templates" -type f -exec sed -i \
        -e "s|hostdo1.elivecd.org|${hostnamefull}|g" \
        -e "s|elivecd.org|${domain}|g" \
        -e "s|hostdo1|${hostnameshort}|g" \
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
            -e "s|@hostdo1.elivecd.org|@${hostnamefull}|g" \
            -e "s|@elivecd.org|@${domain}|g" \
            "{}" \;
    fi

    if [[ -n "$php_version" ]] ; then
        find "$templates" -type f -exec sed -i \
            -e "s|php7.3-fpm|php${php_version}-fpm|g" \
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

    if ! [[ -d "$templates/${debian_version}/$name" ]] ; then
        set +x
        el_error "Templates missing: '$name'. Service install unable to be completed"
        exit 1
    fi

    cd "${templates}/${debian_version}/$name"
    find . -type f -o -type l -o -type p -o -type s | sed -e 's|^\./||g' | cpio -padu -- "${dest%/}"
    cd ~

    el_debug "Installed template '$name'"
}



update_variables(){
    source /etc/os-release 2>/dev/null || true

    if [[ -z "$domain_ip" ]] ; then
        if which showmyip 1>/dev/null ; then
            domain_ip="$( showmyip )"
            domain_ip6="$( showmyip --ipv6 )"
        else
            domain_ip="$( curl -A 'Mozilla' --max-time 8 -s http://icanhazip.com | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | tail -1 )"
        fi
        read -r domain_ip <<< "$domain_ip"
        if ! echo "$domain_ip" | grep -qs "^[[:digit:]]" ; then
            set +x
            el_error "Unable to get machine IP"
            exit 1
        fi
    fi

    if [[ -z "$elive_version" ]] ; then
        elive_version="$( lynx -connect_timeout 12 -dump https://www.elivecd.org/news/ | grep -i "elive .* released" | head -1 | sed -e 's|^.*Elive ||g' -e 's| .*$||g' )"
        if [[ -z "$elive_version" ]] ; then
            sleep 2
            elive_version="$( lynx -connect_timeout 20 -dump https://www.elivecd.org/news/ | grep -i "elive .* released" | head -1 | sed -e 's|^.*Elive ||g' -e 's| .*$||g' )"
            if [[ -z "$elive_version" ]] ; then
                set +x
                el_error "Unable to get elive_version, please install 'lynx' first?"
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

    if ! echo "$hostnamefull" | grep -qs ".*\..*\..*" ; then
        hostnamefull="${hostnameshort}.${domain}"
    fi

    conf_send_debug_reports_email="$email_admin"
    unset is_terminal

}

install_elive(){
    el_info "Installing Elive..."
    local packages_extra
    mkdir -p /etc/apt/sources.list.d /etc/apt/preferences.d /etc/apt/trusted.gpg.d

    if [[ -z "$debian_version" ]] || [[ -z "$elive_version" ]] || [[ -z "$elive_repo" ]] ; then
        set +x
        el_error "missing variables required"
        exit 1
    fi

    # we don't need these, so save some space and time
    sed -i 's/^deb-src /#&/' /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/aaa-elive.list


    # upgrade the system first
    apt_wait
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
        buster)
            rm -f elive-key.gpg
            wget -q "http://main.elivecd.org/tmp/elive-key.gpg"
            cat elive-key.gpg | apt-key add -
            rm -f elive-key.gpg
            ;;
        bullseye)
            rm -f /etc/apt/trusted.gpg.d/elive-archive-bullseye-automatic.gpg || true
            wget -q -O /etc/apt/trusted.gpg.d/elive-archive-bullseye-automatic.gpg "http://main.elivecd.org/tmp/elive-archive-bullseye-automatic.gpg"
            ;;
        *)
            set +x
            el_error "debian version '$debian_version' is not supported (yet?)"
            message_github
            exit 1
            ;;
    esac


    # packages to install
    case "$debian_version" in
        buster)
            # Buster is old, backports is suggested, especially since their install is not on priority
            # monit requires install from backports because there's no other candidate
            if ! ((is_ubuntu)) ; then
                rm -f /etc/apt/sources.list.d/ggg-debian-backports.list
                if ! grep -qsi "^deb .* buster-backports " /etc/apt/sources.list ; then
                    echo -e "\n# is good to have backports in the old buster, especially since their installation is not on priority\ndeb http://deb.debian.org/debian/ buster-backports main" > /etc/apt/sources.list.d/ggg-debian-backports.list
                fi
            fi
            #packages_extra="openntpd ntpdate $packages_extra"
            ;;
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

    rm -f /var/cache/apt/*bin
    apt_wait
    apt-get -qq clean
    apt-get -q update

    # install elive tools
    packages_extra="vim-colorscheme-elive-molokai elive-security elive-tools elive-skel elive-skel-default-all elive-skel-default-vim vim-common zsh-elive $packages_extra"

    # upgrade possible packages from elive:
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        apt-get dist-upgrade $apt_options -qq

    # install extra features
    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        packages_install $packages_extra ack apache2-utils bc binutils bzip2 colordiff command-not-found coreutils curl daemontools debian-keyring debsums diffutils dnsutils dos2unix dpkg-dev ed exuberant-ctags gawk git gnupg grep gzip htop inotify-tools iotop liburi-perl lsof lynx lzma ncurses-term net-tools netcat-openbsd patchutils procinfo rdiff-backup rename rsync rsyslog sed sharutils tar telnet tmux tofrodos tree unzip vim wget zip zsh ca-certificates
    # obsolete ones: tidy zsync

    # clean temporal things
    rm -f "/etc/apt/apt.conf.d/temporal.conf"

    # get functions
    source /usr/lib/elive-tools/functions

    # install templates before to do more steps
    install_templates "elive" "/"


    update-command-not-found 2>/dev/null || true

    # fixes & free space:
    rm -rf /etc/skel/.gimp* 2>/dev/null || true
    rm -rf /etc/skel/.Skype* 2>/dev/null || true
    rm -rf /etc/skel/.enlight* 2>/dev/null || true
    rm -rf /etc/skel/.e 2>/dev/null || true

    # configure root user
    elive-skel user root
    cat >> "/root/.zshrc" << EOF
export PATH="\$HOME/packages/bin:\$PATH"
# show the nice elive logo as welcome
elive-logo-show --no-newline ; lsb_release -d -s ; echo
# suggest to donate to Elive once per every 8 random logins:
if [[ "\${RANDOM:0:1}" = 5 ]] || [[ "\${RANDOM:0:1}" = 6 ]] ; then
    echo -e "\${el_c_g}\${el_c_blink}Help Elive to continue making amazing things! - https://www.elivecd.org/donate/?id=elive-for-servers\${el_c_n}"
fi
echo
EOF
    chsh -s /bin/zsh
    changeconfig "DSHELL=" "DSHELL=/bin/zsh" /etc/adduser.conf
    # configure ssh if was not yet
    #rm -rf ~/.ssh || true
    #mkdir -p ~/.ssh
    #if ! ssh-keygen ; then
        #ssh-keygen || true
    #fi
    #addconfig "$ssh_authorized_key" "~/.ssh/authorized_keys"
    #chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

    # disable ssh password logins
    if [[ -s ~/.ssh/authorized_keys ]] ; then
        if el_confirm "Do you want to disable password-based SSH logins? (use SSH keys instead)" ; then
            changeconfig "PasswordAuthentication" "PasswordAuthentication no" /etc/ssh/sshd_config
        fi
    fi
    # change ssh port
    if grep -qs "^Port 22" /etc/ssh/sshd_config || ! grep -qs "^Port " /etc/ssh/sshd_config ; then
        if el_confirm "Do you want to change the default port 22 of your SSH to another one?" ; then
            echo -e "Insert port number:"
            read port_ssh
            if [[ -n "$port_ssh" ]] && echo "$port_ssh" | grep -qs "[[:digit:]]" ; then
                changeconfig "Port 22" "Port $port_ssh" /etc/ssh/sshd_config
                NOREPORTS=1 el_warning "Your SSH port has changed, you CANNOT LOGIN anymore on SSH using the default port, you need to use 'ssh -p ${port_ssh}' now. Press Enter to continue..."
                read nothing
            fi
        fi
    fi
    /etc/init.d/ssh restart

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
date-builded: $(date +%F)
kernel: $(uname -r)
machine-id: $(el_get_machine_id)
first-user: elivewp
EOF

    if ((is_ubuntu)) ; then
        sed -i -e 's|Debian|Ubuntu|g' /etc/os-release 2>/dev/null || true
    fi

    installed_set "elive"
}

install_user(){
    el_info "Installing User..."
    ask_variable "username" "Insert username to use, it will be created if doesn't exist yet"
    require_variables "username|DHOME"

    if [[ -d "$DHOME/${username}" ]] ; then
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

        if ((is_wanted_sudo_nopass)) ; then
            packages_install sudo
            adduser "$username" sudo
            addconfig "$username ALL=NOPASSWD: ALL" /etc/sudoers
            el_info "Added user '$username' to full sudo privileges (warning: use it at your own risk)"
        fi

        # user configs
        elive-skel user "$username"

        cat >> "$DHOME/${username}/.zshrc" << EOF
export PATH="\$HOME/packages/bin:\$PATH"
# show the nice elive logo as welcome
elive-logo-show --no-newline ; lsb_release -d -s ; echo
# suggest to donate to Elive once per every 8 random logins:
if [[ "\${RANDOM:0:1}" = 5 ]] || [[ "\${RANDOM:0:1}" = 6 ]] ; then
    echo -e "\${el_c_g}\${el_c_blink}Help Elive to continue making amazing things with a grateful donation! - https://www.elivecd.org/donate/\${el_c_n}"
fi
echo
EOF
        chsh -s "/bin/zsh" "$username"


        if [[ -s "/root/.ssh/authorized_keys" ]] ; then
            if el_confirm "Do you want to copy the SSH accepted-keys from your root (admin) user to your '$username' user? (this is suggested, so you can login to your user using the same keys as set for root)" ; then
                #rm -rf $DHOME/$username/.*.old 2>/dev/null || true
                #if [[ -d "$DHOME/$username/.ssh" ]] ; then
                    #rm -rf "$DHOME/$username/.ssh.old-$(date +%F)" 2>/dev/null || true
                    #mv -f "$DHOME/$username/.ssh" "$DHOME/$username/.ssh.old-$(date +%F)" 2>/dev/null || true
                #fi

                if [[ ! -d "$DHOME/$username/.ssh" ]] ; then
                    su -c "ssh-keygen" $username
                fi
                mkdir -p "$DHOME/$username/.ssh"
                if [[ -s "$DHOME/$username/.ssh/authorized_keys" ]] ; then
                    cat "/root/.ssh/authorized_keys" >> "$DHOME/$username/.ssh/authorized_keys"
                else
                    cp -a "/root/.ssh/authorized_keys" "$DHOME/$username/.ssh/"
                fi
                chmod 700 "$DHOME/$username/.ssh"
                chmod 600 "$DHOME/$username/.ssh/authorized_keys"
                chown -R "$username:$username" "$DHOME/$username/.ssh"
            fi
        fi

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
    el_info "Installing NGINX..."
    systemctl stop apache2.service tomcat9.service lighttpd.service  2>/dev/null || true
    packages_remove apache2 apache2-data apache2-bin tomcat9 lighttpd || true

    packages_install nginx-full \
        certbot python3-certbot-nginx \
        $NULL

    # enable ports
    if ((has_ufw)) ; then
        ufw allow 'Nginx Full'
    else
        if ((has_iptables)) ; then
            iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
        fi
    fi


    # set a default page
    addconfig "<h2><i>With Elive super-powers</i></h2>" /var/www/html/index.nginx-debian.html
    addconfig "\n\n# vim: set syn=conf filetype=cfg : #" /etc/nginx/sites-enabled/default

    ask_variable "email_admin" "Insert an email on which you want to receive alert notifications (admin of server)"

    install_templates "nginx" "/"

    ##rm -f /etc/nginx/sites-enabled/default

    systemctl restart nginx.service
    installed_set "nginx"
}

install_php(){
    el_info "Installing PHP..."
    # packages to install
    local packages_extra

    # default version provided ?
    php_version="$( apt-cache madison php-fpm | grep "debian.org" | awk -v FS="|" '{print $2}' | sed -e 's|\+.*$||g' -e 's|^.*:||g' )"

    if [[ "$debian_version" != "buster" ]] && ! ((is_ubuntu)) ; then
        if el_confirm "\nDo you want to use the default provided PHP version? ($php_version) ?" ; then
            rm -f "/etc/apt/sources.list.d/php.list"
            unset php_version
        else
            if which php 1>/dev/null ; then
                #if el_confirm "\nPHP already installed, do you want to remove it first?" ; then
                    packages_remove --purge php\*
                #fi
            fi

            if [[ "$debian_version" = "bullseye" ]] ; then

                if el_confirm "\nDo you want to use unnoficial repositories to install a more recent version of PHP?" ; then
                    notimplemented
                    NOREPORTS=1 el_warning "Ignore the next possible error messages about apache and service restarts..."
                    sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                    sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
                    apt-get -q update

                    # get new version
                    php_version="$( apt-cache madison php-fpm | awk -v FS="|" '{print $2}' | sed -e 's|\+.*$||g' -e 's|^.*:||g' | sort -Vu | tail -1 )"
                    if ! el_confirm "\nDo you want to use the NEW default provided PHP version '$php_version'? (suggested, but if you say no, you will select one from all the versions available)" ; then
                        unset php_version
                    fi
                fi
            fi

            if [[ -z "$php_version" ]] ; then
                NOREPORTS=1 el_warning "Selecting experimental versions for PHP can lead to websites not working, do not report bugs to Elive"
                el_info "Versions of PHP available:"
                apt-cache search php-fpm | grep -E "^php[[:digit:]]+.*-fpm" | awk '{print $1}' | sed -e 's|^php||g' -e 's|-.*$||g' | sort -Vu
                echo -e "Type the version of PHP you whish to use (press Enter to use the default one)"
                read php_version
                # checks
                if echo "$php_version" | grep -qs "^[[:digit:]].*[[:digit:]]$" ; then
                    if ! apt-cache show php${php_version}-fpm 1>/dev/null 2>&1 ; then
                        unset php_version
                    fi
                else
                    unset php_version
                fi
            fi
        fi
    fi

    # remove unneeded repository
    if ! apt-cache madison php${php_version} | grep -qs "sury.org" ; then
        rm -f "/etc/apt/sources.list.d/php.list"
    fi

    # select all the wanted php packages
    packages="$( apt-cache search php${php_version} | awk '{print $1}' | grep "^php${php_version}-" | sort -u | grep -v "dbgsym$" )"

    for package in  bcmath bz2 cli common cropper curl fpm gd getid3 geoip gettext php-gettext imagick imap inotify intl json mbstring mysql oauth opcache pclzip pear phpmailer phpseclib mcrypt snoopy soap sqlite3 recode tcpdf tidy xml xmlrpc yaml zip zstd
    do
        if [[ -n "$package" ]] && echo "$packages" | grep -qs "^php${php_version}-${package}" ; then
            packages_extra="php${php_version}-$package $packages_extra"
        else
            el_debug "Ignoring php '${package}' because is not available for the version '${php_version}'"
        fi
    done
    packages_extra="composer $packages_extra"


    # first install this one independently, because the buggy ubuntu wants to install apache if not
    packages_install $packages_extra composer


    # get php version
    unset php_version
    update_variables
    require_variables "php_version"

    # configure php default options
    changeconfig "default_charset =" "default_charset = UTF-8" /etc/php/$php_version/fpm/php.ini
    changeconfig "short_open_tag" "short_open_tag = Off" /etc/php/$php_version/fpm/php.ini
    changeconfig "post_max_size" "post_max_size = 32M" /etc/php/$php_version/fpm/php.ini
    changeconfig "upload_max_filesize" "upload_max_filesize = 32M" /etc/php/$php_version/fpm/php.ini


    # increase execution times to 4 min
    changeconfig "max_execution_time" "max_execution_time = 240  ; increase this value if you have a plugin that requires more time to run" /etc/php/$php_version/fpm/php.ini
    changeconfig "max_input_time" "max_input_time = 240" /etc/php/$php_version/fpm/php.ini
    changeconfig "memory_limit" "memory_limit = 256M" /etc/php/$php_version/fpm/php.ini

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
        changeconfig ";ping.path =" "ping.path = /ping" /etc/php/$php_version/fpm/pool.d/www.conf
        # do not waste resources
        changeconfig "pm = dynamic" "pm = ondemand" /etc/php/$php_version/fpm/pool.d/www.conf
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
    addconfig "#If you use Unix sockets with PHP-FPM, you might encounter random 502 Bad Gateway errors with busy websites. To avoid this, we raise the max. number of allowed connections to a socket. Also useful for the NC connections:" /etc/sysctl.conf
    addconfig "net.core.somaxconn = 16384" /etc/sysctl.conf
    addconfig "net.ipv4.tcp_max_tw_buckets = 1440000" /etc/sysctl.conf
    addconfig "# Timeout for a port to be freed before to be used as a new one:" /etc/sysctl.conf
    addconfig "net.ipv4.tcp_fin_timeout 30" /etc/sysctl.conf
    addconfig "net.ipv4.tcp_window_scaling = 1" /etc/sysctl.conf
    addconfig "net.ipv4.tcp_max_syn_backlog = 2048" /etc/sysctl.conf

    addconfig "soft nofile 4096" /etc/security/limits.conf
    addconfig "hard nofile 4096" /etc/security/limits.conf

    # reconfigure other possible versions previously configured of php
    sed -i -e "s|php...-fpm|php${php_version}-fpm|g" /etc/nginx/sites-available/* /etc/monit/conf-available/* 2>/dev/null || true

    if ((is_ubuntu)) ; then
        systemctl stop apache2.service 2>/dev/null || true
        packages_remove apache2 apache2-data apache2-bin || true
    fi

    systemctl restart php${php_version}-fpm.service
    systemctl restart nginx.service 1>/dev/null 2>&1 || true

    installed_set "php"
}

install_mariadb(){
    el_info "Installing MariaDB..."
    # install service
    packages_install \
        mariadb-server mariadb-client \
        $NULL

    # set root password
    ask_variable "pass_mariadb_root" "Insert a Password for your ROOT user of your database, this password will be used for admin your mariadb server and create/delete databases, keep it in a safe place"

    if [[ -n "$pass_mariadb_root" ]] ; then
        #sed -i "s|^password = $|password = ${pass_mariadb_root}|g" /etc/mysql/debian.cnf
        #mysql -u root -p"$( grep password /etc/mysql/debian.cnf | sed -e 's|^.* = ||g' | head -1 )" -D mysql -e "update user set password=password('${pass_mariadb_root}') where user='root'"
        #mysql -u root -p"$( grep password /etc/mysql/debian.cnf | sed -e 's|^.* = ||g' | head -1 )" -D mysql -e "flush privileges"

        echo -e "Setting up mariadb..." 1>&2
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
                mysql -u root -D mysql -e "flush privileges;"
                mysql -u root -D mysql -e "SET PASSWORD FOR root@localhost = PASSWORD('${pass_mariadb_root}');"
                # enable unix authentication
                mysql -u root -D mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED VIA unix_socket WITH GRANT OPTION;"
                # remove anonymous user:
                mysql -u root -D mysql -e "DELETE FROM mysql.user WHERE User='';"
                # disallow root login remotely:
                mysql -u root -D mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
                # delete test database
                mysql -u root -D mysql -e "DELETE FROM mysql.db WHERE Db IN('test', 'test\_%');"
                mysql -u root -D mysql -e "flush privileges;"
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
        sync ; sleep 8

        systemctl restart mariadb.service 2>/dev/null || true
        sync ; sleep 1

        el_info "Your MYSQL root Password will be '${pass_mariadb_root}'"
    else
        NOREPORTS=1 el_warning "password for your root DB not provided, you may want to run again and give a root password for your datbase server"
    fi

    # setup, if needed
    if [[ "$debian_version" != "buster" ]] && ! ((is_ubuntu)) ; then
        mysql_install_db
        mysql_upgrade
    fi
    # secure your database
    #mysql_secure_installation

    installed_set "mariadb" "(mysql)"
}

install_wordpress(){
    el_info "Installing Wordpress..."
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
            libjpeg-turbo-progs webp optipng pngquant gifsicle libjs-cropper libjs-underscore
    fi

    # }}}
    # required variables {{{
    ask_variable "pass_mariadb_root" "Insert a Password for your ROOT user of your database, this password will be used for admin your mariadb server and create/delete databases, keep it in a safe place"
    ask_variable "wp_db_name" "Insert a Name for your Wordpress Database, keep it in a safe place"
    ask_variable "wp_db_user" "Insert a User for your Wordpress Database, keep it in a safe place"
    ask_variable "wp_db_pass" "Insert a Password for your Wordpress Database, keep it in a safe place"
    ask_variable "wp_webname" "Insert the Website name for your Wordpress install, examples: mysite.com, www.mysite.com, blog.mydomain.com, etc"
    ask_variable "username" "Insert a desired system username where to install Wordpress, it will be created (suggested) if doesn't exist yet"

    require_variables "wp_db_name|wp_db_user|wp_db_pass|pass_mariadb_root|username"

    # get the domain (last two . elements) from wp_webname
    if [[ -z "$domain" ]] ; then
        domain="$( echo "$wp_webname" | awk '{n=split($0, a, "."); printf("%s.%s", a[n-1], a[n])}' )"
    fi

    # }}}
    # create database {{{


    mysql -u root -p"${pass_mariadb_root}" -e "CREATE USER IF NOT EXISTS ${wp_db_user}@localhost IDENTIFIED BY '${wp_db_pass}';"
    mysql -u root -p"${pass_mariadb_root}" -e "CREATE DATABASE IF NOT EXISTS ${wp_db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    #GRANT ALL PRIVILEGES ON ${wp_db_name}.* TO ${wp_db_user}@localhost IDENTIFIED BY '${wp_db_pass}' WITH GRANT OPTION;
    mysql -u root -p"${pass_mariadb_root}" -e "GRANT ALL ON ${wp_db_name}.* TO '${wp_db_user}'@'localhost' IDENTIFIED BY '${wp_db_pass}';"
    mysql -u root -p"${pass_mariadb_root}" -e "FLUSH PRIVILEGES;"
    sync
    systemctl restart mariadb.service

    el_info "Created Database '${wp_db_name}' with username '${wp_db_user}' and pass '${wp_db_pass}'."

    # }}}
    # create user if not exist {{{
    if ! [[ -d "$DHOME/${username}" ]] ; then
        install_user
    fi
    # cleanups
    if [[ -d "$DHOME/${username}/${wp_webname}" ]] ; then
        NOREPORTS=1 el_warning "The directory '${wp_webname}' in the '${username}' user's home directory already exists"
        if el_confirm "\nDo you want to permanently delete it?" ; then
            rm -rf "$DHOME/${username}/${wp_webname}"
        fi
    fi

    su - "$username" <<EOF
bash -c '
set -e
set -E
#export PATH="$PATH"
cd ~

download_wp_addon(){
    local link filename addon
    link="\$( lynx -dump "https://wordpress.org/\$1/\$2/" | grep -i "downloads.wordpress.org.*zip" | sed -e "s|^.*http|http|g" | grep http | sort -V | tail -1 )"
    read -r link <<< "\$link"

    if [[ -n "\$link" ]] ; then
        echo -e "downloading \${1%s} \$2" 1>&2
        filename="\${link##*/}"
        wget --quiet "\$link"
        unzip -q "\$filename"
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
cd ~
cd "${wp_webname}/wp-content/plugins/"
download_wp_addon "plugins" "404-error-monitor" &
download_wp_addon "plugins" "autoptimize" &
download_wp_addon "plugins" "better-wp-security" &
download_wp_addon "plugins" "block-bad-queries" &
download_wp_addon "plugins" "broken-link-checker" &
download_wp_addon "plugins" "classic-editor" &
download_wp_addon "plugins" "contact-form-7" &
#download_wp_addon "plugins" "cookie-notice" &
download_wp_addon "plugins" "elementor" &
download_wp_addon "plugins" "email-post-changes" &
download_wp_addon "plugins" "essential-addons-for-elementor-lite" &
download_wp_addon "plugins" "google-analytics-for-wordpress" &
download_wp_addon "plugins" "honeypot" &
download_wp_addon "plugins" "master-slider" &
download_wp_addon "plugins" "query-monitor" &
download_wp_addon "plugins" "redirection" &
download_wp_addon "plugins" "resmushit-image-optimizer" &
download_wp_addon "plugins" "search-exclude" &
#download_wp_addon "plugins" "smart-slider-3" &
download_wp_addon "plugins" "updraftplus" &
download_wp_addon "plugins" "woocommerce" &
download_wp_addon "plugins" "wordpress-seo" &
download_wp_addon "plugins" "wp-mail-smtp" &
download_wp_addon "plugins" "wp-search-suggest" &
#download_wp_addon "plugins" "wp-super-cache" &
#download_wp_addon "plugins" "w3-total-cache" &
download_wp_addon "plugins" "wp-youtube-lyte" &
wait

cd ~
cd "${wp_webname}/wp-content/themes/"
download_wp_addon "themes" "bold-photography" &
download_wp_addon "themes" "generatepress" &
download_wp_addon "themes" "hello-elementor" &
download_wp_addon "themes" "neve" &
download_wp_addon "themes" "oceanwp" &
download_wp_addon "themes" "signify-photography" &

# configure wordpress
set -e
cd ~
cd "${wp_webname}"
cat wp-config-sample.php | dos2unix > wp-config.php
echo -e "# vim: foldmarker={{{,}}} foldlevel=0 foldmethod=marker filetype=cfg syn=conf" > nginx.conf
touch nginx-local.conf
# wait remaining processes
wait

'
EOF

# configure wordpress
sed -i -e "s|^define.*'DB_NAME'.*$|define( 'DB_NAME', '${wp_db_name}' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
sed -i -e "s|^define.*'DB_USER'.*$|define( 'DB_USER', '${wp_db_user}' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
sed -i -e "s|^define.*'DB_PASSWORD'.*$|define( 'DB_PASSWORD', '${wp_db_pass}' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
#sed -i -e "s|^define.*'DB_HOST'.*$|define( 'DB_HOST', '${wp_webname}' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
sed -i -e "s|^define.*'DB_CHARSET'.*$|define( 'DB_CHARSET', 'utf8mb4' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
sed -i -e "s|^define.*'DB_COLLATE'.*$|define( 'DB_COLLATE', 'utf8mb4_general_ci' );|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
sed -i -e "s|^table_prefix =.*$|table_prefix = 'elive_wp_';|g" "$DHOME/${username}/${wp_webname}/wp-config.php"
#echo -e "define( 'WP_MAX_MEMORY_LIMIT', '128M' );\ndefine('WP_MEMORY_LIMIT', '128M');" >> "$DHOME/${username}/${wp_webname}/wp-config.php"
echo -e "\n/* Turn off automatic updates of WP itself */\n//define( 'WP_AUTO_UPDATE_CORE', false );" >> "$DHOME/${username}/${wp_webname}/wp-config.php"
echo -e "\n/* Set amount of Revisions you wish to have saved */\n//define( 'WP_POST_REVISIONS', 40 );" >> "$DHOME/${username}/${wp_webname}/wp-config.php"
#echo -e "// Set httpS (ssl) mode\ndefine('FORCE_SSL_ADMIN', true);\ndefine('WP_HOME', 'https://www.elivecd.org');\ndefine('WP_SITEURL', 'https://www.elivecd.org');\ndefine('WP_CONTENT_URL', 'https://www.elivecd.org/wp-content' );" >> "$DHOME/${username}/${wp_webname}/wp-config.php"

    # configure root crontab to reload nginx every hour so plugins can work
    if grep -qs "nginx reload"  /root/.crontab ; then
        sed -i -e 's|^.*nginx reload.*$|5 * * * * /etc/init.d/nginx reload 1>/dev/null|g' /root/.crontab
    else
        echo -e "# reload nginx every hour to update the confs, for example from WP\n5 * * * * /etc/init.d/nginx reload 1>/dev/null" >> /root/.crontab
    fi
    crontab /root/.crontab


    # }}}

    if ((has_ufw)) ; then
        ufw allow 'Nginx Full'
    else
        if ((has_iptables)) ; then
            iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
            iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
        fi
    fi

    install_templates "wordpress" "/"

    # configure WP in nginx {{{
    require_variables "php_version"
    changeconfig "fastcgi_pass " "        fastcgi_pass unix:/run/php/php${php_version}-fpm-${username}.sock;" "/etc/nginx/sites-available/${wp_webname}"

    # redir non-www to www
    sed -i -e '/^# vim: set/d' "/etc/nginx/sites-available/${wp_webname}"
    if echo "$wp_webname" | grep -qsi "^www\." ; then

        #if el_confirm "\nDo you want to redirect '${wp_webname}' to '${wp_webname}' ?" ; then
            cat >> "/etc/nginx/sites-available/${wp_webname}" << EOF

## Redirect 'mywordpress.com' to 'www.mywordpress.com'
#server {
    #server_name ${wp_webname#www.};
    #return 301 https://www.${wp_webname#www.}\$request_uri;
#}

EOF
    else
            cat >> "/etc/nginx/sites-available/${wp_webname}" << EOF

## Redirect 'www.mywordpress.com' to 'mywordpress.com'
#server {
    #server_name www.${wp_webname#www.};
    #return 301 https://${wp_webname#www.}\$request_uri;
#}

EOF
        #fi
    fi
    addconfig "\n\n# vim: set syn=conf filetype=cfg : #" "/etc/nginx/sites-available/${wp_webname}"

    # enable site
    ln -fs "../sites-available/${wp_webname}" "/etc/nginx/sites-enabled/${wp_webname}"
    systemctl restart nginx.service


    # }}}
    # configure php-fpm for your wordpress {{{
    # disable default php-fpm if not yet
    mv -f "/etc/php/$php_version/fpm/pool.d/www.conf" "/etc/php/$php_version/fpm/pool.d/www.conf.template" 2>/dev/null || true
    # get a copy template
    cp -f "/etc/php/$php_version/fpm/pool.d/www.conf.template" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    sed -i -e "s|^\[www\]$|\[${wp_webname}\]|g" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "user =" "user = ${username}" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "group =" "group = ${username}" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    changeconfig "listen =" "listen = /run/php/php${php_version}-fpm-${username}.sock" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    # do not waste resources
    changeconfig "pm = " "pm = ondemand" "/etc/php/$php_version/fpm/pool.d/${wp_webname}.conf"
    # disable default php conf if we are not going to use it
    systemctl restart php${php_version}-fpm.service
    # }}}
    # configure SSL {{{
    # reload

    # interactively run the configurator
    el_info "Letsencrypt SSL (httpS) certificate install request"
    if [[ -d "/etc/letsencrypt/live/${wp_webname}" ]] ; then
        # re-install certificate, needed
        letsencrypt_wrapper --nginx -d "${wp_webname}" --quiet --no-eff-email --agree-tos --redirect --hsts --staple-ocsp
    else
        if ! ping -c 1 ${wp_webname} 1>/dev/null 2>&1 ; then
            NOREPORTS=1 el_warning "IMPORTANT: You must have your DNS's configured and already propagated with a record type A as '${wp_webname}' to point to this IP before to continue:"
            echo -e "Your DNS's should be already propagated before to continue, press Enter when your DNS's are ready"
            read nothing
        fi
        NOREPORTS=1 el_warning "Do not create more than 5 certificates for the same domain or you will be banned for 2 months from Letsencrypt service, use backups of '/etc/letsencrypt' instead of reinstalling entirely the server"
        NOREPORTS=1 el_warning "You must have your DNS configured to point your domain to this server machine in order to validate the certificates"

        if el_confirm "Do you want to create the certificate now? Note that you are limited to only 5 per week. (if you select no, your server will run on plain http with port 80 instead)" ; then
            # register first if needed:
            if [[ ! -d "/etc/letsencrypt/accounts" ]] ; then
                letsencrypt_wrapper register
            fi

            if ! letsencrypt_wrapper --nginx -d "${wp_webname}" --quiet --no-eff-email --agree-tos --redirect --hsts --staple-ocsp ; then
                el_info "You must follow the Letsencrypt wizard to enable SSL (httpS) for your website"
                letsencrypt_wrapper --nginx -d "${wp_webname}" --quiet --no-eff-email --agree-tos --redirect --hsts --staple-ocsp
            fi
        fi
    fi

    # enable http2 improvements
    sed -i -e 's|listen 443 ssl; # managed by Certbot|listen 443 ssl http2; # managed by Certbot|g'  "/etc/nginx/sites-available/${wp_webname}"
    sed -i -e 's|listen [::]:443 ssl; # managed by Certbot|listen [::]:443 ssl http2; # managed by Certbot|g'  "/etc/nginx/sites-available/${wp_webname}"

    # - configure SSL }}}

    # security
    el_info "We will set now an admin Username and Password in order to strenght your security, it will be used for your admin login or for access to your phpMyAdmin tool at 'yourwebsite.com/phpmyadmin' or to login in your Wordpress, if you want to modify the accesses file like adding more usernames it will be saved in your 'yourwebsite.com/.htpasswd' file"
    ask_variable "httaccess_user" "Insert an 'htpasswd' Username"
    ask_variable "httaccess_password" "Insert an 'htpasswd' Password"

    htpasswd -c -b "$DHOME/${username}/${wp_webname}/.htpasswd" "${httaccess_user}" "${httaccess_password}"
    chown "${username}:${username}" "$DHOME/${username}/${wp_webname}/.htpasswd"

    # create and configure local configuration file
    require_variables "php_version|username|wp_webname"

    cat > "$DHOME/${username}/${wp_webname}/nginx-local.conf" << EOF
# User configurations goes here

# Enable this section if you want to keep your login secured with an extra password
#location ^~ /wp-login.php {
#    auth_basic "Restricted";
#    auth_basic_user_file $DHOME/${username}/${wp_webname}/.htpasswd;
#    include fastcgi_params;
#    fastcgi_pass unix:/run/php/php${php_version}-fpm-${username}.sock;
#    fastcgi_index  index.php;
#    fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
#    fastcgi_param PATH_INFO \$fastcgi_script_name;
#}

# forbid access to private files
location = /.htpasswd { access_log off; log_not_found off; deny all; }

# disable useless logs
location = /favicon.ico {
   access_log off;
}
location = /robots.txt {
   allow all;
   access_log off;
}

# forbid showing hidden files, except the ones in .well-known dir which is needed for verifications and letsencrypt
location ^~ /.well-known/        { allow all ; }
location ~ /\\.          { access_log off; log_not_found off; return 444; }
location ~* \\.(conf)$          { access_log off; log_not_found off; return 444; }


# blacklist common hacks, enable these unless gives you problems
#location ~* (/data/admin/ver.txt|/templets/default/style/dedecms.css|/data/admin/allowurl.txt|/data/cache/index.htm|/member/space/person/common/css/css.css|/data/admin/quickmenu.txt|/templets/default/images/logo.gif|/data/mysql_error_trace.inc|//data/mysql_error_trace.inc|/member/templets/images/login_logo.gif|/member/images/dzh_logo.gif|/member/images/base.css|/include/data/vdcode.jpg|/api/Uploadify/|/plugins/uploadify/|alexa.jpeg)  { access_log off; log_not_found off; return 444; }
#location ~ (?i)^/wp\\-content/plugins/.*\\.txt$ { access_log off; log_not_found off; return 444; }
# filenames (php mostly)
#location ~ (?i).*/(autodiscover|eval-stdin|system_api|adminer|connector|adm|IOptimize|blackhat|th3_alpha|vuln|oecache|upload_index|xxx|microsoft.exchange|security|app-ads|newfile|demodata|admins|nginx|apache|wlmanifest|force-download|password)\\.(?:php[1-7]?|pht|phtml?|phps|xml|txt)$ { access_log off; log_not_found off; return 444; }
# directories too:
#location ~ (?i).*/(fckeditor|apismtp|console|jsonws|connectors|streaming|uc_server|ioptimization|code87|administrator|mTheme-Unus|data/404|e/data|client_area|stalker_portal|nextcloud|owncloud|old-wp|zoomsounds|awesome-support|pdst\\.fm)/ { access_log off; log_not_found off; return 444; }


# allow cache indexing to not give 404 errors
location /wp-content/uploads/md_cache/ {
    autoindex on;
}

# sitemap conf for WP Seo plugin:
#rewrite ^/sitemap\\.xml$ /sitemap_index.xml last;
#rewrite ^/([^/]+?)-sitemap([0-9]+)?\\.xml$ /index.php?sitemap=\$1&sitemap_n=\$2 last;
## needed for show the xml on firefox visualizing correctly and without error
#rewrite ^/main-sitemap\\.xsl$ /index.php?xsl=main last;

# vim: foldmarker={{{,}}} foldlevel=0 foldmethod=marker filetype=cfg syn=conf :
EOF

    # reload services
    if ! systemctl restart nginx.service php${php_version}-fpm.service mariadb.service ; then
        set +x
        el_error "failed to restart web services"
        el_report_to_elive "$(lsb_release -ds) - ${PRETTY_NAME} (version ${VERSION_ID}):\n$( journalctl -xe | tail -n 40 | sed -e '/^$/d' )"
    fi
    sleep 5

    http_version="$( curl -sI https://${wp_webname} -o/dev/null -w '%{http_version}\n' || true )"
    if [[ -n "$http_version" ]] ; then
        el_info "HTTP protocol version running is '$http_version'"
        installed_set "wordpress"
        is_installed_wordpress=1
    else
        set +x
        el_error "Your wordpress site seems to not be correctly working"
    fi

    # set up the extra phpmyadmin
    install_phpmyadmin

}

install_phpmyadmin(){
    el_info "Installing PHPMyAdmin..."
    local packages_extra
    # configure & install {{{
    echo -e "phpmyadmin\tphpmyadmin/dbconfig-install\tboolean\tfalse" | debconf-set-selections

    if [[ "$debian_version" = "buster" ]] && ! ((is_ubuntu)) ; then
        packages_extra="php-twig/buster-backports $packages_extra"
    fi


    TERM=linux DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NONINTERACTIVE_SEEN=true DEBCONF_NOWARNINGS=true \
        packages_install phpmyadmin $packages_extra

    # }}}
    # install an updated version of phpmyadmin which works better and less bugged {{{
    rm -rf /usr/share/phpmyadmin-updated || true
    mkdir -p /usr/share/phpmyadmin-updated
    cd /usr/share/phpmyadmin-updated

    download="$( lynx -dump https://www.phpmyadmin.net/downloads/ | grep -i "files.phpmyadmin.net/phpMyAdmin/.*all-languages.zip$" | sed -e 's|^.*http|http|g' | sort -V | tail -1 )"
    if [[ -z "$download" ]] ; then
        sleep 2
        download="$( lynx -dump https://www.phpmyadmin.net/downloads/ | grep -i "files.phpmyadmin.net/phpMyAdmin/.*all-languages.zip$" | sed -e 's|^.*http|http|g' | sort -V | tail -1 )"
    fi
    if [[ -n "$download" ]] ; then
        wget --quiet "$download"
        unzip -q "$( ls -1 *zip | tail -1 )"
        rm -f *zip || true
        rm -rf ../phpmyadmin || true
        mkdir -p ../phpmyadmin
        mv "$( find . -maxdepth 1 -type d | grep -i phpmyadmin )"/* ../phpmyadmin/
        cd /tmp
        rm -rf /usr/share/phpmyadmin-updated || true
    else
        set +x
        el_error "Unable to get the download url of phpMyAdmin from internet: $( lynx -dump https://www.phpmyadmin.net/downloads/ | grep zip )"
        exit 1
    fi

    installed_set "phpmyadmin"
    is_installed_phpmyadmin=1
    # }}}
}

install_fail2ban(){
    el_info "Installing Fail2Ban..."
    ask_variable "domain" "Insert the domain name on this server (like: johnsmith.com)"
    ask_variable "email_admin" "Insert an email on which you want to receive alert notifications (admin of server)"

    require_variables "email_admin|domain_ip|hostnamefull|domain"
    update_variables

    sources_update_adapt

    packages_install \
        fail2ban whois python3-pyinotify \
        nftables arptables ebtables

    install_templates "fail2ban" "/"

    changeconfig "dbpurgeage =" "dbpurgeage = 8d" /etc/fail2ban/fail2ban.conf

    changeconfig "bantime.factor " "bantime.factor = 2" /etc/fail2ban/jail.conf
    changeconfig "ignoreself " "ignoreself = true" /etc/fail2ban/jail.conf
    changeconfig "ignoreip " "ignoreip = 127.0.0.1/8 ::1 ${domain_ip}" /etc/fail2ban/jail.conf
    changeconfig "bantime " "bantime = 1d" /etc/fail2ban/jail.conf
    # NOTE: in buster was needed to use these ones in order to make it correctly working (at least in my setup)
    #   banaction = nftables-multiport
    #   banaction_allports = nftables-allports

    changeconfig "destemail " "destemail = ${email_admin}" /etc/fail2ban/jail.conf
    changeconfig "sender " "sender = root@${hostnamefull}" /etc/fail2ban/jail.conf
    #changeconfig "" " = " /etc/fail2ban/jail.conf
    #changeconfig "" " = " /etc/fail2ban/jail.conf
    #changeconfig "" " = " /etc/fail2ban/jail.conf
    #changeconfig "" " = " /etc/fail2ban/jail.conf

    if installed_check "exim" ; then
        changeconfig "enabled = " "enabled = true" /etc/fail2ban/jail.d/exim.conf
        changeconfig "enabled = " "enabled = true" /etc/fail2ban/jail.d/dovecot.conf
        # enable ddos / bruteforce preventions:
        #changeconfig "mode = " "mode = aggressive" /etc/fail2ban/filter.d/exim.conf
        changeconfig "mode = " "mode = aggressive" /etc/fail2ban/filter.d/exim-elive.conf
        changeconfig "mode = " "mode = aggressive" /etc/fail2ban/filter.d/dovecot.conf
    fi

    if installed_check "nginx" 2>/dev/null || installed_check "wordpress" 2>/dev/null ; then
        changeconfig "enabled = " "enabled = true" /etc/fail2ban/jail.d/nginx.conf
    fi

    if installed_check "mariadb" ; then
        changeconfig "enabled = " "enabled = true" /etc/fail2ban/jail.d/mysqld.conf
    fi

    if installed_check "monit" ; then
        changeconfig "enabled = " "enabled = true" /etc/fail2ban/jail.d/monit.conf
    fi


    systemctl restart  fail2ban.service

    is_installed_fail2ban=1
    installed_set "fail2ban"
}

install_exim(){
    # Howto's used as base:
    # * https://transang.me/setup-a-production-ready-exim-dovecot-server/
    # other nice howto's:
    #   * document with many examples: http://www.sput.nl/software/exim.html
    #   * customized conf example: https://files.directadmin.com/services/exim4.conf
    el_info "Installing Exim mail server..."
    local packages_extra
    systemctl stop  postfix.service  2>/dev/null || true
    packages_remove  postfix || true

    ask_variable "domain" "Insert the domain name on this server (like: johnsmith.com)"
    ask_variable "username" "Insert username to use, it will be created if doesn't exist yet"
    #ask_variable "wp_webname" "Insert the Website name for your email server, for example if you have a Wordpress install can be like: mysite.com, www.mysite.com, blog.mydomain.com. If you don't have any site just leave it empty"
    ask_variable "email_admin" "Insert an email on which you want to receive alert notifications (admin of server)"
    #ask_variable "email_username" "Insert an Email username for SMTP sending, like admin@yourdomain.com"
    ask_variable "email_imap_password" "Insert a password for the email of your '${username}' username"
    email_smtp_password="$email_imap_password"
    ask_variable "email_smtp_password" "Insert a password for your Email SMTP sending (user will be '${username}')"

    update_variables

    if ! [[ -d "$DHOME/${username}" ]] ; then
        install_user "$username"
    fi

    mail_hostname="$hostnamefull"
    #if [[ -z "$mail_hostname" ]] || [[ "${mail_hostname#www.}" = "$domain" ]] ; then
        #mail_hostname="$domain"
    #fi
    if [[ "$mail_hostname" != "$domain" ]] ; then
        if el_confirm "Do you want to use this server as your MAIN Email server for the '$domain' domain? (otherwise, it will be a specific email server for the '$hostnamefull' domain)" ; then
            mail_hostname="$domain"
            # XXX rDNS should point to this one, so domains should be allowed too
        fi
    fi

    require_variables "domain|email_admin|username|email_imap_password|email_smtp_password|hostnamefull"
    email_username="${username}@${mail_hostname}"

    # cleanup old install and configuration
    if [[ -d /etc/exim4 ]] ; then
        rm -rf "/etc/exim4.old-$(date +%F)" 1>/dev/null 2>&1 || true
        mv -f /etc/exim4 "/etc/exim4.old-$(date +%F)"
    fi
    packages_remove --purge exim4-\*


    echo "$mail_hostname" > /etc/mailname
    echo -e "exim4-config\texim4/dc_eximconfig_configtype\tselect\tinternet site; mail is sent and received directly using SMTP" | debconf-set-selections
    # this seems to be auto set:
    echo -e "exim4-config\texim4/dc_postmaster\tstring\t${email_admin}" | debconf-set-selections
    # do not allow external connections:
    if el_confirm "Do you want to be able to connect to this Email server externally? (if you select no, only localhost connections will be allowed)" ; then
        is_external_connections_email_enabled=1
        echo -e "exim4-config\texim4/dc_local_interfaces\tstring\t127.0.0.1 ; ::1 ; 127.0.0.1.587 ; ${domain_ip}.587 ; ${domain_ip}.25 " | debconf-set-selections
    else
        echo -e "exim4-config\texim4/dc_local_interfaces\tstring\t127.0.0.1 ; ::1 ; 127.0.0.1.587 ; 127.0.0.1.25 " | debconf-set-selections
    fi
    # if you send emails to these domains, accept them:
    if [[ "$mail_hostname" = "$domain" ]] ; then
        echo -e "exim4-config\texim4/dc_other_hostnames\tstring\t${mail_hostname}" | debconf-set-selections
    else
        echo -e "exim4-config\texim4/dc_other_hostnames\tstring\t${mail_hostname} ; ${domain}" | debconf-set-selections
    fi
    echo -e "exim4-config\texim4/dc_localdelivery\tselect\tMaildir format in home directory" | debconf-set-selections
    echo -e "exim4-config\texim4/use_split_config\tboolean\ttrue" | debconf-set-selections


    # packages to install
    #case "$debian_version" in
        #buster)
            #packages_extra="heirloom-mailx $packages_extra"
            #;;
        #bullseye|*)
            #packages_extra="$packages_extra"
            #;;
    #esac

    if installed_check "php" ; then
        update_variables
        packages_extra="php${php_version}-cli $packages_extra"
    else
        packages_extra="php-cli $packages_extra"
    fi

    packages_install \
        exim4-daemon-heavy mutt gpgsm openssl s-nail swaks libnet-ssleay-perl letsencrypt whois liburi-perl spf-tools-perl $packages_extra

    rm -f /etc/exim4/exim4.conf.template # since we are using split configurations, delete this file which may be confusing
    update-exim4.conf
    dpkg-reconfigure -fnoninteractive exim4-config

    # install certificate
    if [[ ! -d "/etc/letsencrypt/live/smtp.${mail_hostname}" ]] || [[ ! -d "/etc/letsencrypt/live/imap.${mail_hostname}" ]] ; then
        if ! ping -c 1 smtp.${mail_hostname} 1>/dev/null 2>&1 ; then
            NOREPORTS=1 el_warning "IMPORTANT: You must have your DNS's configured and already propagated with 'smtp.${mail_hostname}' and also 'imap.${mail_hostname}' to point to this IP before to continue:"
            echo -e "You are going to install a Letsencrypt certificate for 'smtp.${mail_hostname}', your DNS's should be already propagated before to continue, press Enter when your DNS's are ready"
            read nothing
        fi

        if installed_check "nginx" ; then
            letsencrypt_wrapper certonly -d smtp.${mail_hostname} --nginx --agree-tos -m ${email_admin} -n
            letsencrypt_wrapper certonly -d imap.${mail_hostname} --nginx --agree-tos -m ${email_admin} -n
        else
            if ((has_ufw)) ; then
                if ! iptables -S | grep -qsE "(\s+|,)80(\s+|,)" ; then
                    ufw allow 80/tcp
                fi
            else
                if ((has_iptables)) ; then
                    iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
                fi
            fi

            letsencrypt_wrapper certonly -d smtp.${mail_hostname} --standalone --agree-tos -m ${email_admin} -n
            letsencrypt_wrapper certonly -d imap.${mail_hostname} --standalone --agree-tos -m ${email_admin} -n
        fi
    fi

    # create group to read SSL certificate for tls
    # TODO: how much reliable is this? are the updated certificates valid or we will end in future "permission problems" because we need to apply again the group values?
    groupadd mailers 2>/dev/null || true
    usermod -aG mailers Debian-exim
    chgrp mailers /etc/letsencrypt/{live,archive}{,/smtp.$mail_hostname} /etc/letsencrypt/live/smtp.${mail_hostname}/privkey.pem
    chgrp mailers /etc/letsencrypt/{live,archive}{,/imap.$mail_hostname} /etc/letsencrypt/live/imap.${mail_hostname}/privkey.pem
    chmod g+x /etc/letsencrypt/{live,archive}
    chmod g+r /etc/letsencrypt/live/smtp.${mail_hostname}/privkey.pem
    chmod g+r /etc/letsencrypt/live/imap.${mail_hostname}/privkey.pem

    # be able to send from this domain, add a dkim signature
    /usr/local/sbin/exim_adddkim "${mail_hostname}"
    sed -i -e "/^${email_username}: /d" /etc/exim4/passwd 2>/dev/null || true
    echo -e "\n${email_username}: $( echo "${email_smtp_password}" | mkpasswd -s )" >> /etc/exim4/passwd

    # our server settings
    cat >> /etc/exim4/conf.d/main/000_localmacros << EOF

# require TLS (encrypted connections) to connect
MAIN_TLS_ENABLE = yes
MAIN_TLS_CERTIFICATE = /etc/letsencrypt/live/smtp.${mail_hostname}/fullchain.pem
MAIN_TLS_PRIVATEKEY = /etc/letsencrypt/live/smtp.${mail_hostname}/privkey.pem

# set the DKIM configuration
DKIM_DOMAIN = ${mail_hostname}
DKIM_SELECTOR = mail
DKIM_PRIVATE_KEY = /etc/exim4/${mail_hostname}/dkim_private.key

# No local deliveries will ever be run under the uids of these users (a colon-
# separated list). An attempt to do so gets changed so that it runs under the
# uid of "nobody" instead. This is a paranoic safety catch. Note the default
# setting means you cannot deliver mail addressed to root as if it were a
# normal user. This isn't usually a problem, as most sites have an alias for
# root that redirects such mail to a human administrator.
never_users                        = root

# Improve defaults
# default was 2d
MAIN_IGNORE_BOUNCE_ERRORS_AFTER = 8h
# default was 7d
MAIN_TIMEOUT_FROZEN_AFTER = 2d

# include special filters if you have, like replacing a header from: or reply-to: to another one
#system_filter = /etc/exim4/filter-headers.conf

# SPF filtering
CHECK_RCPT_SPF = true

# extra options
CHECK_MAIL_HELO_ISSUED = true
CHECK_RCPT_REVERSE_DNS = true
CHECK_DATA_VERIFY_HEADER_SYNTAX = true

# DNS blacklist:
#CHECK_RCPT_IP_DNSBLS = sbl.spamhaus.org:bl.spamcop.net:cbl.abuseat.org
CHECK_RCPT_IP_DNSBLS = zen.spamhaus.org
#CHECK_RCPT_DOMAIN_DNSBLS = dnsbl.spfbl.net/\$sender_address_domain
#CHECK_RCPT_DOMAIN_DNSBLS = dnsbl.sorbs.net/\$sender_address_domain : dnsbl.spfbl.net/\$sender_address_domain

# Logging details, also needed for fail2ban, change it with caution:
MAIN_LOG_SELECTOR = \
  +all \
  +subject \
  -arguments
  #+delivery_size \
  #+sender_on_delivery \
  #+received_recipients \
  #+received_sender \
  #+smtp_confirmation \
  #+subject \
  #+smtp_incomplete_transaction
  #-dnslist_defer \
  #-host_lookup_failed \
  #-queue_run \
  #-rejected_header \
  #-retry_defer \
  #-skip_delivery


EOF

    # configure the login system:
    cat >> /etc/exim4/conf.d/auth/30_exim4-config_examples << 'EOF'

# Elive: login to SMTP using tls
login_server:
  driver = plaintext
  public_name = LOGIN
  server_prompts = "Username:: : Password::"
  server_condition = "${if crypteq{$auth2}{${extract{1}{:}{${lookup{$auth1}lsearch{CONFDIR/passwd}{$value}{*:*}}}}}{1}{0}}"
  server_set_id = $auth1
  .ifndef AUTH_SERVER_ALLOW_NOTLS_PASSWORDS
  server_advertise_condition = ${if eq{$tls_in_cipher}{}{}{*}}
  .endif

EOF

    # edit the conf file to deny blacklisted ip's (instead of warn about them)
    # note: very nice 'ed' howto: https://www.computerhope.com/unix/ued.htm
    echo -e "/ifdef CHECK_RCPT_IP_DNSBLS\n+1\ns/warn/deny/\nw\nq" | ed /etc/exim4/conf.d/acl/30_exim4-config_check_rcpt 1>/dev/null

    systemctl stop exim4.service
    rm -f /var/log/exim4/paniclog
    rm -rf /var/log/exim4/* /var/log/mail*
    systemctl restart rsyslog.service
    systemctl start exim4.service

    #grep -R Subject /var/spool/exim4/input/* | sed -e 's/^.*Subject:\ //' | sort | uniq -c | sort -n   # show Subjects of Emails in the queue
    exim -bp | exiqgrep -i | xargs exim -Mrm  2>/dev/null || true  # delete all the queued emails

    # configure mailx-send to work
    changeconfig "username=" "username=\"$( echo "${email_username}" | uri-gtk-encode )\" # note: must be converted to uri (uri-gtk-encode)" /usr/local/bin/mailx-send
    changeconfig "password=" "password=\"$email_smtp_password\"" /usr/local/bin/mailx-send
    changeconfig "smtp_connect=" "smtp_connect=\"smtp.${mail_hostname}\"" /usr/local/bin/mailx-send
    changeconfig "smtp_port=" "smtp_port=\"587\"" /usr/local/bin/mailx-send
    changeconfig "args_snail_extra=" "args_snail_extra=\"-S smtp-use-starttls -S smtp-auth=login\"" /usr/local/bin/mailx-send

    # configure our tool email-sender too
    su - "$username" <<EOF
bash -c '
set -e
mkdir -p \$HOME/.config
rm -f \$HOME/.config/email-sender
echo -e "email_account=\"${email_username}\"" >> \$HOME/.config/email-sender
echo -e "email_password=\"${email_smtp_password}\"" >> \$HOME/.config/email-sender
mkdir -p \$HOME/.mutt/accounts
rm -f \$HOME/.mutt/accounts/elive-sender
echo -e "# smtp, sending of emails:" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set smtp_url = \"smtp://${email_username}@smtp.${mail_hostname}:587/\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set smtp_pass = \"${email_smtp_password}\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set from = \"${username}@${mail_hostname}\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set realname = \"${username^} from ${hostname} (EliveServer)\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set copy = no" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set timeout = 60" >> \$HOME/.mutt/accounts/elive-sender
echo -e "" >> \$HOME/.mutt/accounts/elive-sender
echo -e "# imap settings:" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set imap_user = \"${username}\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set imap_pass = \"${email_imap_password}\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set spoolfile = \"imaps://imap.${mail_hostname}/\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set folder = \"imaps://imap.${mail_hostname}/INBOX/\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set record  = \"=Sent\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set postponed = \"=Drafts\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set mail_check = 60" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set imap_keepalive = 10" >> \$HOME/.mutt/accounts/elive-sender
echo -e "" >> \$HOME/.mutt/accounts/elive-sender
echo -e "set ssl_force_tls = yes" >> \$HOME/.mutt/accounts/elive-sender
echo -e "# Set default editor\n#set editor=\"vim\"" >> \$HOME/.mutt/accounts/elive-sender
echo -e "# sort messages by thread\nset sort=threads" >> \$HOME/.mutt/accounts/elive-sender
# make it default if we had not another config previously
if [[ ! -e "\$HOME/.muttrc" ]] ; then
    ln -fs "\$HOME/.mutt/accounts/elive-sender" "\$HOME/.muttrc"
fi
# symlink the user mail location to make it compatible with mutt or other tools
ln -fs \$HOME/Maildir /var/mail/\$USER || true
'
EOF



    # Dovecot:
    el_info "Installing Dovecot IMAP email server..."
    packages_install \
        dovecot-imapd dovecot-pop3d

    usermod -aG mailers dovecot

    changeconfig "ssl_cert =" "ssl_cert = </etc/letsencrypt/live/imap.${mail_hostname}/fullchain.pem" /etc/dovecot/conf.d/10-ssl.conf
    changeconfig "ssl_key =" "ssl_key = </etc/letsencrypt/live/imap.${mail_hostname}/privkey.pem" /etc/dovecot/conf.d/10-ssl.conf
    changeconfig "auth_mechanisms =" "auth_mechanisms = plain login" /etc/dovecot/conf.d/10-auth.conf
    sed -i -e "s|^\!include auth-system.conf.ext|#\!include auth-system.conf.ext|g" /etc/dovecot/conf.d/10-auth.conf
    sed -i -e "s|^#\!include auth-passwdfile.conf.ext|\!include auth-passwdfile.conf.ext|g" /etc/dovecot/conf.d/10-auth.conf

    awk -v replace="  unix_listener auth-userdb {\n    mode = 0660\n    user = mail\n    #group =\n  }"  '/unix_listener auth-userdb[[:space:]]+\{/{f=1} !f{print} ;  /}/{if (f == 1) print replace; f=0}' /etc/dovecot/conf.d/10-master.conf > /etc/dovecot/conf.d/10-master.conf.new
    mv -f /etc/dovecot/conf.d/10-master.conf.new /etc/dovecot/conf.d/10-master.conf

    changeconfig "mail_location =" "mail_location = maildir:~/Maildir" /etc/dovecot/conf.d/10-mail.conf
    changeconfig "#log_path = syslog" "log_path = syslog" /etc/dovecot/conf.d/10-logging.conf

    # add credentials
    touch /etc/dovecot/users
    # example: me:{CRYPT}$2y$05$pFZ8zDO.o.FtcTIWNOTqdeTgRj0OmoxzK2HineVAKEv91DEP4DXY6:1000:1000::/home/foo:/bin/bash:userdb_mail=maildir:/home/foo/Maildir
    sed -i -e "/^${username}@${mail_hostname}:/d" /etc/dovecot/users 2>/dev/null || true
    echo -e "${username}@${mail_hostname}:{SHA512-CRYPT}$( perl -e "print crypt("${email_imap_password}",'\$6\$saltsalt\$')" ):$( grep "^${username}:" /etc/passwd | sed -e "s|^${username}:.:||g" ):userdb_mail=maildir:$( awk -F: -v user="$username" '{if ($1 == user) print $6}' /etc/passwd )/Maildir" >> /etc/dovecot/users

    # redirect emails to your website's user email
    if [[ "${email_username%@*}" != "$username" ]] ; then
        sed -i -e "/^${email_username%@*}: /d" /etc/aliases 2>/dev/null || true
        echo "${email_username%@*}: ${username}" >> /etc/aliases
    fi
    sed -i -e "/^no-reply: ${username}$/d" /etc/aliases 2>/dev/null || true
    echo "no-reply: ${username}" >> /etc/aliases
    #echo "notification: ${username}" >> /etc/aliases


    # open ports: POP3, port 995
    if ((is_external_connections_email_enabled)) ; then
        if ((has_ufw)) ; then
            ufw allow 25/tcp
            ufw allow 587/tcp
            ufw allow 995/tcp
        else
            if ((has_iptables)) ; then
                iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
                iptables -A INPUT -p tcp -m tcp --dport 587 -j ACCEPT
                iptables -A INPUT -p tcp -m tcp --dport 995 -j ACCEPT
            fi
        fi
    fi

    # TODO: include a stat system to know how many people installed the server


    # restart
    systemctl restart dovecot.service

    if el_confirm "Do you want to install the Anti-Spam Spamassasin system? (Important: this feature will use 100 MB of your RAM resources)" ; then
        el_info "Installing SpamAssassin antispam system..."
        # make a backup so the user can switch from one to other conf
        cp -a /etc/exim4 /etc/exim4.no-spamassassin

        packages_install \
            spamassassin

        # enable it
        changeconfig "spamd_address =" "spamd_address = 127.0.0.1 783" /etc/exim4/conf.d/main/02_exim4-config_options

        ed /etc/exim4/conf.d/acl/40_exim4-config_check_data 1>/dev/null <<EOF
/Reject spam messages
-1
a

  # put headers in all messages (no matter if spam or not)
  warn  spam = debian-spamd:true
    add_header = X-Spam-Score: \$spam_score (\$spam_bar)
    add_header = X-Spam-Report: \$spam_report

  # add second subject line with *SPAM* marker when message is over threshold
  warn  spam = debian-spamd
    add_header = Subject: ***SPAM (score:\$spam_score)*** \$h_Subject:

  # reject spam at high scores (> 12)
  deny  spam = debian-spamd:true
    condition = \${if >{\$spam_score_int}{120}{1}{0}}
    message = This message scored \$spam_score spam points.

.
w
q
EOF
        changeconfig "CRON=0" "CRON=1" /etc/default/spamassassin

        sa-update
        systemctl enable spamassassin.service
        systemctl restart spamassassin.service

    fi


    installed_set "exim"
    is_installed_exim=1
}

install_iptables(){
    el_info "Installing Iptables..."

    # only ufw mode:
    if ((has_ufw)) ; then
        if ! grep -qs "syn-flood attack" /etc/ufw/before.rules ; then
            ed /etc/ufw/before.rules 1>/dev/null <<EOF
/End required lines
a

# block null packets
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP
# reject syn-flood attack
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP
# reject x-mas packets
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

.
w
q
EOF
        fi

        # ddos protection for web
        if installed_check "wordpress" ; then

            if el_confirm "Do you want to protect your webserver against DDOS attacks?" ; then
            ed /etc/ufw/before.rules 1>/dev/null <<EOF
/^\\*filter
a
:ufw-http - [0:0]
:ufw-http-logdrop - [0:0]
.
/^COMMIT\$
-2
a
### start ddos atacks prevention ###
# Enter rule
-A ufw-before-input -p tcp --dport 80 -j ufw-http
-A ufw-before-input -p tcp --dport 443 -j ufw-http

# Limit connections per Class C
-A ufw-http -p tcp --syn -m connlimit --connlimit-above 50 --connlimit-mask 24 -j ufw-http-logdrop

# Limit connections per IP
-A ufw-http -m state --state NEW -m recent --name conn_per_ip --set
-A ufw-http -m state --state NEW -m recent --name conn_per_ip --update --seconds 10 --hitcount 20 -j ufw-http-logdrop

# Limit packets per IP
-A ufw-http -m recent --name pack_per_ip --set
-A ufw-http -m recent --name pack_per_ip --update --seconds 1 --hitcount 20 -j ufw-http-logdrop

# Finally accept
-A ufw-http -j ACCEPT

# Log
-A ufw-http-logdrop -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW HTTP DROP (DDOS prevention)] "
-A ufw-http-logdrop -j DROP
### end ###

.
w
q
EOF

            # comment the original 80,443 port opening to use only our settings
            sed -i -e '/443.*Nginx/s|.*|#&|g' /etc/ufw/user.rules

            fi
        fi

        ufw reload

    else

        # iptables only mode:
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
            # extra services:
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

            # rate-limited pop3 connections (avoids bruteforce attacks), untested
            #iptables -A INPUT -p tcp --dport 110 -m state --state NEW -m recent --name pop --rsource --update --seconds 60 --hitcount 5 -j DROP
            #iptables -A INPUT -p tcp --dport 110 -m state --state NEW -m recent --name pop --rsource --set -j ACCEPT

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

            netfilter-persistent save || true
        fi

    fi

    installed_set "iptables"
}

install_monit(){
    el_info "Installing Monit..."
    ask_variable "email_admin" "Insert an email on which you want to receive alert notifications (admin of server)"
    ask_variable "domain" "Insert the domain name on this server (like: johnsmith.com)"

    update_variables
    require_variables "hostnamefull|domain|email_admin"

    install_templates "monit" "/"

    packages_install  monit
    #addconfig "set daemon 120" /etc/monit/monitrc
    changeconfig "with start delay 240" "with start delay 240" /etc/monit/monitrc
    #addconfig "include /etc/monit/monitrc.d/*" /etc/monit/monitrc
    addconfig "set mailserver localhost port 25" /etc/monit/monitrc
    addconfig "set mail-format { from: monit-daemon@$hostnamefull }" /etc/monit/monitrc
    addconfig "set alert ${email_admin} not {instance}" /etc/monit/monitrc
    # enable features like "monit summary" or other commands
    addconfig "# enable http interface so we can use 'monit summary' and other commands\nset httpd port 2811 and\n    use address localhost\n    allow localhost\n    allow admin:monit" /etc/monit/monitrc

    ln -fs ../conf-available/openssh-server /etc/monit/conf-enabled
    ln -fs ../conf-available/file_systems /etc/monit/conf-enabled
    ln -fs ../conf-available/system /etc/monit/conf-enabled
    ln -fs ../conf-available/rsyslog /etc/monit/conf-enabled

    if installed_check "mariadb" ; then
        ln -fs ../conf-available/mysql /etc/monit/conf-enabled
    fi
    if installed_check "nginx" ; then
        ln -fs ../conf-available/nginx /etc/monit/conf-enabled
    fi
    if installed_check "exim" ; then
        ln -fs ../conf-available/exim4 /etc/monit/conf-enabled
    fi
    if installed_check "wordpress" ; then
        ln -fs ../conf-available/wordpress /etc/monit/conf-enabled
    fi

    systemctl restart monit.service

    is_installed_monit=1
    installed_set "monit"
}

install_rootkitcheck(){
    el_info "Installing rootkit checkers..."
    echo -e "chkrootkit\tchkrootkit/run_daily\tboolean\ttrue" | debconf-set-selections
    echo -e "chkrootkit\tchkrootkit/run_daily_opts\tstring\t-q" | debconf-set-selections
    echo -e "chkrootkit\tchkrootkit/diff_mode\tboolean\ttrue" | debconf-set-selections

    echo -e "rkhunter\trkhunter/cron_daily_run\tboolean\ttrue" | debconf-set-selections
    echo -e "rkhunter\trkhunter/cron_db_update\tboolean\ttrue" | debconf-set-selections
    echo -e "rkhunter\trkhunter/apt_autogen\tboolean\ttrue" | debconf-set-selections

    DEBIAN_FRONTEND="noninteractive" packages_install  \
        chkrootkit rkhunter unhide

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

    el_info "Cleaned up some space removing unneeded things"
}

final_steps(){
    # clean all
    apt_wait
    apt-get -q clean
    if ((is_production)) ; then
        rm -rf "$sources"
    fi

    # make system lighter
    # this is a freaking waste of resources, some devs really don't care about lightness, but Elive do :P so let's fix this bug:
    if systemctl status unattended-upgrades.service 2>&1 | colors-remove | grep -qsi "Active: active" ; then
        systemctl stop unattended-upgrades.service
        systemctl disable unattended-upgrades.service
        # run lighter upgrades without daemon
        echo -e "\n# Run unattended-upgrades in one shot daily instead of a waste-resources daemon\n0 8 * * * /usr/local/sbin/unattended-upgrades-light 1>/dev/null" >> /root/.crontab
    fi
    # seems like this package is entirely useless in our server and also uses some RAM resources so let's remove it
    if [[ -e /var/lib/dpkg/info/packagekit.list ]] ; then
        packages_remove  packagekit
    fi

    changeconfig "GRUB_TIMEOUT=" "GRUB_TIMEOUT=1" /etc/default/grub 2>/dev/null || true

    # save settings {{{
    if ((has_ufw)) ; then
        ufw reload
    else
        if ((has_iptables)) ; then
            packages_install iptables-persistent
            netfilter-persistent save || true
            # save all iptables configs
            ip6tables-save > /etc/ip6tables.rules
            iptables-save > /etc/iptables.rules
        fi
    fi

    crontab /root/.crontab

    # save a backup of the full etc created
    rm -rf /etc.bak-after-elive-setup 2>/dev/null || true
    cp -a /etc /etc.bak-after-elive-setup


    swapoff -a 1>/dev/null 2>&1 || true
    swapon -a 1>/dev/null 2>&1 || true

    # unmark a possible previously failed attempt
    rm -f "/tmp/.${SOURCE}.failed"

    # }}}

    echo -e "\n"

    if [[ -s /etc/cloud/cloud.cfg ]] ; then
        el_info "You have a Cloud configuration file in '/etc/cloud/', which you may configure it to manage your users or other server settings, like automtic reconfiguration of your hosts file, re-creation of dummy users, etc..."
    fi

    if [[ "$( ls -1 /boot/vmlinuz-* | wc -l )" -gt 1 ]] ; then
        el_info "You have more than one kernels installed, you can free up some disk space by uninstalling the old ones (maybe you need to reboot first to switch to the new one)"
    fi

    # TODO: review and remove
    #echo -e "Maybe you want now to:"
    #echo -e " # use backup websites tool to recover the last state of a website (faster than use mysql to import databases)"
    #echo -e " # verify all the settings in /etc that all looks correct"
    #echo -e " # disable root ssh access"
    #echo -e " # run a check to see if your httpS / ssl is the most valid one: https://www.ssllabs.com/ssltest/analyze.html?d=elivecd.org"
    #echo -e "   # you have copies of /etc/letsencrypt, the account is thanatermesis@gmail.com, and use the same confs as in forum.elivelinux.org"
    #echo -e "   # run: 'systemctl disable certbot.timer' in order to run manually the renewal from your custom cronjob"
    #echo -e "\nFinally: "
    #echo -e " * Make sure that you have disabled cronjobs (reboot server, backups, etc) and daemons uneeded"
    #echo -e " * Please restart/reboot everything"

    # TODO: add mysql password etc
    # TODO: add a beautiful list to show to the user
    # TODO: tell user we would like to know his experience, link to forum dedicated to elive for servers
    if ((is_installed_elive)) ; then
        el_info "Elive Features installed: Many, see github page: https://github.com/Elive/elive-for-servers"
        echo
    fi

    if ((is_mode_curl)) || ! ((is_extra_service)) ; then
        el_info " *** You have installed Elive on your server, optionally you can run again the tool with the '--help' option to know all the extra options available like installing full-featured services in one shot ***"
        echo 1>&2
    fi


    if ((is_installed_wordpress)) ; then
        el_info "Wordpress installed:"
        el_info "Your system's user for it is: '${username}' with home in '$DHOME/${username}'"
        el_info "Database name is '${wp_db_name}', user '${wp_db_user}', pass '${wp_db_pass}', to manage it you can use the installed phpmyadmin tool from 'https://${wp_webname}/phpmyadmin', password is on your website directory's '.htpasswd' file"
        el_info "Website is: '${wp_webname}', make sure you configure correctly your needed DNS to point to this server"
        el_info "You must add a DNS record in your server, type A named '${wp_webname}' with data '${domain_ip}'"
        el_info "Recommended plugins and templates are included, enable them as your choice and DELETE the ones you are not going to use"
        el_info "You have an 'nginx.conf' file in your wordpress install, read them to enable or disable configurations, like for example restricting all your admin access with a basic password"
        echo 1>&2
    fi

    if ((is_installed_exim)) ; then
        # TODO: tell about where to check these settings, like https://mxtoolbox.com/SuperTool.aspx?action=ptr%3a78.141.244.36&run=toolpage
        el_info "Exim Email server configurations:"

        el_info "DNS: you must configure your server's dns to follow these entries:"

        # SPF & other DNS
        el_info "DNS type A record with (empty) name '' with data '${domain_ip}'"

        if [[ "$mail_hostname" = "$domain" ]] ; then
            el_info "DNS type A record named 'smtp' with data '${domain_ip}'"
            el_info "DNS type A record named 'imap' with data '${domain_ip}'"
            el_info "DNS type TXT record named '_dmarc' with data 'v=DMARC1; p=reject; rua=mailto:postmaster@${domain};'"
            el_info "DNS type TXT record with (empty) name '' with data 'v=spf1 a ip4:${domain_ip} -all'"
            el_info "DNS type MX record with (empty) name '' with data 'smtp.${domain}'"
        else
            el_info "DNS type A record named '${mail_hostname}' with data '${domain_ip}'"
            el_info "DNS type A record named 'smtp.${hostnameshort}' with data '${domain_ip}'"
            el_info "DNS type A record named 'imap.${hostnameshort}' with data '${domain_ip}'"
            el_info "DNS type TXT record named '_dmarc.${hostnameshort}' with data 'v=DMARC1; p=reject; rua=mailto:postmaster@${mail_hostname};'"
            el_info "DNS type TXT record named '${hostnameshort}' with data 'v=spf1 a ip4:${domain_ip} -all'"
            el_info "DNS type MX record named '${mail_hostname}' with data 'smtp.${mail_hostname}'" # TODO: this one is generic to send all to mail.smtp.yourdomain.com, we should be more specific?
        fi
        #el_info "DNS type TXT record named '*._report._dmarc.${mail_hostname}' with data 'v=DMARC1;" # TODO: needed?
        #el_info "DNS type TXT record named '*._dmarc.${mail_hostname}' with data 'v=DMARC1; p=reject; rua=mailto:${email_admin};"
        #el_info "DNS type MX record named '@' with data 'mail.${mail_hostname}'" # TODO: this one is generic to send all to mail.smtp.yourdomain.com, we should be more specific?
        #el_info "DNS type MX record named '@' with data 'smtp.${mail_hostname}'" # TODO: this one is generic to send all to mail.smtp.yourdomain.com, we should be more specific?
        if [[ "$wp_webname" != "$mail_hostname" ]] ; then
            el_info "DNS type MX record named '${wp_webname}' with data 'smtp.${mail_hostname}'"
        fi
        for i in ${mail_hostname} ${domain}
        do
            [[ -z "$i" ]] && continue
            [[ ! -s "/etc/exim4/${i}/dkim_public.key" ]] && continue
            el_info "Email DKIM: Edit your DNS's and add a TXT entry named 'mail._domainkey.${i%%.*}' with these contents:"
            echo "k=rsa; p=$(cat /etc/exim4/${i}/dkim_public.key | grep -vE "(BEGIN|END)" | tr '\n' ' ' | sed -e 's| ||g' ; echo )" 1>&2
        done
        el_info "DNS in your 'reverse DNS', set it to '${mail_hostname}'"
        # TODO: is reverse dns meant to be FQHN or it can be the domain itself?

        if ((has_ipv6)) ; then
            el_info "For your IPv6 settings, in case you use it:"
            echo -e "    * Add DNS type AAAA record named '${mail_hostname}' with data '${domain_ip6}'" 1>&2
            echo -e "    * Append 'ip6:${domain_ip6}' to your previous TXT record for SPF" 1>&2
            echo -e "    * Set the Reverse-DNS in your hosting for your IPv6 to be '${mail_hostname}'" 1>&2
        fi

        el_info "If you have DNSSEC activate it (caution that this doesn't conflicts with shared DNS among multiple hostings), by configuring it in the advanced dns of your domain and your host service"
        # TODO: add mta-sts

        # SMTP conf
        el_info "SMTP connect: to configure your website or other tools to send emails from this server you must use: URL 'smtp.${mail_hostname}', PORT '587' (TLS), username '${email_username}', password (plain) '${email_smtp_password}'"
        el_info "Note: When you send emails from no-reply@${mail_hostname}, bounces or reply's will be received with your user '${username}', you can access to these emails using the IMAP system"
        el_info "IMAP connect: connect to your email as: URL 'imap.${mail_hostname}', PORT '995' (pop3, ssl/tls), username '${email_username}', password (plain) '${email_imap_password}'. So the emails will be received on this user of your server"
        #if [[ "$mail_hostname" != "$domain" ]] ; then
            # TODO: tell that we need to add more same dns's for the main domain
        #fi
        echo 1>&2
    fi

    if ((is_installed_fail2ban)) ; then
        el_info "Fail2ban: make sure that you have enabled all the services that you want to watch for attacks and disabled the ones you don't want, from the jail file and directory in /etc/fail2ban, if you are unable to connect to your server it could be by a false positive so make sure your IP is not blacklisted on that moment in fail2ban and improve this tool if needed"
        echo 1>&2
    fi

    if ((is_installed_monit)) ; then
        el_info "Monit: monit is a daemon that watch the other daemons are correctly running and if is not the case, restarts it. So if a daemon is restarted when you don't expect to, this feature can be the reason."
        echo 1>&2
    fi

    el_info "IMPORTANT: FOLLOW THE PREVIOUS INSTRUCTIONS TO FINISH YOUR SETUP. DO NOT CLOSE THIS TERMINAL UNTIL YOU HAVE SET ALL. YOU CAN COPY-PASTE EVERYTHING JUST LIKE PASSWORDS AND ALL TO SAVE IT IN A BACKUP SOMEWHERE, DO NOT LOSE THIS INFO"
    el_info "Remember to subscribe to Elive in order to know about more new amazing things - Donate to the project to keep it alive if it helped you!"

    # TODO: if this tool has been useful for you or you got benefited from it, please make a donation so we can continue doing amazing things
}


# usage {{{
notimplemented(){
    source /usr/lib/elive-tools/functions || exit 1

    if ! ((is_production)) ; then
        return
    fi

    NOREPORTS=1 el_warning "Note: This feature should have been correctly tested but it may be not fully working / functional / stable, use it at your own risk"
    if ! el_confirm "\nDo you want to proceed even if is not implemented or completely integrated? it may not work as expected or wanted. DO NOT REPORT BUGS BY USING THIS OPTION. You are welcome to improve this tool to make it working.\nContinue anyways?" ; then
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

    exit 1
}
#}}}
main(){
    # TODO: set to 1 for release, to 0 for betatesting more automated installs
    is_production=1
    # TODO: comment after release has been debugged
    is_tool_beta=1

    # get user options
    get_args "$@"


    if [[ "$UID" != "0" ]] ; then
        set +x
        el_error "You need to be root to run this tool"
        exit 1
    fi

    # update: dhome is not fully compatible because of templates, do not enable it:
    #source /etc/adduser.conf 2>/dev/null || true
    DSHELL=/bin/zsh
    if [[ -z "$DHOME" ]] || [[ ! -d "$DHOME" ]] ; then
        DHOME="/home"
    fi

    if which ufw 1>/dev/null ; then
        has_ufw=1
    fi
    if which iptables 1>/dev/null ; then
        has_iptables=1
    fi



    hostname="$(hostname)"
    hostnameshort="${hostname%%.*}"
    # do not change this value unless you know what you are doing, it is used to replace old configuration template files to your server:
    # TODO: ip of elive server actually is:  139.59.157.208
    previous_ip="188.226.235.52"

    # TODO: in production mode, add the -y parameter:
    # update: it should always be -y, otherwise if user says maybe accidentally no, setup will be broken but marked as valid
    #if ((is_production)) ; then
        #apt_options="-q --allow-downgrades -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 "
    #else
        apt_options="-q -y --allow-downgrades -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew"
    #fi

    #domain_names="www.${domain} ${domain} blog.${domain} forum.${domain}"
    #domain_names="www.${domain} ${domain}"

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
            elive_repo="deb ${repoarch} http://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
            ;;
        "11."*|"bullseye"*)
            debian_version="bullseye"
            elive_version="bullseye"
            elive_repo="deb ${repoarch} https://repo.${debian_version}.elive.elivecd.org/ ${debian_version} main elive"
            ;;
        *)
            echo -e "E: sorry, this version of Debian is not supported, you can help implementing it on: https://github.com/Elive/elive-for-servers" 1>&2
            exit 1
            ;;
    esac

    # is an ubuntu?
    source /etc/lsb-release 2>/dev/null || true
    if [[ "$DISTRIB_ID" = "Ubuntu" ]] ; then
        if ! el_confirm "\nWarning: Elive is much more compatible with Debian than Ubuntu, the support for ubuntu is entirely experimental and bug reports will be not accepted, you can optionally reinstall your server using a better base system like Debian. Are you sure to continue with Ubuntu?" ; then
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
                echo -e "E: sorry, this version of Ubuntu is not supported, you can help implementing it on: https://github.com/Elive/elive-for-servers" 1>&2
                exit 1
                ;;
        esac
    fi


    # backup etc before to install things
    if ! [[ -d "/etc.bak-before-elive" ]] ; then
        cp -a /etc /etc.bak-before-elive
    fi




    #
    # Create / import back users
    #

    prepare_environment start

    # root pass change {{{
    if ((is_change_pass_root)) ; then
        #if el_confirm "\nChange root pass?" ; then
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
        if ! installed_check "elive" ; then
            install_elive
        fi
    else
        #if ! [[ -s /etc/elive-version ]] ; then
        if installed_ask "elive" "This server has not yet Elive superpowers. Install them? (required)" ; then
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
    if ! installed_check "swapfile" 1>/dev/null 2>&1 && ! swapon -s | grep -qs "^/" ; then
        if [[ "$( cat /proc/meminfo | grep -i memtotal | head -1 | awk '{print $2}' )" -lt 1500000 ]] && ! swapon -s | grep -qs "^/" ; then
            if el_confirm "\nYour server doesn't has much RAM, do you want to add a swapfile?" ; then
                is_wanted_swapfile=1
            fi
        fi

        if ((is_wanted_swapfile)) ; then
            if ! [[ -s "/swapfile" ]] ; then
                dd if=/dev/zero of=/swapfile bs=1M count=1000
                chmod 0600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                sed -i -e '/^\/swapfile/d' /etc/fstab
                addconfig "/swapfile       swap          swap           defaults    0 0" /etc/fstab
            fi

            installed_set "swapfile" "Swap file is created and running, special 'swappiness' and 'watermark_scale_factor' configurations added in /etc/sysctl.conf for not bottleneck the server's HD"
        fi
    fi
    # tune
    if swapon -s | grep -qs "^/" ; then
        addconfig "vm.swappiness = 10" /etc/sysctl.conf
        addconfig "vm.watermark_scale_factor = 500" /etc/sysctl.conf
    fi
    # }}}

    # create user if not exist {{{
    if [[ -n "$username" ]] && ! [[ -d "$DHOME/${username}" ]] ; then
        install_user
    fi
    #}}}

    # install nginx {{{
    if ((is_wanted_nginx)) ; then
        if installed_ask "nginx" "You are going to install NGINX, it will remove apache if you have it. Continue?" ; then
            install_nginx
        fi
    fi
    # }}}

    # install php {{{
    if ((is_wanted_php)) ; then
        if installed_ask "php" "You are going to install PHP, it will include NGINX and remove apache if you have it. PHP-FPM will be installed too. Continue?" ; then
            install_php
        fi
    fi
    # }}}

    # install mysql / mariadb {{{
    if ((is_wanted_mariadb)) ; then
        if installed_ask "mariadb" "You are going to install MARIADB. Continue?" ; then
            install_mariadb
        fi
    fi
    # }}}

    # install wordpress {{{
    if ((is_wanted_wordpress)) ; then
        if el_confirm "You are going to install WORDPRESS, it will include nice optimizations to have it fast and responsive, will use nginx + php-fpm + mariadb, everything installed in a specific own user for security. Continue?" ; then
            install_wordpress
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

    # install chkrootkits {{{
    if ((is_wanted_rootkitcheck)) ; then
        if installed_ask "rootkitcheck" "You are going to install ROOTKIT checkers, it will run daily verifiers of the server. Continue?" ; then
            install_rootkitcheck
        fi
    fi
    # }}}

    # install iptables {{{
    if ((is_wanted_iptables)) ; then
        if installed_ask "iptables" "You are going to install IPTABLES (or use the installed UFW), it will include some default settings. Continue?" ; then
            install_iptables
        fi
    fi
    # }}}

    # LAST SERVICES TO INSTALL

    # install monit {{{
    if ((is_wanted_monit)) ; then
        #if [[ "$debian_version" = "buster" ]] ; then
            #NOREPORTS=1 el_warning "Ignoring install of MONIT because has no installation candidate for *Buster, press Enter to continue..."
            #read nothing
        #else
            if installed_ask "monit" "You are going to install MONIT, it will feature restarting services when they are found to be down. WE RECOMMEND to install first all the services you want to have. Continue?" ; then
                install_monit
            fi
        #fi
    fi
    # }}}

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
        #if el_confirm "\nIP $domain_ip not included in your /etc/hosts file, do you want to add it with your hostname and domains?" ; then
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
        if installed_ask "lynis" "You are going to install Lynis. Which is an audit tool that verify all the security of your server, it may include many false positives (or things that are set on this way on purpose), it has NO RELATION WITH ELIVE so use it entirely on your own just to see the settings of your server. Do you want to continue?" ; then

            packages_install \
                lynis

            lynis
            installed_set "lynis"
        fi
    fi



    #rm -rf /etc.bak-elive-allconfigured
    #cp -a /etc /etc.bak-elive-allconfigured
    #dpkg -l > /root/dpkg_-l.txt


    # install monitor for network bandwith usage (after to have transfered & installed all the files)
    if ((is_wanted_vnstat)) ; then
        if installed_ask "vnstat" "You are going to install VNSTAT. It will start collecting data, use the command 'vnstat' to check your bandwith usage. Continue?" ; then
            packages_install \
                vnstat

            installed_set "vnstat"
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




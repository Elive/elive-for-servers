# Elive for Servers, with superpowers!
Enjoy your server with Elive super-powers, where you can also optionally install well-tuned services in one shot!

_Important: this tool installs packages in your server to improve it with Elive features, and optionally full services too_

### Distros supported:
 * **Debian**: Bullseye, Buster
 * **Elive**: Elive versions on the same debian base versions previously said
 * **Ubuntu**: 21.10 "Impish", 21.04 "Irsute", 20.04 "Focal", 18.04 "Bionic"


_:warning: Note: Ubuntu installs are added for compatibility, but we **strongly** suggest to use Debian instead. If you use Ubuntu we don't accept but reports, only 'Pull requests' if you send the improvements/fixes_

## Features:
* Turn an slow or ugly server into a full **Elive featured** one
* Set up a very powerful server using the **lowest resources**! _optimized multiple wordpress websites & strong email server, including security protections and more_ in only  1 GB RAM server machine
* Install **Wordpress** with all the dependencies and special customizations, from zero to this in less than 2 minutes
  * _plugins: a selection of good needed plugins are also preinstalled, you can enable or delete them in your setup_
  * install multiple wordpress websites & subdomains in the same machine and still being light on resources (3 wordpress sites, full server setup, 171 MB ram)
* Install PHP / Mariadb / Nginx / or other listed services in one shot, already customized and optimized.
* Install an Exim **email server** featuring dovecot to read your emails on thunderbird and optional spamassassin
* Powerful configurations for **server tools** like VIM with plugins and the best color syntax, git status prompt, aliases, lots of handy shell things, etc
* The most featured and friendly Shell in the world!
  * zsh based with plugins and customizations, tunned to be friendly for bash users
  * Don't lose your working terminals if your connection is lost or while you sleep
  * Have multiple terminal sessions, split windows, history saved, etc
  * undo features!
  * tons of autocompletions for everything, like kill<tab>, directories and files, manpages, corrections, etc
  * hilightings, color reports
  * suggestions based on history commands while you type, press arrow-up to select the matches
  * directories history and switch, multiple sub-dirs as '...' featured
  * many, MANY more, just type "help" and check the dotfiles to know more details...

### _TODO: Document the many extra features and ways to use it, special tools included, etc..._

### Elive shell
![screenshot login](screenshots/screenshot-login.png)

_This is the login of your server after installing it, where you can see:_
* root user is always written and marked in red so you clearly know if you are root
* shell sessions automatically starts in tmux where you will not lose the work when disconnecting the terminal
* press ctrl + down to open more shells, ctrl + arrows to switch between them
* name of server is shown, datetime, opened windows, returned codes, etc

## **Install it** (from root):

 * Basic Elive features installation:

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" )`


### Installing extra services:

 * Install Wordpress:

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --install=wordpress`

 * Install Wordpress with an email server:

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --install=wordpress --install=exim`

 * Add an extra independent Wordpress website

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --install=wordpress --user=user2`

 * To create a new Elivised user (only):

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --user=johnsmith`

 * **Etc**.. See the Help showing more options:

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --help`


___Note: it's important to set all the options wanted in a single command, so that the configurator will know all the values to configure for the resulting system and have everything working___

## Services
 You can install services in one shot, like nginx / php / WORDPRESS / email server / etc... for example using the options:
 * --install=wordpress      - _full wordpress install with fine tunned options_
 * --install=exim           - _full email server with settings ready to use_
 * --install=php            - _php, includes many php versions_
 * --install=nginx          - _nginx webserver, includes SSL (httpS)_
 * --install=fail2ban       - _detect and ban bot attacks, automatically preconfigured for some services_
 * --install=mariadb        - _mysql database_
 * --install=monit          - _daemon that watch your services and restarts them in case they stopped to work_
 * --install=rootkitcheck   - _daemon to check daily your system to find posible rootkits malware_
 * --install=swapfile       - _creates a 1 GB swap file to help your server not having processes killed by memory exhausted_
 * --install=elivemirror-isos   - _Sets up a [mirror for the Elive ISOs](https://forum.elivelinux.org/t/how-to-be-a-mirror-for-elive/1298)_
 * --force                  - _it will force the reinstall of the services / options, even if was installed previously_
 * --freespace-system       - _it will remove up your system of unneeded things, making it faster, use it with CAUTION, it removes manpages, docs, locales, selinux_

## Details:
 * you can install many wordpress websites as you want, each one will be isolated on its own userspace and it will not require extra resources
 * if you have SSH keys to login included, the installation asks you if you want to disable password-based logins on ssh (so use only ssh-keys), and also asks if you want to change the port
 * phpinfo is not enabled by default, also nginx tokens (nginx version / info etc) are disabled
 * firewall is included and input ports closed by default, DURING the installation of services on elive-for-servers, the needed ports for these services are then configured to be open (so yeah, all working by default but only enabled for the wanted things)



## Collaboration:
You are welcome to send push commits for fixes and improvements, especially dynamic compatibility, but changing the behaviour of the tool will require a previous debate / brainstorm since some things can break if done differently. There's many different operating systems (and so different way to set up things, file locations, compatibilities, versions, etc...) so it's sometimes better to just stick to a debian base of which we know works well and is made for it.

## Testimonials:

> _"As I was a trainee in IT, we need to setup a LAMP and use HeidiSQL under windows. Since I was using Linux quite a time, I brought my laptop and got a fully functional server in 5 minutes. The rest of the class needed up to a whole day for the setup and understanding._" - _[Benjamin Møller](https://blog.lupuse.org/cv_de.html)_



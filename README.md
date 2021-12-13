# Elive superpowers on your Server ! w00t
Enjoy your server with some Elive super-powers, and you can also optionally install well-tuned services in one shot!

_Important: this tool will install packages in your server to improve it with Elive features, you can optionally install services too_

**Install it** (from root):

`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" )`

**Distros supported**: Debian buster, Debian bullseye.
**Ubuntu versions**: 21.10 impish, 21.04 irsute, 20.04 focal, 18.04 bionic
_Note: Ubuntu installs are added for compatibility, but we **strongly** suggest to use Debian instead, do not report bugs if you use ubuntu_ 

### Installing extra services:

_Install wordpress:_
`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --install=wordpress`

_Install wordpress with an email server_
`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --install=wordpress --install=exim`

_To create a new user:_
`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --user=johnsmith`

_Help & list with more options:_
`bash - <(curl -fsSLg -- "https://raw.githubusercontent.com/Elive/elive-for-servers/main/install-elive-on-server.sh" ) --help`

___Note: it's important to set all the options wanted in a single install, so that the configurator will know all the values to configure for the resulting system and have everything working___

## Features:
* Turn an ugly server into a full Elive powered one
* Install Wordpress with all the dependencies and special customizations, from zero to this in less than 2 minutes
  * _plugins: a selection of good needed plugins are also preinstalled, you can enable or delete them in your setup_
* Install PHP / Mariadb / Nginx / Exim email server / etc services in one shot
* Well tunned and optimized customizations for the services
* Powerful configurations for server tools like VIM with plugins and the best color syntax
* Git status prompt, aliases, etc...
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

### Elive shell
![screenshot login](screenshots/screenshot-login.png)

_This is the login of your server after installing it, description:_
* root user is always written and marked in red so you clearly know if you are root
* shell sessions automatically starts in tmux where you will not lose the work when disconnecting the terminal
* press ctrl + down to open more shells, ctrl + arrows to switch between them
* name of server is shown, datetime, opened windows, returned codes, etc
 
 ## Services
 You can install services in one shot, like nginx / php / WORDPRESS / email server / etc... for example using the options:
 * --install=wordpress      # full wordpress install with fine tunned options
 * --install=exim           # full email server with settings ready to use
 * --install=php            # php, includes many php versions
 * --install=nginx          # nginx webserver, includes SSL (httpS)
 * --install=fail2ban       # detect and ban bot attacks, automatically preconfigured for some services
 * --install=mariadb        # mysql database
 * --install=monit          # daemon that watch your services and restarts them in case they stopped to work



## Collaboration:
You are welcome to send push commits for fixes and improvements, especially dynamic compatibility, but to change the behaviour of the tool will require a previous debate / brainstorm since some things can break if done differently, since there's many different operating systems (and so different way to set up things, file locations, compatibilities, versions, etc...) it's sometimes better to just stick to a debian base of which we know works well and is made for it.

# phpmyadmin installed ?
#set $phpmyadmin "yes";

# redirect http to https?
set $redir_http_to_https "no";

# redirect non-wwww to www?
set $redir_to_www "yes";

# redirect http to https, this entry is also needed for your SSL certificate
if ($redir_http_to_https = yes ) {
    server {
        listen 80 ;
        listen [::]:80 ;

        server_name mywordpress.com;

        error_log /var/log/nginx/error.log ;

        # Necessary for Let's Encrypt Domain Name ownership validation
        location ^~ /.well-known/acme-challenge/ {
            try_files $uri /dev/null =404;
            default_type "text/plain";
        }

        # Needed for Certbot / Letsencrypt
        return 301 https://mywordpress.com$request_uri; # auto for certbot, do not remove this comment

        root /home/elivewp/mywordpress.com;
    }
}

# redirect 'mywordpress.com' to 'www.mywordpress.com'
if ($redir_to_www = yes ) {
    server_name mywordpress.com;

    if ($redir_http_to_https = yes ) {
        listen 443 [::]:443;
        return 301 https://www.mywordpress.com$request_uri;
    }
    if ($redir_http_to_https = no ) {
        listen 80 [::]:80;
        return 301 http://www.mywordpress.com$request_uri;
    }
}

# default wordpress configuration
server {
    if ($redir_http_to_https = yes ) {
        listen 443 [::]:443;
        #listen 80 [::]:80;
    }
    if ($redir_http_to_https = no ) {
        listen 80 [::]:80;
    }

    # do not show indexed files by defaul
    autoindex off;
    # don't show the nginx version
    server_tokens   off;


    server_name  mywordpress.com;
    root /home/elivewp/mywordpress.com;

    index index.php index.html index.htm;

    # local user's configurations, also needed for some plugins that writes their own confs
    include /home/elivewp/mywordpress.com/nginx.conf;

    # PHP-FPM health service monitoring at /ping
    location /ping {
        access_log off;
        allow 127.0.0.1; # localhost
        allow ::1; # IPv6 localhost
        #deny all;
        fastcgi_split_path_info ^(.+.php)(.*)$;
        fastcgi_pass unix:/var/run/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    # custom error pages
    #error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /etc/nginx/offline-pages/;
    }
    location / {
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location = /favicon.ico {
        access_log off;
        log_not_found off;
        expires max;
    }
    location = /robots.txt {
        access_log off;
        log_not_found off;
    }

    # Cache Static Files For As Long As Possible
    location ~*
        \.(ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|css|rss|atom|js|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$
        {
            access_log off;
            log_not_found off;
            expires max;
        }
    # Security Settings For Better Privacy Deny Hidden Files
    location ^~ /.well-known/        { allow all ; }
    location ~ /\.          { access_log off; log_not_found off; return 444; }
    # Return 403 Forbidden For readme.(txt|html) or license.(txt|html)
    if ($request_uri ~* "^.+(readme|license)\.(txt|html)$") {
        return 403;
    }
    # Disallow PHP In Upload Folder
    location /wp-content/uploads/ {
        location ~ \.php$ {
            deny all;
        }
    }

    if ($phpmyadmin = yes ) {

        location /phpmyadmin {
            auth_basic "Restricted";
            auth_basic_user_file /home/elivewp/mywordpress.com/.htpasswd;

            root /usr/share/;
            index index.php index.html index.htm;

            location ~ ^/phpmyadmin/(.+\.php)$ {
                try_files $uri =404;
                root /usr/share/;
                fastcgi_pass unix:/var/run/php7.4-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                include /etc/nginx/fastcgi_params;
            }
            location ~* ^/phpmyadmin/(.+\.(jpeg|jpg|png|css|gif|ico|js|html|xml|txt))$ {
                root /usr/share/;
            }
        }
    }
}



# vim: set syn=conf filetype=cfg expandtab : #

# default Wordpress configuration

# limit the requests to 50 per second
limit_req_zone $binary_remote_addr zone=wordpress:10m rate=10r/s;

server {
    listen 80;
    listen [::]:80;
    # do not show indexed files by defaul
    autoindex off;
    # don't show the nginx version
    server_tokens   off;

    # but allow shots of 1000 requests to not delay normal page loads
    limit_req zone=wordpress burst=1000 nodelay;

    server_name  mywordpress.com;
    root /home/elivewp/mywordpress.com;

    index index.php index.html index.htm;

    # local user's configurations, also needed for some plugins that writes their own confs
    include /home/elivewp/mywordpress.com/nginx.conf;
    include /home/elivewp/mywordpress.com/nginx-local.conf;

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
        fastcgi_pass unix:/run/php/php7.3-fpm-elivewp.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # PHP-FPM health service monitoring at /ping
    location /ping {
        access_log off;
        allow 127.0.0.1; # localhost
        allow ::1; # IPv6 localhost
        #deny all;
        fastcgi_split_path_info ^(.+.php)(.*)$;
        fastcgi_pass unix:/run/php/php7.3-fpm-elivewp.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # enable phpmyadmin access too but always from an admin password access
    location /phpmyadmin {
        auth_basic "Restricted";
        auth_basic_user_file /home/elivewp/mywordpress.com/.htpasswd;
        root /usr/share/;
        index index.php index.html index.htm;
        location ~ ^/phpmyadmin/(.+\.php)$ {
            try_files $uri =404;
            root /usr/share/;
            fastcgi_pass unix:/run/php/php7.3-fpm-elivewp.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
        }
        location ~* ^/phpmyadmin/(.+\.(jpeg|jpg|png|css|gif|ico|js|html|xml|txt))$ {
            root /usr/share/;
            access_log off;
            expires 30d;
        }
    }
    #
}

# vim: set syn=conf filetype=cfg expandtab : #

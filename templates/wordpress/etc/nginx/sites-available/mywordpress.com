server {
    listen 80;
    listen [::]:80;

    root /home/elivewp/mywordpress.com;
    index index.php index.html index.htm;

    server_name www.mywordpress.com mywordpress.com;

    error_page 404 /404.html;

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        #root /usr/share/nginx/html;
        root /etc/nginx/offline-pages/;
    }
    location / {
        # try_files $uri $uri/ =404;
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }


    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
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
}



# vim: set syn=conf filetype=cfg expandtab : #

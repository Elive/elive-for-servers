# default Elive Mirror configuration

# limit the requests to 50 per second
limit_req_zone $binary_remote_addr zone=elivemirror:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;

server {
    listen 80;
    listen [::]:80;
    # do not show indexed files by defaul
    # update: managed by the mirror itself
    #autoindex off;
    # don't show the nginx version
    server_tokens   off;

    # but allow shots of 1000 requests to not delay normal page loads
    limit_req zone=elivemirror burst=2000 nodelay;

    # limit connections per ip
    limit_conn conn_limit_per_ip 60;


    server_name  elivemirror.com;
    root /home/elivewp/elivemirror.com;

    index index.php index.html index.htm;

    # local user's configurations, also needed for some plugins that writes their own confs
    include /home/elivewp/elivemirror.com/.nginx.conf;

    # custom error pages
    #error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /etc/nginx/offline-pages/;
    }

    # disable logs for specific cases:
    location ~ "/i18n/"          { access_log off; log_not_found off; }
    location ~ "Packages.*"          { access_log off; log_not_found off; }
    location ~ "favicon.*"          { access_log off; log_not_found off; }
    # disable logs entirely
    error_log off;
    access_log off;
    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    location ~ /\.ht {
        deny all;
    }
    location ~ /db {
        deny all;
    }
}

# vim: set syn=conf filetype=cfg expandtab : #

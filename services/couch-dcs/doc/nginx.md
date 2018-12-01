# Nginx Settings

Add the following entry to `/etc/nginx/sites-enabled/example.com`

        location ^~ /couchdb/ {
            proxy_pass http://10.0.81.192:5984/;
            proxy_redirect off;
            proxy_buffering off;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

and use `http://example.com/couchdb` as db url.

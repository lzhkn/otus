Docker.sh

1.1 Проверяем версию ПО

root@ubuntu2402:~# docker --version
docker compose version
Docker version 29.0.1, build eedd969
Docker Compose version v2.40.3


root@ubuntu2402:~# docker compose version
Docker Compose version v2.40.3

1.2 Создаем папку

mkdir -p ~/docker/custom-nginx
cd ~/docker/custom-nginx

~/docker/custom-nginx

1.3 Пишем докер файл

root@ubuntu2402:~/docker/custom-nginx# cat > Dockerfile <<'EOF'
FROM alpine:3.20

# Устанавливаем nginx и необходимые утилиты
RUN apk update && \
    apk add --no-cache nginx && \
    mkdir -p /run/nginx

# Копируем нашу страницу в стандартную директорию nginx (alpine nginx)
COPY index.html /var/www/localhost/htdocs/index.html

EXPOSE 80

# Запуск nginx в foreground
CMD ["nginx", "-g", "daemon off;"]
EOF

1.4 Пишем базовый конфиг и страницу для веб сервера.

root@ubuntu2402:~/docker/custom-nginx# cat > index.html <<'EOF'

<h1>My custom NGINX page</h1>
<p>Работает с собственного Docker-образа!</p>
EOF



1.5 Пишем базовый конфиг и страницу для веб сервера.

root@ubuntu2402:~/docker/custom-nginx# cat > nginx.conf <<'EOF'
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

1.6 Собираем образ:

root@ubuntu2402:~/docker/custom-nginx# docker build -t my-nginx-alpine .

[+] Building 3.2s (9/9) FINISHED                                                                                      docker:default
 => [internal] load build definition from Dockerfile                                                                            0.1s
 => => transferring dockerfile: 565B                                                                                            0.0s
 => [internal] load metadata for docker.io/library/nginx:alpine                                                                 0.2s
 => [internal] load .dockerignore                                                                                               0.1s
 => => transferring context: 2B                                                                                                 0.0s
 => [1/4] FROM docker.io/library/nginx:alpine@sha256:b3c656d55d7ad751196f21b7fd2e8d4da9cb430e32f646adcf92441b72f82b14           0.2s
 => => resolve docker.io/library/nginx:alpine@sha256:b3c656d55d7ad751196f21b7fd2e8d4da9cb430e32f646adcf92441b72f82b14           0.2s
 => [internal] load build context                                                                                               0.1s
 => => transferring context: 171B                                                                                               0.0s
 => CACHED [2/4] RUN apk update && apk upgrade                                                                                  0.0s
 => CACHED [3/4] COPY nginx.conf /etc/nginx/nginx.conf                                                                          0.0s
 => [4/4] COPY index.html /usr/share/nginx/html/index.html                                                                      0.3s
 => exporting to image                                                                                                          1.6s
 => => exporting layers                                                                                                         0.6s
 => => exporting manifest sha256:5bcc679cc8ed712792e92983ce5e1d47969efcd525849078097a54f6527a8c11                               0.1s
 => => exporting config sha256:149b49448af8d13a73adbe3cf8ea8fbe5a6f84b83860ec8e06cb06f69eaf83ac                                 0.2s
 => => exporting attestation manifest sha256:4c509aaa7057677c4490cf8793c143f4c78df3b288e47f8779f6165ebf47c657                   0.2s
 => => exporting manifest list sha256:d4a35632d989d973b39d93fbf60499a00e9693555005a70d9564f71a55d88fb9                          0.2s
 => => naming to docker.io/library/my-nginx-alpine:latest                                                                       0.0s
 => => unpacking to docker.io/library/my-nginx-alpine:latest   
                                                                  0.2s
1.7 Запускаем контейнер:

root@ubuntu2402:~/docker/custom-nginx# docker run -d -p 8080:80 --name my-nginx-container my-nginx-alpine
465f4f7822ec046efb63c4dbf5e021d2bf98a940ca20646dfc1244107752b45d

1.8 Проверяем:

root@ubuntu2402:~/docker/custom-nginx# curl http://localhost:8080

<h1>My custom NGINX page</h1>
<p>Работает с собственного Docker-образа!</p>

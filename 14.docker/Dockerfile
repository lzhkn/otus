FROM nginx:alpine

# Обновление пакетов и установка дополнительных утилит (опционально)
RUN apk update && apk upgrade

# Копирование кастомной конфигурации nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Копирование кастомной страницы
COPY index.html /usr/share/nginx/html/index.html

# Открытие порта 80
EXPOSE 80

# Команда для запуска nginx
CMD ["nginx", "-g", "daemon off;"]
# Используем официальный стабильный образ Python
FROM python:3.11-slim

# Устанавливаем системные зависимости (нужны для сборки некоторых библиотек, например psycopg2 для dbt)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Настраиваем рабочую директорию внутри контейнера
WORKDIR /app

# Копируем список зависимостей и устанавливаем их
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем весь остальной код проекта в контейнер
COPY . .

# Открываем порт для Streamlit (по умолчанию 8501)
EXPOSE 8501

# Команда для запуска вашего Streamlit-приложения (замените main.py на ваш главный файл)
CMD ["streamlit", "run", "dashboard.py", "--server.port=8501", "--server.address=0.0.0.0"]

from python:3.11-alpine

RUN apk add --no-cache git postgresql-dev gcc libc-dev
RUN apk add --no-cache gcc g++ make libffi-dev python3-dev build-base

RUN pip install gunicorn
RUN pip install psycopg2
RUN pip install ipdb
RUN pip install ipython

WORKDIR /app

RUN git clone https://github.com/antonioluisjf22/EGC-2324-1830.git . && git checkout egc_test
RUN pip install -r requirements.txt

WORKDIR /app/decide

# Django settings module for Docker
ENV DJANGO_SETTINGS_MODULE=decide.settings
ENV PYTHONUNBUFFERED=1

# local settings.py
ADD docker-settings.py /app/decide/local_settings.py

RUN python manage.py collectstatic --noinput

#CMD ["gunicorn", "-w 5", "decide.wsgi", "--timeout=500", "-b 0.0.0.0:5000"]

FROM python:3.9

COPY /serve_py /app/serve_py
COPY /certs/ca.pem /app/ca.pem
RUN pip install --no-cache-dir -r /app/serve_py/requirements.txt

WORKDIR /app
CMD [ "python", "-m", "serve_py" ]


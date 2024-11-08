FROM nginx:1.27.1-alpine

COPY configs /configs/
COPY init /docker-entrypoint.d/

RUN find /docker-entrypoint.d -type f -exec sed -i -e 's/\r$//' {} \;
RUN chmod -R +x /docker-entrypoint.d

ENV WORKSPACE_ENVIRONMENT=local
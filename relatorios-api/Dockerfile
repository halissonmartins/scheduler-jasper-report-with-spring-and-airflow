# Esqueleto da fase inicial. A imagem de produção é construída na VM (ticket 30),
# a partir de SHA ou tag fixados — nunca de `main` HEAD.
FROM eclipse-temurin:25-jre

# curl existe aqui por causa do HEALTHCHECK do Compose. É peso deliberado:
# a alternativa seria o Compose não conseguir consultar o actuator.
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY target/relatorios-api-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

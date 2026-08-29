FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY target/engineering-acceptance-backend-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

FROM eclipse-temurin:21-jdk AS test
WORKDIR /workspace
COPY . .
RUN chmod +x mvnw
ENTRYPOINT ["./mvnw"]

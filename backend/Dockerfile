FROM eclipse-temurin:21-jdk AS build
ARG RELEASE_VERSION=0.0.0-dev
ARG GIT_COMMIT=unknown
WORKDIR /workspace
COPY .mvn .mvn
COPY mvnw pom.xml ./
COPY src src
RUN chmod +x mvnw && ./mvnw -q -DskipTests \
    -Drevision="$RELEASE_VERSION" -Dgit.commit="$GIT_COMMIT" package && \
    find target -maxdepth 1 -type f -name '*.jar' ! -name '*.original' \
      -exec cp '{}' target/application.jar \; && \
    test -s target/application.jar

FROM eclipse-temurin:21-jre AS runtime
ARG RELEASE_VERSION=0.0.0-dev
ARG GIT_COMMIT=unknown
ARG BUILD_TIME=1970-01-01T00:00:00Z
LABEL org.opencontainers.image.title="engineering-acceptance-backend" \
      org.opencontainers.image.version="$RELEASE_VERSION" \
      org.opencontainers.image.revision="$GIT_COMMIT" \
      org.opencontainers.image.created="$BUILD_TIME"
WORKDIR /app
COPY --from=build /workspace/target/application.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

FROM eclipse-temurin:21-jdk AS test
WORKDIR /workspace
COPY .mvn .mvn
COPY mvnw pom.xml ./
COPY src src
RUN chmod +x mvnw
ENTRYPOINT ["./mvnw"]

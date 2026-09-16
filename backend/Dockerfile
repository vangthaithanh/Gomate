FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn --batch-mode clean verify
FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S gomate && adduser -S gomate -G gomate
WORKDIR /app
COPY --from=build --chown=gomate:gomate /build/target/gomate-backend-1.0.0.jar app.jar
USER gomate
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

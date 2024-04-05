#!/bin/sh

# Name of container registry, which is in the 'docker.io/<account>' format' for DockerHub
crServer=$1

# Build application package
mvn clean package --file javaee-cafe/pom.xml
cp javaee-cafe/target/javaee-cafe.war ./build

# Download postgresql-42.2.4.jar if not existing
jdbcDriver=./build/postgresql-42.2.4.jar
if [ ! -f "jdbcDriver" ]; then
    wget -O "$jdbcDriver" https://repo1.maven.org/maven2/org/postgresql/postgresql/42.2.4/postgresql-42.2.4.jar
fi

# Build application image
docker build -t open-liberty-demo:1.0.0 -f ./build/Dockerfile --pull ./build
docker tag open-liberty-demo:1.0.0 ${crServer}/open-liberty-demo:1.0.0

# Push to specified container registry
docker login
docker push ${crServer}/open-liberty-demo:1.0.0

echo "The application image pushed to container registry is: ${crServer}/open-liberty-demo:1.0.0"

#!/bin/sh -x

echo "Generating java sources"
lcm-gen -j msg/*.lcm

echo "Compiling classes"
javac -classpath $(pkg-config lcm-java --variable=classpath) xat_msgs/*.java

echo "JAR packaging"
jar cf xat_msgs.jar xat_msgs/*.class

echo "Cleanup"
rm -rf xat_msgs

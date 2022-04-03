FROM ubuntu

WORKDIR /github/build-nodejs

RUN apt update && apt install wget python3 g++ make python3-pip git unzip curl -y

# 下载Android NDK
RUN wget -q https://dl.google.com/android/repository/android-ndk-r23b-linux.zip && unzip -q android-ndk-r23b-linux.zip

COPY node-build.sh node-build.sh

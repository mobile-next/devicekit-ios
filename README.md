# DeviceKit iOS

## ScreenStreaming

### TCP Swift Package

Basic TCP server and client utilizing Apple's [Network](https://developer.apple.com/documentation/network) framework. The server runs on the real device on the port 12005 by default and expects incoming connections. 

### H264 Codec Swift Package

[Video Toolbox](https://developer.apple.com/documentation/videotoolbox) is a core framework used for compression and decompression.

### devicekit-ios App

A sample app with an Extension 

### Local dev testing

#### Gstreamer setup with Docker:

- Pull this [container](https://hub.docker.com/layers/restreamio/gstreamer/2023-12-05T16-57-29Z-prod/images/sha256-be449bc2d2673b68afa9a0d35769ce7a96c2d33fd05229d4af03805cdf96f680?context=explore) with gstreamer 1.26.x version

```
docker pull restreamio/gstreamer:2023-12-05T16-57-29Z-prod
```

- Run the container 
```
docker run -ti 375dff539ee9e4b01aef020049cdaeac3b2213b59e118405be645586db408ebd
```

#### Device streaming service setup:

- Check the ip address on the device:
```
Settings -> WiFi -> Tap on "Info" icon -> copy valu from IP Address cell
```

- Run the ScreenStreamerServer App on the real iOS device

- In the opened app on the device:
```
Select "BroadcastUploadExtensions" -> Press "Start Broadcast"
```

#### Run:

- Run the gstreamer pipeline in the running docker container to record the video in mp4 file:
```
export DEVICE_IP_ADDRESS=your_device_ip_address

gst-launch-1.0 tcpclientsrc -e do-timestamp=true host=$DEVICE_IP_ADDRESS port=12005 ! h264parse ! h264timestamper ! identity sync=true ! mp4mux ! filesink location=sintel_video.mp4
```

- Stop the gstreamer recording (ctrl + C)

#### Copy the video to Host

```
docker cp container_id:/sintel_video.mp4 sintel_video.mp4
```

#### Building `app`:
```
xcodebuild \
  -workspace devicekit-ios.xcworkspace \
  -scheme devicekit-ios \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

#### Building `runner`:
```
Xcode -> Product -> Build For -> Testing
```

#### Building `ipa`:
- create a dir `Payload`
- move `.app` artifact to `Payload` dir
- zip the `Payload` dir and rename `zip` extension to `ipa`

### Useful links
- https://blog.video.ibm.com/streaming-video-tips/keyframes-interframe-video-compression/
- https://en.wikipedia.org/wiki/Network_Abstraction_Layer
- https://en.wikipedia.org/wiki/Advanced_Video_Coding
- https://developer.apple.com/videos/play/wwdc2014/513/

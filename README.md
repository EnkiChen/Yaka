# Yaka

一个用来支持日常开发的辅助工具，当前包括以下功能：

* 支持从摄像头、屏幕以及文件中采集数据；
* 支持 x264、openh264 以及 VideoToolBox 的编解码；
* 支持 OpenGL、Metal 以及 AVSampleBufferDisplayLayer 方式进行渲染；

当前依赖以下第三方库：

* x264：用来做 h264 的编码；
* Openh264： 用来做 h264 的编码和解码；
* libyuv：用来做 yuv 数据的操作；
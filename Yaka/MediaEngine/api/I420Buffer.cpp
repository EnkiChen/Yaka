//
//  I420BufferImp.cpp
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#include "I420Buffer.h"

int I420DataSize(int height, int stride_y, int stride_u, int stride_v) {
    return stride_y * height + (stride_u + stride_v) * ((height + 1) / 2);
}
namespace YUV {

I420Buffer::I420Buffer(int width, int height)
  : I420Buffer(width, height, width, (width + 1) / 2, (width + 1) / 2) {
}

I420Buffer::I420Buffer(int width, int height, int stride_y, int stride_u, int stride_v)
  : width_(width),
    height_(height),
    stride_y_(stride_y),
    stride_u_(stride_u),
    stride_v_(stride_v),
    data_(static_cast<uint8_t*>(malloc(I420DataSize(height, stride_y, stride_u, stride_v)))) {
}

I420Buffer::~I420Buffer() {
    
}

// static
std::shared_ptr<I420Buffer> I420Buffer::Create(int width, int height) {
    return  std::shared_ptr<I420Buffer>(new I420Buffer(width, height));
}

// static
std::shared_ptr<I420Buffer> I420Buffer::Create(int width, int height, int stride_y, int stride_u, int stride_v) {
    return std::shared_ptr<I420Buffer>(new I420Buffer(width, height, stride_y, stride_u, stride_v));
}

void I420Buffer::InitializeData() {
    memset(data_.get(), 0, I420DataSize(height_, stride_y_, stride_u_, stride_v_));
}

int I420Buffer::width() const {
    return width_;
}

int I420Buffer::height() const {
    return height_;
}

uint8_t* I420Buffer::DataY() {
    return data_.get();
}

uint8_t* I420Buffer::DataU() {
    uint8_t* datau = data_.get() + stride_y_ * height_;
    return datau;
}

uint8_t* I420Buffer::DataV() {
    uint8_t* datav = data_.get() + stride_y_ * height_ + stride_u_ * ((height_ + 1) / 2);
    return datav;
}

int I420Buffer::StrideY() const {
    return stride_y_;
}

int I420Buffer::StrideU() const {
    return stride_u_;
}

int I420Buffer::StrideV() const {
    return stride_v_;
}

}

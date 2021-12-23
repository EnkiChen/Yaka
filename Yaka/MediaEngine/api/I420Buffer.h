//
//  I420Buffer.h
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#ifndef YUV_I420BUFFER_H
#define YUV_I420BUFFER_H

#include <stdio.h>
#include <memory>

namespace YUV {

class I420Buffer {
public:
    static std::shared_ptr<I420Buffer> Create(int width, int height);
    static std::shared_ptr<I420Buffer> Create(int width, int height, int stride_y, int stride_u, int stride_v);
    
    ~I420Buffer();
    
    void InitializeData();
    
    int width() const;
    int height() const;
    
    uint8_t* DataY();
    uint8_t* DataU();
    uint8_t* DataV();
    
    int StrideY() const;
    int StrideU() const;
    int StrideV() const;
    
protected:
    I420Buffer(int width, int height);
    I420Buffer(int width, int height, int stride_y, int stride_u, int stride_v);
    
private:
    const int width_;
    const int height_;
    const int stride_y_;
    const int stride_u_;
    const int stride_v_;
    const std::unique_ptr<uint8_t> data_;
};

}

#endif /* YUV_I420BUFFER_H */

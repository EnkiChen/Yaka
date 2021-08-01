//
//  YuvHelper.cpp
//  Yaka
//
//  Created by Enki on 2019/10/17.
//  Copyright © 2019 Enki. All rights reserved.
//

#include "YuvHelper.h"
#include <stdio.h>
#include <iostream>
#include <memory>
#include "libyuv.h"

namespace  {

size_t read_data(unsigned char* buffer, int lenght, FILE *fd) {
    size_t read_size = 0;
    size_t total_size = 0;
    do {
        read_size = fread(buffer + total_size, 1, lenght - total_size, fd);
        total_size += read_size;
    } while ( read_size != 0 && total_size != lenght );
    return total_size;
}

}

void scaleYUV(const char *src_file, int width, int height, const char *dst_file, int dst_width, int dst_height)
{
    FILE *in_fd = fopen(src_file, "rb");
    FILE *out_fd = fopen(dst_file, "wb");
    
    if ( in_fd == NULL || out_fd == NULL ) {
        return;
    }
    
    int in_frame_size = width * height * 3 / 2;
    unsigned char *in_buffer = new unsigned char[in_frame_size];
    memset(in_buffer, 0, in_frame_size);
    
    int stride_y = width;
    int stride_u = (width + 1) / 2;
    int stride_v = (width + 1) / 2;
    
    unsigned char *DataY = in_buffer;
    unsigned char *DataU = in_buffer + stride_y * height;
    unsigned char *DataV = in_buffer + stride_y * height + stride_u * ((height + 1) / 2);
    
    int out_frame_size = dst_width * dst_height * 3 / 2;
    unsigned char *out_buffer = new unsigned char[out_frame_size];
    
    int dst_stride_y = dst_width;
    int dst_stride_u = (dst_width + 1) / 2;
    int dst_stride_v = (dst_width + 1) / 2;
    
    unsigned char *dst_DataY = out_buffer;
    unsigned char *dst_DataU = out_buffer + dst_stride_y * dst_height;
    unsigned char *dst_DataV = out_buffer + dst_stride_y * dst_height + dst_stride_u * ((dst_height + 1) / 2);
    
    size_t read_size = read_data(in_buffer, in_frame_size, in_fd);
    while ( read_size != 0) {
        
        libyuv::I420Scale(DataY, stride_y, DataU, stride_u, DataV, stride_v, width, height,
                          dst_DataY, dst_stride_y, dst_DataU, dst_stride_u, dst_DataV, dst_stride_v, dst_width, dst_height,
                          libyuv::kFilterBox);
        
        size_t ws = fwrite(out_buffer, 1, out_frame_size, out_fd);
        
        if ( ws != out_frame_size ) {
            std::cout << "write fail." << std::endl;
        }
        
        read_size = read_data(in_buffer, in_frame_size, in_fd);
    }
    
    fclose(in_fd);
    fclose(out_fd);
}

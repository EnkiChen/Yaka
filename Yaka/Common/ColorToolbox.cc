//
//  ColorToolbox.c
//  Yaka
//
//  Created by Enki on 2022/5/26.
//  Copyright © 2022 Enki. All rights reserved.
//

#include "ColorToolbox.h"

void rgbToYuvBT2020(uint16_t r, uint16_t g, uint16_t b, uint16_t *y, uint16_t *u, uint16_t *v) {
    *y = 0.2627f * r + 0.678f * g + 0.0593f * b;
    *u = -0.1396f * r - 0.3604f * g + 0.5f * b;
    *v = 0.5f * r - 0.4598f * g - 0.0402f * b;
    
    // UV 范围 -512 ~ +512，这里加 512，变为 0 ~ 1024
    *u += 512;
    *v += 512;
}

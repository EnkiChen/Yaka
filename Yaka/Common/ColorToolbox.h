//
//  ColorToolbox.h
//  Yaka
//
//  Created by Enki on 2022/5/26.
//  Copyright © 2022 Enki. All rights reserved.
//

#ifndef ColorToolbox_h
#define ColorToolbox_h

#include <stdint.h>

void rgbToYuvBT2020(uint16_t r, uint16_t g, uint16_t b, uint16_t *y, uint16_t *u, uint16_t *v);

#endif /* ColorToolbox_h */

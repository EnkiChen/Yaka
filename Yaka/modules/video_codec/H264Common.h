//
//  H264Common.h
//  Yaka
//
//  Created by Enki on 2019/10/9.
//  Copyright © 2019 Enki. All rights reserved.
//

#ifndef H264Common_h
#define H264Common_h

namespace H264 {
// The size of a full NALU start sequence {0 0 0 1}, used for the first NALU
// of an access unit, and for SPS and PPS blocks.
const size_t kNaluLongStartSequenceSize = 4;

// The size of a shortened NALU start sequence {0 0 1}, that may be used if
// not the first NALU of an access unit or an SPS or PPS block.
const size_t kNaluShortStartSequenceSize = 3;

// The size of the NALU type byte (1).
const size_t kNaluTypeSize = 1;

enum NaluType : uint8_t {
    kSlice = 1,
    kIdr = 5,
    kSei = 6,
    kSps = 7,
    kPps = 8,
    kAud = 9,
    kEndOfSequence = 10,
    kEndOfStream = 11,
    kFiller = 12,
    kTemporal = 14,
    kStapA = 24,
    kFuA = 28
};

enum SliceType : uint8_t {
    kP = 0,
    kB = 1,
    kI = 2,
    kSp = 3,
    kSi = 4
};
    
inline NaluType naluType(uint8_t code)
{
    return NaluType(code & 0x1F);
}

inline bool isNalu(unsigned char *buffer)
{
    return buffer[0] == 0x00 && buffer[1] == 0x00 && buffer[2] == 0x00 && buffer[3] == 0x01;
}
    
}

#endif /* H264Common_h */

//
//  kernels.metal
//  LightAnchors
//
//  Created by Nick Wilkerson on 2/7/19.
//  Copyright © 2019 Wiselab. All rights reserved.
//

#include <metal_stdlib>
#include <metal_math>
//#include <metal_integer>

//#define NUM_PREAMBLE_BITS 6
//#define NUM_DATA_BITS 6
#define NUM_SNR_BASELINE_BITS 4

#define NUM_DATA_CODES 4//2//32
#define NUM_DATA_BUFFERS 16
#define NUM_BASELINE_BUFFERS 4
#define SNR_THRESHOLD 1.5



using namespace metal;

//constant char threshold [[ function_constant(0) ]];
//constant char preamble [[ function_constant(1) ]];



/* iterate over entire preamble every frame */
kernel void matchPreamble(
                          const device uchar4 *image [[ buffer(0) ]],
                          device ushort *dataCodesBuffer [[ buffer(1) ]],
                          device ushort4 *actualDataBuffer [[ buffer(2) ]],
                          device uint4 *matchBuffer [[ buffer(3) ]],
                          device uchar4 *dataMinBuffer [[ buffer(4) ]],
                          device uchar4 *dataMaxBuffer [[ buffer(5) ]],
                          device uchar4 *baselineMinBuffer [[ buffer(6) ]],
                          device uchar4 *baselineMaxBuffer [[ buffer(7) ]],
                          device uchar4 *matchCounterBuffer [[ buffer(8) ]],
                          const device uchar4 *prevImage1 [[ buffer(9) ]],
                          const device uchar4 *prevImage2 [[ buffer(10) ]],
                          const device uchar4 *prevImage3 [[ buffer(11) ]],
                          const device uchar4 *prevImage4 [[ buffer(12) ]],
                          const device uchar4 *prevImage5 [[ buffer(13) ]],
                          const device uchar4 *prevImage6 [[ buffer(14) ]],
                          const device uchar4 *prevImage7 [[ buffer(15) ]],
                          const device uchar4 *prevImage8 [[ buffer(16) ]],
                          const device uchar4 *prevImage9 [[ buffer(17) ]],
                          const device uchar4 *prevImage10 [[ buffer(18) ]],
                          const device uchar4 *prevImage11 [[ buffer(19) ]],
                          const device uchar4 *prevImage12 [[ buffer(20) ]],
                          const device uchar4 *prevImage13 [[ buffer(21) ]],
                          const device uchar4 *prevImage14 [[ buffer(22) ]],
                          const device uchar4 *prevImage15 [[ buffer(23) ]],
                          
                          const device uchar4 *prevImage16 [[ buffer(24) ]],
                          const device uchar4 *prevImage17 [[ buffer(25) ]],
                          const device uchar4 *prevImage18 [[ buffer(26) ]],
                          const device uchar4 *prevImage19 [[ buffer(27) ]],
                          
                          uint id [[ thread_position_in_grid ]]
                          ) {
    /* preamble detector */
    if (matchBuffer[id][0] == 0 && matchBuffer[id][1] == 0 && matchBuffer[id][2] == 0 && matchBuffer[id][3] == 0) {
        
        uchar4 baselineBuffers[NUM_BASELINE_BUFFERS];
        baselineBuffers[0] = prevImage19[id];
        baselineBuffers[1] = prevImage18[id];
        baselineBuffers[2] = prevImage17[id];
        baselineBuffers[3] = prevImage16[id];
        
        uchar4 imageBuffers[NUM_DATA_BUFFERS];
        //        imageBuffers[0] = prevImage15[id];
        //        imageBuffers[1] = prevImage14[id];
        //        imageBuffers[2] = prevImage13[id];
        //        imageBuffers[3] = prevImage12[id];
        imageBuffers[0] = prevImage11[id];
        imageBuffers[1] = prevImage10[id];
        imageBuffers[2] = prevImage9[id];
        imageBuffers[3] = prevImage8[id];
        imageBuffers[4] = prevImage7[id];
        imageBuffers[5] = prevImage6[id];
        imageBuffers[6] = prevImage5[id];
        imageBuffers[7] = prevImage4[id];
        imageBuffers[8] = prevImage3[id];
        imageBuffers[9] = prevImage2[id];
        imageBuffers[10] = prevImage1[id];
        imageBuffers[11] = image[id];
        
        /* calculate threshold */
        /* looking at previous images and current images means that the first bit of data we are looking for must be 1 */
        uchar4 minValue = min(0xFF, image[id]);
        uchar4 maxValue = max(0, image[id]);
        for (int i = 0; i<12; i++) {
            uchar4 buffer = imageBuffers[i];
            minValue = min(minValue, buffer);
            maxValue = max(maxValue, buffer);
        }
        uchar4 thresh = (uchar4)(((ushort4)maxValue+(ushort4)minValue)/2);
        
        ushort4 bit = (ushort4)(image[id] > thresh);
        
        actualDataBuffer[id] = (actualDataBuffer[id] << 1) | bit;
        ushort4 restrictedActualData = actualDataBuffer[id] & 0x0FFF;
        //  ushort4 restrictedActualData = actualDataBuffer[id];
        uint4 matches = 0;
        for (int i=0; i<NUM_DATA_CODES; i++) {
            ushort dataCode = dataCodesBuffer[i];
            uint4 match = (uint4)((restrictedActualData ^ dataCode) == 0);
            matches = matches | (match << i);
        }
        
        if (any(matches != 0) ) {
            uchar4 baselineMinValue = 0xFF;
            uchar4 baselineMaxValue = 0;
            for (int i=0; i<NUM_BASELINE_BUFFERS; i++) {
                uchar4 buffer = baselineBuffers[i][id];
                baselineMinValue = min(baselineMinValue, buffer);
                baselineMaxValue = max(baselineMaxValue, buffer);
            }
            half4 snr = (half4)(maxValue-minValue)/ (half4)(baselineMaxValue-baselineMinValue);
            uint4 acceptMask = (uint4)(snr > SNR_THRESHOLD) * 0xFFFFFFFF;
            uint4 acceptedMatches = matches & acceptMask;
            matchBuffer[id] = acceptedMatches;
        }
        
    } else {
        /* how long to keep matches for */
        matchCounterBuffer[id] += (uchar4)(matchBuffer != 0);
        if (any(matchCounterBuffer[id] == 20)) {
            matchCounterBuffer[id] = 0;
            matchBuffer[id] = 0;
        }
        
    }
    
    
    
}





kernel void difference(const device char4 *imageA [[ buffer(0) ]],
                       const device char4 *imageB [[ buffer(1) ]],
                       device char4 *diff [[ buffer(2) ]],
                       uint id [[ thread_position_in_grid ]] ) {
    //    uint firstIndex = id * NUM_PIXELS_PER_THREAD;
    //    uint endIndex = firstIndex+NUM_PIXELS_PER_THREAD;
    //    for (uint i = firstIndex; i<endIndex; i++) {
    //        char d = (char)abs(imageA[i]-imageB[i]);
    //        diff[i] = d;
    //    }
    
    diff[id] = abs(imageA[id]-imageB[id]);
    
}


#define NUM_PIXELS_PER_THREAD 21600 //for 128 threads

kernel void max(const device char *diff [[ buffer(0) ]],
                device char *maxValueArray [[ buffer(1) ]],
                device uint *maxIndexArray [[ buffer(2) ]],
                uint id [[ thread_position_in_grid ]] ) {
    
    uint firstIndex = id * NUM_PIXELS_PER_THREAD;
    uint endIndex = firstIndex+NUM_PIXELS_PER_THREAD;
    uint maxIndex = 0;
    char maxValue = 0;
    for (uint i = firstIndex; i<endIndex; i++) {
        if (diff[i] > maxValue) {
            maxValue = diff[i];
            maxIndex = i;
        }
    }
    maxValueArray[id] = maxValue;
    maxIndexArray[id] = maxIndex;
}


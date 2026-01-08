#ifndef OPUS_ENCODER_WRAPPER_H
#define OPUS_ENCODER_WRAPPER_H

#include <stdint.h>
#include <opus.h>

typedef OpusEncoder *OpusEncoderRef;

OpusEncoderRef OpusEncoderCreate(int sampleRate, int channels, int bitrate, int *error);
void OpusEncoderDestroy(OpusEncoderRef encoder);

int OpusEncoderEncode(
    OpusEncoderRef encoder,
    const int16_t *pcm,
    int frameSize,
    uint8_t *data,
    int maxDataBytes
);

int OpusEncoderSetBitrate(OpusEncoderRef encoder, int bitrate);

#endif

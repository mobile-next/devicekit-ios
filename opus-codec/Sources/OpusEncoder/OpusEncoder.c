#include "OpusEncoder.h"

OpusEncoderRef OpusEncoderCreate(int sampleRate, int channels, int bitrate, int *error) {
    int err = OPUS_OK;
    OpusEncoder *encoder = opus_encoder_create(sampleRate, channels, OPUS_APPLICATION_AUDIO, &err);
    if (err != OPUS_OK) {
        if (error != NULL) {
            *error = err;
        }

        return NULL;
    }

    opus_encoder_ctl(encoder, OPUS_SET_BITRATE(bitrate));
    if (error != NULL) {
        *error = OPUS_OK;
    }

    return encoder;
}

int OpusEncoderEncode(OpusEncoderRef encoder, const int16_t *pcm, int frameSize, uint8_t *data, int maxDataBytes) {
    if (encoder == NULL) {
        return OPUS_BAD_ARG;
    }

    return opus_encode(encoder, (const opus_int16 *)pcm, frameSize, data, maxDataBytes);
}

int OpusEncoderSetBitrate(OpusEncoderRef encoder, int bitrate) {
    if (encoder == NULL) {
        return OPUS_BAD_ARG;
    }

    return opus_encoder_ctl(encoder, OPUS_SET_BITRATE(bitrate));
}

void OpusEncoderDestroy(OpusEncoderRef encoder) {
    if (encoder == NULL) {
        return;
    }

    opus_encoder_destroy(encoder);
}

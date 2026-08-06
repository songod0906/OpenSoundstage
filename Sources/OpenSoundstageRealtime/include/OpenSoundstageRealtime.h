// SPDX-License-Identifier: MIT

#ifndef OPEN_SOUNDSTAGE_REALTIME_H
#define OPEN_SOUNDSTAGE_REALTIME_H

#include <stddef.h>

typedef struct OSSWaveformRing OSSWaveformRing;

OSSWaveformRing *oss_waveform_ring_create(size_t capacity);
void oss_waveform_ring_destroy(OSSWaveformRing *ring);
void oss_waveform_ring_clear(OSSWaveformRing *ring);

void oss_waveform_ring_write_interleaved(
    OSSWaveformRing *ring,
    const float *samples,
    size_t frame_count);

void oss_waveform_ring_write_planar(
    OSSWaveformRing *ring,
    const float *left,
    const float *right,
    size_t frame_count);

size_t oss_waveform_ring_copy_latest(
    const OSSWaveformRing *ring,
    float *left,
    float *right,
    size_t maximum_frame_count);

#endif

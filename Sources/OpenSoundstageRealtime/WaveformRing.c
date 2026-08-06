// SPDX-License-Identifier: MIT

#include "OpenSoundstageRealtime.h"

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

_Static_assert(sizeof(uint_least32_t) == sizeof(float), "Waveform slots must fit Float32 bits");

struct OSSWaveformRing {
  size_t capacity;
  _Atomic uint_least32_t *left;
  _Atomic uint_least32_t *right;
  _Atomic uint_least64_t write_cursor;
};

static uint_least32_t float_bits(float value) {
  uint32_t bits = 0;
  memcpy(&bits, &value, sizeof(value));
  return bits;
}

static float bits_float(uint_least32_t bits) {
  uint32_t narrowed = (uint32_t)bits;
  float value = 0;
  memcpy(&value, &narrowed, sizeof(value));
  return value;
}

OSSWaveformRing *oss_waveform_ring_create(size_t capacity) {
  if (capacity == 0) {
    return NULL;
  }

  OSSWaveformRing *ring = calloc(1, sizeof(OSSWaveformRing));
  if (ring == NULL) {
    return NULL;
  }

  ring->left = calloc(capacity, sizeof(*ring->left));
  ring->right = calloc(capacity, sizeof(*ring->right));
  if (ring->left == NULL || ring->right == NULL) {
    free(ring->left);
    free(ring->right);
    free(ring);
    return NULL;
  }

  ring->capacity = capacity;
  for (size_t index = 0; index < capacity; index++) {
    atomic_init(&ring->left[index], 0);
    atomic_init(&ring->right[index], 0);
  }
  atomic_init(&ring->write_cursor, 0);
  return ring;
}

void oss_waveform_ring_destroy(OSSWaveformRing *ring) {
  if (ring == NULL) {
    return;
  }
  free(ring->left);
  free(ring->right);
  free(ring);
}

void oss_waveform_ring_clear(OSSWaveformRing *ring) {
  if (ring == NULL) {
    return;
  }
  atomic_store_explicit(&ring->write_cursor, 0, memory_order_release);
}

static void write_frame(
    OSSWaveformRing *ring,
    uint_least64_t cursor,
    float left,
    float right) {
  size_t index = (size_t)(cursor % ring->capacity);
  atomic_store_explicit(&ring->left[index], float_bits(left), memory_order_relaxed);
  atomic_store_explicit(&ring->right[index], float_bits(right), memory_order_relaxed);
}

void oss_waveform_ring_write_interleaved(
    OSSWaveformRing *ring,
    const float *samples,
    size_t frame_count) {
  if (ring == NULL || samples == NULL || frame_count == 0) {
    return;
  }

  uint_least64_t cursor = atomic_load_explicit(&ring->write_cursor, memory_order_relaxed);
  for (size_t frame = 0; frame < frame_count; frame++) {
    write_frame(ring, cursor + frame, samples[frame * 2], samples[frame * 2 + 1]);
  }
  atomic_store_explicit(&ring->write_cursor, cursor + frame_count, memory_order_release);
}

void oss_waveform_ring_write_planar(
    OSSWaveformRing *ring,
    const float *left,
    const float *right,
    size_t frame_count) {
  if (ring == NULL || left == NULL || right == NULL || frame_count == 0) {
    return;
  }

  uint_least64_t cursor = atomic_load_explicit(&ring->write_cursor, memory_order_relaxed);
  for (size_t frame = 0; frame < frame_count; frame++) {
    write_frame(ring, cursor + frame, left[frame], right[frame]);
  }
  atomic_store_explicit(&ring->write_cursor, cursor + frame_count, memory_order_release);
}

size_t oss_waveform_ring_copy_latest(
    const OSSWaveformRing *ring,
    float *left,
    float *right,
    size_t maximum_frame_count) {
  if (ring == NULL || left == NULL || right == NULL || maximum_frame_count == 0) {
    return 0;
  }

  uint_least64_t end = atomic_load_explicit(&ring->write_cursor, memory_order_acquire);
  size_t available = end < ring->capacity ? (size_t)end : ring->capacity;
  size_t count = available < maximum_frame_count ? available : maximum_frame_count;
  uint_least64_t start = end - count;

  for (size_t frame = 0; frame < count; frame++) {
    size_t index = (size_t)((start + frame) % ring->capacity);
    left[frame] = bits_float(atomic_load_explicit(&ring->left[index], memory_order_relaxed));
    right[frame] = bits_float(atomic_load_explicit(&ring->right[index], memory_order_relaxed));
  }
  return count;
}

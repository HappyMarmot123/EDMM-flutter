package com.ryanheise.just_audio;

import android.os.Handler;
import androidx.media3.common.C;
import androidx.media3.exoplayer.audio.TeeAudioProcessor;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicIntegerArray;

/** Copies decoded PCM into a bounded mailbox and analyzes it off the playback thread. */
final class SpectrumAudioBufferSink implements TeeAudioProcessor.AudioBufferSink {
    interface Listener {
        void onSpectrumEvent(Map<String, Object> event);
    }

    static final int BIN_COUNT = 24;
    private static final int FFT_SIZE = 1024;
    private static final int SLOT_COUNT = 3;
    private static final int SLOT_FREE = 0;
    private static final int SLOT_WRITING = 1;
    private static final int SLOT_READY = 2;
    private static final int SLOT_READING = 3;
    private static final long FRAME_PERIOD_MILLIS = 40;
    private static final double MIN_FREQUENCY_HZ = 40.0;
    private static final double MAX_FREQUENCY_HZ = 20000.0;
    private static final double MIN_DECIBELS = -80.0;

    private final Handler mainHandler;
    private final Listener listener;
    private final float[][] mailbox = new float[SLOT_COUNT][FFT_SIZE];
    private final int[] mailboxSampleRates = new int[SLOT_COUNT];
    private final AtomicIntegerArray mailboxStates = new AtomicIntegerArray(SLOT_COUNT);
    private final AtomicBoolean resetRequested = new AtomicBoolean(true);
    private final AtomicInteger captureGeneration = new AtomicInteger();
    private final ScheduledExecutorService analysisExecutor;
    private final double[] fftReal = new double[FFT_SIZE];
    private final double[] fftImaginary = new double[FFT_SIZE];
    private final double[] window = new double[FFT_SIZE];
    private final double[] smoothedBins = new double[BIN_COUNT];

    private volatile boolean listenerAttached;
    private volatile boolean pcmSupported;
    private volatile String forcedUnavailableReason;
    private volatile int sampleRateHz;
    private volatile int channelCount;
    private volatile int encoding;
    private ScheduledFuture<?> analysisTask;

    // The following fields are touched only by ExoPlayer's audio thread.
    private int writerSlot = -1;
    private int writerPosition;

    SpectrumAudioBufferSink(Handler mainHandler, Listener listener) {
        this.mainHandler = mainHandler;
        this.listener = listener;
        for (int i = 0; i < FFT_SIZE; i++) {
            window[i] = 0.5 - 0.5 * Math.cos(2.0 * Math.PI * i / (FFT_SIZE - 1));
        }
        ThreadFactory threadFactory = runnable -> {
            Thread thread = new Thread(runnable, "just_audio-spectrum");
            thread.setDaemon(true);
            return thread;
        };
        analysisExecutor = Executors.newSingleThreadScheduledExecutor(threadFactory);
    }

    void startCapture(String unavailableReason) {
        captureGeneration.incrementAndGet();
        listenerAttached = true;
        forcedUnavailableReason = unavailableReason;
        resetRequested.set(true);
        clearReadySlots();
        if (analysisTask == null || analysisTask.isCancelled()) {
            analysisTask = analysisExecutor.scheduleAtFixedRate(
                this::analyzeLatestSlot,
                0,
                FRAME_PERIOD_MILLIS,
                TimeUnit.MILLISECONDS);
        }
        if (unavailableReason != null) {
            postAvailability(false, unavailableReason);
        } else if (pcmSupported) {
            postAvailability(true, null);
        } else {
            postAvailability(false, "pcmUnavailable");
        }
    }

    void stopCapture() {
        captureGeneration.incrementAndGet();
        listenerAttached = false;
        forcedUnavailableReason = null;
        ScheduledFuture<?> task = analysisTask;
        analysisTask = null;
        if (task != null) task.cancel(false);
        resetRequested.set(true);
    }

    void dispose() {
        stopCapture();
        analysisExecutor.shutdownNow();
    }

    @Override
    public void flush(int sampleRateHz, int channelCount, @C.PcmEncoding int encoding) {
        this.sampleRateHz = sampleRateHz;
        this.channelCount = channelCount;
        this.encoding = encoding;
        pcmSupported = sampleRateHz > 0 &&
            channelCount > 0 &&
            (encoding == C.ENCODING_PCM_16BIT || encoding == C.ENCODING_PCM_FLOAT);
        resetRequested.set(true);
        if (listenerAttached) {
            String reason = forcedUnavailableReason;
            if (reason != null) {
                postAvailability(false, reason);
            } else if (pcmSupported) {
                postAvailability(true, null);
            } else {
                postAvailability(false, "unsupportedPcmEncoding");
            }
        }
    }

    @Override
    public void handleBuffer(ByteBuffer buffer) {
        if (!listenerAttached || !pcmSupported || forcedUnavailableReason != null) return;
        if (resetRequested.getAndSet(false)) resetWriter();
        if (writerSlot < 0 && !claimWriterSlot()) return;

        final int channels = channelCount;
        final int bytesPerSample = encoding == C.ENCODING_PCM_FLOAT ? 4 : 2;
        final int frameSize = channels * bytesPerSample;
        final int limit = buffer.limit() - frameSize + 1;
        for (int frameOffset = buffer.position(); frameOffset < limit; frameOffset += frameSize) {
            double mixed = 0.0;
            for (int channel = 0; channel < channels; channel++) {
                int sampleOffset = frameOffset + channel * bytesPerSample;
                if (encoding == C.ENCODING_PCM_FLOAT) {
                    float sample = buffer.getFloat(sampleOffset);
                    mixed += Float.isFinite(sample) ? sample : 0.0;
                } else {
                    mixed += buffer.getShort(sampleOffset) / 32768.0;
                }
            }
            mailbox[writerSlot][writerPosition++] = (float)(mixed / channels);
            if (writerPosition == FFT_SIZE) publishWriterSlot();
            if (writerSlot < 0 && !claimWriterSlot()) return;
        }
    }

    private void resetWriter() {
        if (writerSlot >= 0) {
            mailboxStates.compareAndSet(writerSlot, SLOT_WRITING, SLOT_FREE);
        }
        writerSlot = -1;
        writerPosition = 0;
    }

    private boolean claimWriterSlot() {
        for (int slot = 0; slot < SLOT_COUNT; slot++) {
            if (mailboxStates.compareAndSet(slot, SLOT_FREE, SLOT_WRITING)) {
                writerSlot = slot;
                writerPosition = 0;
                return true;
            }
        }
        return false;
    }

    private void publishWriterSlot() {
        mailboxSampleRates[writerSlot] = sampleRateHz;
        mailboxStates.set(writerSlot, SLOT_READY);
        writerSlot = -1;
        writerPosition = 0;
    }

    private void analyzeLatestSlot() {
        int generation = captureGeneration.get();
        if (!listenerAttached || forcedUnavailableReason != null) return;
        int slot = claimReadySlot();
        if (slot < 0) return;
        int analyzedSampleRate = mailboxSampleRates[slot];
        try {
            for (int i = 0; i < FFT_SIZE; i++) {
                fftReal[i] = mailbox[slot][i] * window[i];
                fftImaginary[i] = 0.0;
            }
        } finally {
            mailboxStates.set(slot, SLOT_FREE);
        }

        fftInPlace();
        List<Double> bins = calculateLogBins(analyzedSampleRate);
        Map<String, Object> event = new HashMap<>();
        event.put("available", true);
        event.put("sampleRate", analyzedSampleRate);
        event.put("timestamp", System.nanoTime() / 1000L);
        event.put("magnitudes", bins);
        mainHandler.post(() -> {
            if (listenerAttached &&
                    forcedUnavailableReason == null &&
                    captureGeneration.get() == generation) {
                listener.onSpectrumEvent(event);
            }
        });
    }

    private void clearReadySlots() {
        for (int slot = 0; slot < SLOT_COUNT; slot++) {
            mailboxStates.compareAndSet(slot, SLOT_READY, SLOT_FREE);
        }
    }

    private int claimReadySlot() {
        for (int slot = 0; slot < SLOT_COUNT; slot++) {
            if (mailboxStates.compareAndSet(slot, SLOT_READY, SLOT_READING)) {
                return slot;
            }
        }
        return -1;
    }

    private void fftInPlace() {
        for (int i = 1, j = 0; i < FFT_SIZE; i++) {
            int bit = FFT_SIZE >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) {
                double real = fftReal[i];
                fftReal[i] = fftReal[j];
                fftReal[j] = real;
                double imaginary = fftImaginary[i];
                fftImaginary[i] = fftImaginary[j];
                fftImaginary[j] = imaginary;
            }
        }
        for (int length = 2; length <= FFT_SIZE; length <<= 1) {
            double angle = -2.0 * Math.PI / length;
            double stepReal = Math.cos(angle);
            double stepImaginary = Math.sin(angle);
            for (int offset = 0; offset < FFT_SIZE; offset += length) {
                double weightReal = 1.0;
                double weightImaginary = 0.0;
                for (int i = 0; i < length / 2; i++) {
                    int even = offset + i;
                    int odd = even + length / 2;
                    double oddReal = fftReal[odd] * weightReal -
                        fftImaginary[odd] * weightImaginary;
                    double oddImaginary = fftReal[odd] * weightImaginary +
                        fftImaginary[odd] * weightReal;
                    fftReal[odd] = fftReal[even] - oddReal;
                    fftImaginary[odd] = fftImaginary[even] - oddImaginary;
                    fftReal[even] += oddReal;
                    fftImaginary[even] += oddImaginary;
                    double nextWeightReal = weightReal * stepReal -
                        weightImaginary * stepImaginary;
                    weightImaginary = weightReal * stepImaginary +
                        weightImaginary * stepReal;
                    weightReal = nextWeightReal;
                }
            }
        }
    }

    private List<Double> calculateLogBins(int analyzedSampleRate) {
        List<Double> bins = new ArrayList<>(BIN_COUNT);
        double nyquist = analyzedSampleRate / 2.0;
        double maxFrequency = Math.min(MAX_FREQUENCY_HZ, nyquist);
        double ratio = Math.pow(maxFrequency / MIN_FREQUENCY_HZ, 1.0 / BIN_COUNT);
        for (int bin = 0; bin < BIN_COUNT; bin++) {
            double lowerFrequency = MIN_FREQUENCY_HZ * Math.pow(ratio, bin);
            double upperFrequency = MIN_FREQUENCY_HZ * Math.pow(ratio, bin + 1);
            int lowerIndex = Math.max(1, (int)Math.floor(lowerFrequency * FFT_SIZE / analyzedSampleRate));
            int upperIndex = Math.min(FFT_SIZE / 2, (int)Math.ceil(upperFrequency * FFT_SIZE / analyzedSampleRate));
            double peak = 0.0;
            for (int index = lowerIndex; index <= upperIndex; index++) {
                peak = Math.max(peak, Math.hypot(fftReal[index], fftImaginary[index]));
            }
            double linearMagnitude = Math.max(1.0e-5, peak * 2.0 / FFT_SIZE);
            double decibels = 20.0 * Math.log10(linearMagnitude);
            double normalized = Math.max(0.0, Math.min(1.0,
                (decibels - MIN_DECIBELS) / -MIN_DECIBELS));
            smoothedBins[bin] = Math.max(normalized, smoothedBins[bin] * 0.82);
            bins.add(smoothedBins[bin]);
        }
        return bins;
    }

    private void postAvailability(boolean available, String reason) {
        int generation = captureGeneration.get();
        mainHandler.post(() -> {
            if (!listenerAttached || captureGeneration.get() != generation) return;
            Map<String, Object> event = new HashMap<>();
            event.put("available", available);
            if (reason != null) event.put("reason", reason);
            listener.onSpectrumEvent(event);
        });
    }
}

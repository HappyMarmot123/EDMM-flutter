import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

// Portable golden model for the RBJ peaking filters used by DarwinEqualizer.m.
// The source-contract test separately requires the native implementation to use
// the same five-band peaking-biquad design.
void main() {
  const sampleRate = 48000.0;
  const centers = [125.0, 375.0, 1000.0, 4000.0, 10000.0];
  const lowers = [20.0, 250.0, 500.0, 2000.0, 6000.0];
  const uppers = [250.0, 500.0, 2000.0, 6000.0, 20000.0];

  test('zero-gain peaking filters are transparent', () {
    for (var band = 0; band < centers.length; band++) {
      final coefficients = _peaking(
        sampleRate: sampleRate,
        centerFrequency: centers[band],
        q: _bandQ(centers[band], lowers[band], uppers[band]),
        gainDecibels: 0,
      );
      for (final frequency in [40.0, 125.0, 1000.0, 10000.0, 18000.0]) {
        expect(
          coefficients.magnitudeAt(frequency, sampleRate),
          closeTo(1, 1e-12),
        );
      }
    }
  });

  test('a boosted band changes its center more than remote frequencies', () {
    final coefficients = _peaking(
      sampleRate: sampleRate,
      centerFrequency: centers.first,
      q: _bandQ(centers.first, lowers.first, uppers.first),
      gainDecibels: 6,
    );

    expect(
      _toDecibels(coefficients.magnitudeAt(125, sampleRate)),
      closeTo(6, 0.01),
    );
    expect(
      _toDecibels(coefficients.magnitudeAt(4000, sampleRate)).abs(),
      lessThan(0.1),
    );
  });

  test('the five-band bass curve is frequency selective', () {
    const gains = [5.0, 2.0, -1.0, 0.0, 1.0];
    final filters = <_Coefficients>[
      for (var band = 0; band < centers.length; band++)
        _peaking(
          sampleRate: sampleRate,
          centerFrequency: centers[band],
          q: _bandQ(centers[band], lowers[band], uppers[band]),
          gainDecibels: gains[band],
        ),
    ];

    final bass = _cascadeDecibels(filters, 125, sampleRate);
    final mid = _cascadeDecibels(filters, 1000, sampleRate);
    final treble = _cascadeDecibels(filters, 4000, sampleRate);

    expect(bass, greaterThan(mid + 4));
    expect(bass, greaterThan(treble + 3));
  });

  test('all supported gains produce stable poles', () {
    for (final rate in [8000.0, 44100.0, 48000.0, 96000.0]) {
      for (var band = 0; band < centers.length; band++) {
        for (final gain in [-12.0, 12.0]) {
          final coefficients = _peaking(
            sampleRate: rate,
            centerFrequency: centers[band],
            q: _bandQ(centers[band], lowers[band], uppers[band]),
            gainDecibels: gain,
          );
          expect(coefficients.maximumPoleMagnitude, lessThan(1));
        }
      }
    }
  });
}

double _bandQ(double center, double lower, double upper) {
  return (center / (upper - lower)).clamp(0.25, 4).toDouble();
}

_Coefficients _peaking({
  required double sampleRate,
  required double centerFrequency,
  required double q,
  required double gainDecibels,
}) {
  if (sampleRate <= 0 ||
      centerFrequency >= sampleRate * 0.5 ||
      gainDecibels.abs() < 1e-12) {
    return const _Coefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0);
  }

  final amplitude = math.pow(10, gainDecibels / 40).toDouble();
  final omega = 2 * math.pi * centerFrequency / sampleRate;
  final alpha = math.sin(omega) / (2 * q);
  final cosine = math.cos(omega);
  final a0 = 1 + alpha / amplitude;

  return _Coefficients(
    b0: (1 + alpha * amplitude) / a0,
    b1: (-2 * cosine) / a0,
    b2: (1 - alpha * amplitude) / a0,
    a1: (-2 * cosine) / a0,
    a2: (1 - alpha / amplitude) / a0,
  );
}

double _cascadeDecibels(
  List<_Coefficients> filters,
  double frequency,
  double sampleRate,
) {
  var magnitude = 1.0;
  for (final filter in filters) {
    magnitude *= filter.magnitudeAt(frequency, sampleRate);
  }
  return _toDecibels(magnitude);
}

double _toDecibels(double magnitude) => 20 * math.log(magnitude) / math.ln10;

class _Coefficients {
  const _Coefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;

  double magnitudeAt(double frequency, double sampleRate) {
    final omega = 2 * math.pi * frequency / sampleRate;
    final cos1 = math.cos(omega);
    final sin1 = -math.sin(omega);
    final cos2 = math.cos(2 * omega);
    final sin2 = -math.sin(2 * omega);
    final numeratorReal = b0 + b1 * cos1 + b2 * cos2;
    final numeratorImaginary = b1 * sin1 + b2 * sin2;
    final denominatorReal = 1 + a1 * cos1 + a2 * cos2;
    final denominatorImaginary = a1 * sin1 + a2 * sin2;
    return math.sqrt(
      (numeratorReal * numeratorReal +
              numeratorImaginary * numeratorImaginary) /
          (denominatorReal * denominatorReal +
              denominatorImaginary * denominatorImaginary),
    );
  }

  double get maximumPoleMagnitude {
    final discriminant = a1 * a1 - 4 * a2;
    if (discriminant < 0) return math.sqrt(a2.abs());
    final root = math.sqrt(discriminant);
    final pole1 = (-a1 + root) / 2;
    final pole2 = (-a1 - root) / 2;
    return math.max(pole1.abs(), pole2.abs());
  }
}

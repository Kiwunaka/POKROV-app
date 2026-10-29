import 'dart:math' as math;
import 'dart:typed_data';

/// Fixed CPU inference for the validated pokrov-preaction-v1 Transformer.
/// This reads an explicitly supplied local asset; it never downloads a model.
class CandidateRankerModel {
  static const byteLength = 8 + 933700 * 4;

  CandidateRankerModel.fromBytes(Uint8List bytes) {
    if (bytes.length != byteLength ||
        String.fromCharCodes(bytes.take(8)) != 'PKRTF001') {
      throw const FormatException('candidate_ranker_model_contract');
    }
    final data = ByteData.sublistView(bytes, 8);
    _weights = Float32List(933700);
    for (var i = 0; i < _weights.length; i++) {
      final value = data.getFloat32(i * 4, Endian.little);
      if (!value.isFinite) throw const FormatException('candidate_ranker_model_weight');
      _weights[i] = value;
    }
  }

  late final Float32List _weights;
  static const features = 82;
  static const tokens = 9;

  List<double> score(Float32List input) {
    if (input.isEmpty || input.length % (tokens * features) != 0 ||
        input.any((value) => !value.isFinite)) {
      throw const FormatException('candidate_ranker_input');
    }
    return [for (var offset = 0; offset < input.length; offset += tokens * features)
      _candidate(Float32List.sublistView(input, offset, offset + tokens * features))];
  }

  double _candidate(Float32List input) {
    // Export order is fixed by scripts/export_candidate_ranker.py.
    var offset = 9 * 160;
    Float32List linear(Float32List values, int rows, int width, int out,
        {bool gelu = false}) {
      final result = _linear(values, rows, width, out, offset, gelu: gelu);
      offset += out * width + out;
      return result;
    }
    var x = linear(input, tokens, features, 160);
    for (var i = 0; i < x.length; i++) {
      x[i] += _weights[i];
    }
    for (var layer = 0; layer < 4; layer++) {
      final qkv = linear(x, tokens, 160, 480);
      final attention = Float32List(tokens * 160);
      final logits = Float64List(tokens);
      for (var head = 0; head < 4; head++) {
        for (var query = 0; query < tokens; query++) {
          var maximum = double.negativeInfinity;
          for (var key = 0; key < tokens; key++) {
            var dot = 0.0;
            for (var column = 0; column < 40; column++) {
              dot += qkv[query * 480 + head * 40 + column] *
                  qkv[key * 480 + 160 + head * 40 + column];
            }
            logits[key] = dot / math.sqrt(40);
            maximum = math.max(maximum, logits[key]);
          }
          var total = 0.0;
          for (var key = 0; key < tokens; key++) {
            logits[key] = math.exp(logits[key] - maximum);
            total += logits[key];
          }
          for (var column = 0; column < 40; column++) {
            var value = 0.0;
            for (var key = 0; key < tokens; key++) {
              value += logits[key] / total * qkv[key * 480 + 320 + head * 40 + column];
            }
            attention[query * 160 + head * 40 + column] = value;
          }
        }
      }
      final projected = linear(attention, tokens, 160, 160);
      // PyTorch exports both feed-forward layers before the norm parameters.
      final ffOffset = offset;
      offset += 384 * 160 + 384 + 160 * 384 + 160;
      final norm1 = offset;
      final norm2 = norm1 + 320;
      offset = norm2 + 320;
      x = _normalize(x, projected, norm1);
      final hidden = _linear(x, tokens, 160, 384, ffOffset, gelu: true);
      final output = _linear(hidden, tokens, 384, 160, ffOffset + 384 * 160 + 384);
      x = _normalize(x, output, norm2);
    }
    final projected = linear(Float32List.sublistView(x, 8 * 160), 1, 160, 64, gelu: true);
    final result = linear(projected, 1, 64, 4).first;
    if (!result.isFinite) throw const FormatException('candidate_ranker_nonfinite_score');
    return result;
  }

  Float32List _linear(Float32List input, int rows, int width, int out, int offset,
      {bool gelu = false}) {
    final result = Float32List(rows * out);
    for (var row = 0; row < rows; row++) {
      for (var unit = 0; unit < out; unit++) {
        var value = _weights[offset + width * out + unit];
        for (var column = 0; column < width; column++) {
          value += input[row * width + column] * _weights[offset + unit * width + column];
        }
        result[row * out + unit] = gelu ? _gelu(value) : value;
      }
    }
    return result;
  }

  Float32List _normalize(Float32List residual, Float32List update, int offset) {
    final result = Float32List(residual.length);
    for (var row = 0; row < tokens; row++) {
      var mean = 0.0;
      for (var column = 0; column < 160; column++) {
        final i = row * 160 + column;
        result[i] = residual[i] + update[i];
        mean += result[i] / 160;
      }
      var variance = 0.0;
      for (var column = 0; column < 160; column++) {
        final difference = result[row * 160 + column] - mean;
        variance += difference * difference / 160;
      }
      final scale = 1 / math.sqrt(variance + 1e-5);
      for (var column = 0; column < 160; column++) {
        final i = row * 160 + column;
        result[i] = (result[i] - mean) * scale * _weights[offset + column] +
            _weights[offset + 160 + column];
      }
    }
    return result;
  }

  static double _gelu(double value) {
    // erf approximation, maximum absolute error < 1.5e-7.
    final x = value.abs() / math.sqrt2;
    final t = 1 / (1 + 0.3275911 * x);
    final erf = 1 - (((((1.061405429 * t - 1.453152027) * t) +
        1.421413741) * t - 0.284496736) * t + 0.254829592) * t * math.exp(-x * x);
    return 0.5 * value * (1 + (value < 0 ? -erf : erf));
  }
}

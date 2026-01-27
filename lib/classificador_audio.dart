import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificadorAudio {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  final List<String> labels = [
    'BAIXO',
    'Background Noise',
    'CIMA',
    'DESLIGADO',
    'DIREITO',
    'ESQUERDO',
    'LIGADO',
  ];

  Future<void> loadModel() async {
    if (_isModelLoaded) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/soundclassifier_with_metadata.tflite',
      );

      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      print('MODELO');
      print('Input shape : ${inputTensor.shape}');
      print('Input type  : ${inputTensor.type}');
      print('Output shape: ${outputTensor.shape}');
      print('-----------------------------');

      _isModelLoaded = true;
    } catch (e) {
      print('Erro ao carregar modelo: $e');
    }
  }

  Future<Map<String, dynamic>> classificarAudio(String audioPath) async {
    await loadModel();

    if (_interpreter == null) {
      return {'classe': 'Erro', 'confiança': 0.0};
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      print('Arquivo de áudio não encontrado');
      return {'classe': 'Erro', 'confiança': 0.0};
    }

    final pcmBytes = await file.readAsBytes();
    final numSamples = pcmBytes.length ~/ 2;

    print('\nÁUDIO');
    print('Samples : $numSamples');
    print('Duração : ${(numSamples / 16000).toStringAsFixed(2)} s');


    final byteData = ByteData.sublistView(pcmBytes);
    final Float32List floatBuffer = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      floatBuffer[i] = sample / 32768.0;
    }

    final int tamanhoEsperado =
        _interpreter!.getInputTensor(0).shape.last;

    print('Modelo espera: $tamanhoEsperado samples');

    Float32List inputBuffer;

    if (numSamples >= tamanhoEsperado) {
      inputBuffer = floatBuffer.sublist(0, tamanhoEsperado);
    } else {
      inputBuffer = Float32List(tamanhoEsperado);
      inputBuffer.setRange(0, numSamples, floatBuffer);
    }

    final input = inputBuffer.reshape([1, tamanhoEsperado]);
    final output =
        List.generate(1, (_) => List.filled(labels.length, 0.0));

  
    _interpreter!.run(input, output);
    final scores = output[0];

    print('\nSAÍDA DO MODELO');
    for (int i = 0; i < labels.length; i++) {
      print('${labels[i].padRight(15)} : ${scores[i]}');
    }
    if (scores.any((v) => v.isNaN)) {
      print('\nSAÍDA CONTÉM NaN');
      return {
        'classe': 'Background Noise',
        'confiança': 0.0,
      };
    }
    int maxIndex = 0;
    double maxValue = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxValue) {
        maxValue = scores[i];
        maxIndex = i;
      }
    }

    print('\nRESULTADO');
    print('Classe : ${labels[maxIndex]}');
    print('Score  : ${(maxValue * 100).toStringAsFixed(1)}%');

    return {
      'classe': labels[maxIndex],
      'confiança': maxValue,
    };
  }
}

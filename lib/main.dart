import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'classificador_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Fundo quase branco
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          background: const Color(0xFFF8F9FA),
        ),
      ),
      home: const AudioClassifierPage(),
    );
  }
}

class AudioClassifierPage extends StatefulWidget {
  const AudioClassifierPage({super.key});

  @override
  State<AudioClassifierPage> createState() => _AudioClassifierPageState();
}

class _AudioClassifierPageState extends State<AudioClassifierPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ClassificadorAudio _classificador = ClassificadorAudio();

  bool _gravando = false;
  String _status = 'Toque para iniciar';
  String _resultadoClasse = '';
  double _confianca = 0.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    await _classificador.loadModel();
  }

  Future<void> _toggle() async {
    if (_gravando) {
      final String? path = await _recorder.stopRecorder();
      setState(() {
        _gravando = false;
        _status = 'Analisando...';
      });

      if (path != null) {
        final Map<String, dynamic> resultado = await _classificador.classificarAudio(path);
        setState(() {
          _resultadoClasse = resultado['classe'].toString();
          _confianca = resultado['confiança'];
          _status = 'Concluído';
        });
      }
    } else {
      await _recorder.startRecorder(
        toFile: 'audio_temp.pcm',
        codec: Codec.pcm16,
        sampleRate: 44032,
        numChannels: 1,
      );
      setState(() {
        _gravando = true;
        _resultadoClasse = '';
        _status = 'Escutando...';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (_gravando) _toggle();
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Cabeçalho Minimalista
              const Text(
                'Classificador',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF2D3436)),
              ),
              const Text(
                'Comando de Voz',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              
              const Spacer(),

              // Área do Visualizador / Círculo Central
              _buildMicrophoneArea(),

              const SizedBox(height: 20),
              Text(
                _status.toUpperCase(),
                style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),

              const Spacer(),

              // Card de Resultado (Apenas se houver dado)
              _buildResultPanel(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicrophoneArea() {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ondas de animação simples quando gravando
          if (_gravando)
            ...[1, 2].map((e) => TweenAnimationBuilder(
                  tween: Tween(begin: 1.0, end: 2.0),
                  duration: const Duration(seconds: 1),
                  builder: (context, double value, child) {
                    return Container(
                      width: 120 * value,
                      height: 120 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withOpacity(0.2 * (2 - value)),
                      ),
                    );
                  },
                )),
          // Botão Principal
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _gravando ? Icons.stop_rounded : Icons.mic_none_rounded,
              size: 40,
              color: _gravando ? Colors.redAccent : Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _resultadoClasse.isEmpty ? 0 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            const Text("COMANDO DETECTADO", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _resultadoClasse.isEmpty ? "-" : _resultadoClasse,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _confianca,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F2F6),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 10),
            Text("${(_confianca * 100).toStringAsFixed(0)}% de precisão", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
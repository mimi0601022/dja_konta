import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Ecrã reutilizável: lê um código de barras/QR e devolve o texto lido
// Usado para os itens e para o QR do convite.
class ScannerPage extends StatefulWidget {
  final String titulo;
  final String instrucao;

  const ScannerPage({
    super.key,
    this.titulo = 'Ler código',
    this.instrucao = 'Aponte para o código de barras ou QR do produto',
  });

  @override
  ScannerPageState createState() => ScannerPageState();
}

class ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController();

  bool _lido = false; // evita devolver o mesmo código várias vezes
  bool _falhou = false; // estado de erro ("Código pouco nítido")
  bool _lanterna = false; // lanterna ligada/desligada
  Timer? _timer; // conta o tempo sem ler nada

  static const _laranja = Color(0xFFB8501A);

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose(); // liberta a câmara
    super.dispose();
  }

  // Ao fim de 10 s sem ler nenhum código, mostra o estado de erro
  // (mas não se a câmara falhou: aí o problema é outro)
  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_lido && _controller.value.error == null) {
        setState(() => _falhou = true);
      }
    });
  }

  void _aoDetetar(BarcodeCapture captura) {
    if (_lido) return;
    final valor = captura.barcodes.isNotEmpty ? captura.barcodes.first.rawValue : null;
    if (valor == null || valor.isEmpty) return;

    _lido = true;
    _timer?.cancel();
    Navigator.of(context).pop(valor.trim()); // devolve o código lido
  }

  Future<void> _alternarLanterna() async {
    await _controller.toggleTorch();
    if (mounted) setState(() => _lanterna = !_lanterna);
  }

  // Diálogo para escrever o código à mão
  Future<void> _introduzirManual() async {
    _timer?.cancel();
    final texto = TextEditingController();

    final codigo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Introduzir código'),
        content: TextField(
          controller: texto,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(texto.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    texto.dispose();

    if (!mounted) return;
    if (codigo != null && codigo.trim().isNotEmpty) {
      _lido = true;
      Navigator.of(context).pop(codigo.trim()); // devolve o código escrito
    } else {
      _iniciarTimer(); // cancelou: volta a contar
    }
  }

  // Ecrã mostrado quando a câmara não abre (sem permissão ou avariada)
  Widget _semCamara(MobileScannerException error) {
    final cores = Theme.of(context).colorScheme;

    String titulo;
    String texto;
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      titulo = 'Sem acesso à câmara';
      texto = 'Ative a permissão da câmara nas definições do telemóvel.';
    } else {
      titulo = 'Câmara indisponível';
      texto = 'Não foi possível abrir a câmara.';
    }

    return Container(
      color: cores.surface, // tapa o fundo preto da câmara
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 64, color: cores.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(color: cores.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corMoldura = _falhou ? _laranja : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          // Lanterna (desativada se a câmara falhou)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, estado, child) {
              return IconButton(
                tooltip: _lanterna ? 'Desligar lanterna' : 'Ligar lanterna',
                icon: Icon(_lanterna ? Icons.flashlight_on : Icons.flashlight_off_outlined),
                onPressed: estado.error != null ? null : _alternarLanterna,
              );
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          // Imagem da câmara (ocupa o ecrã todo)
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _aoDetetar,
              // Se a câmara não abrir, mostra o nosso ecrã de erro
              errorBuilder: (context, error) => _semCamara(error),
            ),
          ),

          // Moldura, linha, texto e etiqueta de erro
          // (escondidos se a câmara falhou)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, estado, child) {
              if (estado.error != null) return const SizedBox.shrink();

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CustomPaint(
                        painter: _CantosPainter(cor: corMoldura),
                        child: _falhou
                            ? null
                            // Linha laranja no meio (só no estado normal)
                            : Center(
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  color: _laranja,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_falhou)
                      // Etiqueta "Código pouco nítido"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.grid_4x4, size: 16, color: Colors.white70),
                            SizedBox(width: 6),
                            Text('Código pouco nítido',
                                style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      )
                    else ...[
                      // Instrução e estado da lanterna
                      SizedBox(
                        width: 240,
                        child: Text(
                          widget.instrucao,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lanterna: ${_lanterna ? 'ligada' : 'desligada'}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Parte de baixo: botão manual (normal) ou faixa de erro
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: _falhou
                  // Faixa de erro com a ação "Manual"
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2B2B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Não foi possível ler o código. Aproxime e tente de novo.',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _introduzirManual,
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFF0A27A)),
                            child: const Text('Manual'),
                          ),
                        ],
                      ),
                    )
                  // Botão "Introduzir código manualmente"
                  : SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEDEDE8),
                          foregroundColor: Colors.black87,
                        ),
                        icon: const Icon(Icons.keyboard_outlined),
                        label: const Text('Introduzir código manualmente'),
                        onPressed: _introduzirManual,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Desenha os 4 cantos da moldura de leitura
class _CantosPainter extends CustomPainter {
  final Color cor;
  _CantosPainter({required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const l = 36.0; // comprimento de cada "perna" do canto
    const r = 12.0; // raio da curva do canto
    final w = size.width, h = size.height;

    // Canto superior esquerdo
    canvas.drawPath(
        Path()
          ..moveTo(0, l)
          ..lineTo(0, r)
          ..quadraticBezierTo(0, 0, r, 0)
          ..lineTo(l, 0),
        paint);
    // Canto superior direito
    canvas.drawPath(
        Path()
          ..moveTo(w - l, 0)
          ..lineTo(w - r, 0)
          ..quadraticBezierTo(w, 0, w, r)
          ..lineTo(w, l),
        paint);
    // Canto inferior esquerdo
    canvas.drawPath(
        Path()
          ..moveTo(0, h - l)
          ..lineTo(0, h - r)
          ..quadraticBezierTo(0, h, r, h)
          ..lineTo(l, h),
        paint);
    // Canto inferior direito
    canvas.drawPath(
        Path()
          ..moveTo(w - l, h)
          ..lineTo(w - r, h)
          ..quadraticBezierTo(w, h, w, h - r)
          ..lineTo(w, h - l),
        paint);
  }

  @override
  bool shouldRepaint(_CantosPainter old) => old.cor != cor;
}
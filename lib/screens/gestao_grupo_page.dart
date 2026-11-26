import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/membro.dart';
import 'package:dja_konta/models/convite.dart';
import 'package:dja_konta/services/membro_service.dart';
import 'package:dja_konta/widgets/membro_sheet.dart';
import 'package:dja_konta/services/conexao_service.dart';


// Gestão do grupo: convite (só staff), membros e sair
// Devolve 'saiu' no pop se o utilizador saiu do grupo
class GestaoGrupoPage extends StatefulWidget {
  final Grupo grupo;
  const GestaoGrupoPage({super.key, required this.grupo});

  @override
  GestaoGrupoPageState createState() => GestaoGrupoPageState();
}

class GestaoGrupoPageState extends State<GestaoGrupoPage> {
  late final Stream<List<Membro>> _streamMembros;
  Future<Convite?>? _futureConvite; // só existe para o staff

  List<Membro> _membros = []; // última lista recebida (para o "Sair")
  final _meuUid = FirebaseAuth.instance.currentUser!.uid;
  bool _aSair = false;

  @override
  void initState() {
    super.initState();
    _streamMembros = MembroService.ouvirMembros(widget.grupo.id);
    // O viewer não vê (nem pode ler) o convite
    if (widget.grupo.isStaff) {
      _futureConvite = MembroService.obterConvite(widget.grupo.id);
    }

    // Quando a rede voltar, volta a ler o convite
    ConexaoService.online.addListener(_aoMudarLigacao);
  }

  @override
  void dispose() {
    ConexaoService.online.removeListener(_aoMudarLigacao);
    super.dispose();
  }

  // A rede voltou: volta a ler o convite os membros voltam sozinhos pelo stream
  void _aoMudarLigacao() {
    if (ConexaoService.online.value && widget.grupo.isStaff) {
      setState(() {
        _futureConvite = MembroService.obterConvite(widget.grupo.id);
      });
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  //Convite 
  Future<void> _copiar(Convite convite) async {
    await Clipboard.setData(ClipboardData(text: convite.formatado));
    if (!mounted) return;
    _aviso('Código copiado.');
  }

  Future<void> _partilhar(Convite convite) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Entre no grupo «${widget.grupo.nome}» na app Dja Konta? '
            'com o código ${convite.formatado}',
      ),
    );
  }

  void _mostrarQr(Convite convite) {
    showDialog(
      context: context,
      builder: (contextDialogo) => AlertDialog(
        title: Text(
          convite.formatado,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 4),
        ),
        content: SizedBox(
          width: 240,
          height: 240,
          // Sem hífen: é o que o "Ler QR do convite" espera
          child: QrImageView(data: convite.codigo, backgroundColor: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _gerar(Convite? atual) async {
    // Se o atual ainda vale, confirmar (vai deixar de funcionar)
    if (atual != null && !atual.expirado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (contextDialogo) => AlertDialog(
          title: const Text('Gerar novo código?'),
          content: const Text('O código atual deixa de funcionar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialogo, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(contextDialogo, true),
              child: const Text('Gerar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    final erro = await MembroService.gerarConvite(
      grupoId: widget.grupo.id,
      codigoAntigo: atual?.codigo,
    );
    if (!mounted) return;

    if (erro != null) {
      _aviso(erro);
      return;
    }

    // Volta a ler o convite 
    setState(() {
      _futureConvite = MembroService.obterConvite(widget.grupo.id);
    });
    _aviso('Novo código gerado.');
  }

  //  Membros 

  Future<void> _alterarPapel(Membro membro, String papel) async {
    if (papel == membro.papel) return;
    final erro = await MembroService.alterarPapel(
      grupoId: widget.grupo.id,
      uid: membro.uid,
      papel: papel,
    );
    if (!mounted) return;
    if (erro != null) _aviso(erro);
  }
  

  Future<void> _sair() async {
    final cores = Theme.of(context).colorScheme;
    final nome = widget.grupo.nome;

    // O meu papel atual da lista em tempo real, não do que veio de trás
    final eu = _membros.where((m) => m.uid == _meuUid);
    final euStaff = eu.isNotEmpty && eu.first.isStaff;
    final totalStaff = _membros.where((m) => m.isStaff).length;

    // Último staff com outros membros: não pode sair
    if (euStaff && totalStaff == 1 && _membros.length > 1) {
      await showDialog<void>(
        context: context,
        builder: (contextDialogo) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: cores.primary),
          title: const Text('Não pode sair do grupo'),
          content: Text(
            'É o único staff de «$nome». Atribua o papel de staff a outro '
            'membro antes de sair.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contextDialogo),
              child: const Text('Fechar'),
            ),
            FilledButton(
              // Já está no ecrã dos membros: basta fechar
              onPressed: () => Navigator.pop(contextDialogo),
              child: const Text('Gerir membros'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextDialogo) => AlertDialog(
        title: const Text('Sair do grupo?'),
        content: Text(
          'Deixa de ver os itens de «$nome». Para voltar, precisa de um novo convite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() {
      _aSair = true;
    });

    final erro = await MembroService.sairDoGrupo(grupoId: widget.grupo.id);
    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _aSair = false;
      });
      _aviso(erro);
      return;
    }

    Navigator.pop(context, 'saiu');
  }

    // Abre a folha do membro; se pedir para remover, confirma e remove
  Future<void> _abrirMembro(Membro membro) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => MembroSheet(grupo: widget.grupo, membro: membro),
    );
    if (!mounted || acao != 'remover') return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextDialogo) => AlertDialog(
        title: Text('Remover «${membro.nome}»?'),
        content: const Text(
          'Deixa de ter acesso ao grupo. Pode voltar com um novo convite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final erro = await MembroService.removerMembro(
      grupoId: widget.grupo.id,
      uid: membro.uid,
    );
    if (!mounted) return;
    _aviso(erro ?? 'Membro removido.');
  }

  // Ecrã 

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final staff = widget.grupo.isStaff;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(staff ? 'Gestão do grupo' : 'Membros'),
            const SizedBox(height: 2),
            Text(
              widget.grupo.nome,
              style: TextStyle(fontSize: 12, color: cores.onSurfaceVariant),
            ),
          ],
        ),
      ),


      body: ValueListenableBuilder<bool>(
        valueListenable: ConexaoService.online,
        builder: (context, online, _) {
          if (!online) return _semLigacao(cores);

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Membro>>(
                  stream: _streamMembros,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Não foi possível carregar os membros.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    _membros = snapshot.data!;

                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Convite (só staff)
                        if (staff) ...[
                          _titulo('CÓDIGO DE CONVITE', cores),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _cartaoConvite(cores),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Membros
                        _titulo('MEMBROS · ${_membros.length}', cores),
                        for (var i = 0; i < _membros.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 72),
                          _linhaMembro(_membros[i], cores),
                        ],
                      ],
                    );
                  },
                ),
              ),

              // Sair do grupo (todos)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: cores.error,
                      side: BorderSide(color: cores.error),
                    ),
                    onPressed: _aSair ? null : _sair,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair do grupo'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Título pequeno de secção ("CÓDIGO DE CONVITE", "MEMBROS · 4")
  Widget _titulo(String texto, ColorScheme cores) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        texto,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          letterSpacing: 1.5,
          color: cores.onSurfaceVariant,
        ),
      ),
    );
  }

  // Cartão do convite: a carregar / sem convite / expirado / válido
  Widget _cartaoConvite(ColorScheme cores) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<Convite?>(
        future: _futureConvite,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final convite = snapshot.data;

          // Grupo ainda sem convite
          if (convite == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Este grupo ainda não tem código de convite.',
                  style: TextStyle(color: cores.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _gerar(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Gerar código'),
                ),
              ],
            );
          }

          // Dias que faltam (arredonda para cima: acabado de criar = 7)
          final horas = convite.expiraEm.difference(DateTime.now()).inHours;
          final dias = (horas / 24).ceil();
          final validade = convite.expirado
              ? 'expirado'
              : 'expira em $dias ${dias == 1 ? 'dia' : 'dias'}';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Código grande (tocar abre o QR)
                  Expanded(
                    child: InkWell(
                      onTap: convite.expirado ? null : () => _mostrarQr(convite),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        convite.formatado,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: convite.expirado
                              ? cores.onSurfaceVariant
                              : cores.onSurface,
                          decoration:
                              convite.expirado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    validade,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: convite.expirado ? cores.error : cores.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              if (!convite.expirado) ...[
                const SizedBox(height: 4),
                Text(
                  'Toque no código para ver o QR',
                  style: TextStyle(fontSize: 11, color: cores.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copiar(convite),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _partilhar(convite),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Partilhar'),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _gerar(convite),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Gerar novo código'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Mostrado quando não há rede 
  Widget _semLigacao(ColorScheme cores) {
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: cores.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'Sem ligação',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'A gestão do grupo precisa de ligação à internet. '
              'Os itens continuam disponíveis sem rede.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // Uma linha de membro
  Widget _linhaMembro(Membro membro, ColorScheme cores) {
    final souEu = membro.uid == _meuUid;
    // Só o staff gere os outros (ninguém muda o próprio papel)
    final podeGerir = widget.grupo.isStaff && !souEu;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cores.surfaceContainerHighest,
        foregroundColor: cores.onSurfaceVariant,
        child: Text(
          membro.iniciais,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(souEu ? '${membro.nome} (eu)' : membro.nome),
      subtitle: Text(
        membro.email,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      onTap: podeGerir ? () => _abrirMembro(membro) : null,
      trailing: podeGerir
          ? PopupMenuButton<String>(
              tooltip: 'Alterar papel',
              initialValue: membro.papel,
              onSelected: (papel) => _alterarPapel(membro, papel),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'staff', child: Text('Staff')),
                PopupMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
              child: _etiquetaPapel(membro.papel, cores, comSeta: true),
            )
          : _etiquetaPapel(membro.papel, cores),
    );
  }

  // Etiqueta "staff" / "viewer" (com seta quando dá para mudar)
  Widget _etiquetaPapel(String papel, ColorScheme cores, {bool comSeta = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: cores.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(papel, style: TextStyle(fontSize: 12, color: cores.onSurface)),
          if (comSeta)
            Icon(Icons.arrow_drop_down, size: 18, color: cores.onSurfaceVariant),
        ],
      ),
    );
  }
}
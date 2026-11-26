import 'package:dja_konta/services/conexao_service.dart';
import 'package:dja_konta/widgets/faixa_sincronizacao.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dja_konta/services/group_service.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/screens/profile_page.dart';
import 'package:dja_konta/screens/criar_grupo_page.dart';
import 'package:dja_konta/screens/entrar_grupo_page.dart';
import 'package:dja_konta/screens/itens_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  GroupsPageState createState() => GroupsPageState();
}

class GroupsPageState extends State<GroupsPage> {
  late Future<List<Grupo>> _futureGrupos;

  // Para escrever a data em português sem pacotes extra
  static const _dias = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _futureGrupos = GroupService.lerGrupos(); // lê uma vez ao abrir o ecrã
    ConexaoService.online.addListener(_aoMudarLigacao);
  }

  @override
  void dispose() {
    ConexaoService.online.removeListener(_aoMudarLigacao);
    super.dispose();
  }
 

  //rede volta le grupo again
  void _aoMudarLigacao(){
    if(ConexaoService.online.value) _recarregar();
  }

  // Volta a ler os grupos (depois de criar/entrar/sair, ou ao puxar para baixo)
  Future<void> _recarregar() async {
    final novo = GroupService.lerGrupos();
    setState(() {
      _futureGrupos = novo;
    });
    await novo; // o RefreshIndicator espera até terminar
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _novoGrupo() async {
    final criado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true, // abre de baixo para cima, com o X
        builder: (_) => const CriarGrupoPage(),
      ),
    );
    if (!mounted) return;
    if (criado == true) {
      _recarregar();
      _aviso('Grupo criado.');
    }
  }

  Future<void> _entrarComCodigo() async {
    final entrou = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const EntrarGrupoPage()));
    if (!mounted) return;
    if (entrou == true) {
      _recarregar();
      _aviso('Entrou no grupo.');
    }
  }

  // Abre os itens ao voltar, recarrega sempre (os números podem ter mudado)
  Future<void> _abrirGrupo(Grupo grupo) async {
    final resultado = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => ItensPage(grupo: grupo)));
    if (!mounted) return;
    await _recarregar();
    if (!mounted) return;
    if (resultado == 'saiu') _aviso('Saiu do grupo.');
  }

  // Os dois botões, empilhados e com a largura toda
  Widget _botoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Criar grupo'),
            onPressed: _novoGrupo,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.key_outlined),
            label: const Text('Entrar com código'),
            onPressed: _entrarComCodigo,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dja Konta?'),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),

      // Conteúdo: a carregar / vazio / lista
      body: Column(
        children: [
          const FaixaSincronizacao(),
          Expanded(
            child: FutureBuilder<List<Grupo>>(
              future: _futureGrupos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final grupos = snapshot.data ?? [];

                // Sem grupos: estado vazio com os botões no meio
                if (grupos.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _recarregar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                      children: [
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: cores.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: cores.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Ainda não pertence\na nenhum grupo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cada grupo é um inventário partilhado. Crie um novo ou entre num existente com um código de convite.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: cores.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _botoes(),
                      ],
                    ),
                  );
                }

                // Com grupos: cabeçalho + cartões + botões fixos em baixo
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _recarregar,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _cabecalho(grupos, cores),
                            for (final grupo in grupos)
                              _cartaoGrupo(grupo, cores),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
                        child: _botoes(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // "quarta-feira, 21 de outubro" / "Olá, Miriam" / "3 grupos · 5 com stock baixo"
  Widget _cabecalho(List<Grupo> grupos, ColorScheme cores) {
    final nomeCompleto = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final primeiroNome = nomeCompleto.trim().split(RegExp(r'\s+')).first;

    final hoje = DateTime.now();
    final data =
        '${_dias[hoje.weekday - 1]}, ${hoje.day} de ${_meses[hoje.month - 1]}';

    // Soma o stock baixo de todos os grupos
    final totalBaixos = grupos.fold<int>(0, (soma, g) => soma + g.nBaixos);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data,
            style: TextStyle(fontSize: 13, color: cores.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            primeiroNome.isEmpty ? 'Olá!' : 'Olá, $primeiroNome',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, color: cores.onSurfaceVariant),
              children: [
                TextSpan(
                  text:
                      '${grupos.length} ${grupos.length == 1 ? 'grupo' : 'grupos'}',
                ),
                if (totalBaixos > 0)
                  TextSpan(
                    text: ' · $totalBaixos com stock baixo',
                    style: TextStyle(
                      color: cores.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'OS MEUS GRUPOS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1.5,
              color: cores.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Cartão de um grupo
  Widget _cartaoGrupo(Grupo grupo, ColorScheme cores) {
    final stock = grupo.tipo == 'stock';
    final tipoTexto = stock ? 'Loja' : 'Sala';
    final linha2 = grupo.localizacao != null
        ? '$tipoTexto · ${grupo.localizacao}'
        : tipoTexto;
    final palavraItens = stock
        ? (grupo.nItens == 1 ? 'produto' : 'produtos')
        : (grupo.nItens == 1 ? 'item' : 'itens');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cores.outlineVariant),
      ),
      // Material transparente: o InkWell precisa dele para desenhar o efeito do toque
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _abrirGrupo(grupo),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone, nome, tipo/localização e papel
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cores.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        stock
                            ? Icons.storefront_outlined
                            : Icons.meeting_room_outlined,
                        color: cores.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grupo.nome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            linha2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, // corta com "..."
                            style: TextStyle(
                              fontSize: 13,
                              color: cores.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _etiquetaPapel(grupo.papel, cores),
                  ],
                ),

                const SizedBox(height: 12),

                // Quantos itens e quantos membros
                Row(
                  children: [
                    _indicador(
                      Icons.inventory_2_outlined,
                      '${grupo.nItens} $palavraItens',
                      cores,
                    ),
                    const SizedBox(width: 16),
                    _indicador(
                      Icons.group_outlined,
                      '${grupo.nMembros} ${grupo.nMembros == 1 ? 'membro' : 'membros'}',
                      cores,
                    ),
                  ],
                ),

                // Alerta de stock baixo (só se houver)
                if (grupo.nBaixos > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: cores.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: cores.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${grupo.nBaixos} com stock baixo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cores.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Ícone pequeno + texto ("12 produtos", "3 membros")
  Widget _indicador(IconData icone, String texto, ColorScheme cores) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: cores.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(fontSize: 13, color: cores.onSurfaceVariant),
        ),
      ],
    );
  }

  // Etiqueta "staff" / "viewer"
  Widget _etiquetaPapel(String papel, ColorScheme cores) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: cores.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        papel,
        style: TextStyle(fontSize: 12, color: cores.onSurface),
      ),
    );
  }
}

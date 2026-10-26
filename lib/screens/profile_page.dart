import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/services/auth_service.dart';
import 'package:dja_konta/screens/gestao_grupo_page.dart';

// Perfil do utilizador.
// Se vier um grupo (aberto a partir dos itens), mostra o "Grupo ativo",
// "Os meus grupos" e "Gestão do grupo" (só staff).
// Devolve 'saiu' no pop se o utilizador saiu do grupo pela gestão.
class ProfilePage extends StatefulWidget {
  final Grupo? grupo;
  const ProfilePage({super.key, this.grupo});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  bool _aSair = false; // a terminar sessão

  // "Ana Silva" → "AS" (primeira e última palavra)
  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  Future<void> _terminarSessao() async {
    setState(() {
      _aSair = true;
    });
    await AuthService.signOut();
    if (!mounted) return;
    // O perfil está por cima de outros ecrãs: fecha tudo até ao ecrã base
    // (que o main.dart já trocou para o login)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Volta à lista de grupos (o primeiro ecrã)
  void _osMeusGrupos() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Abre a gestão; se saiu do grupo, avisa o ecrã de trás (os itens)
  Future<void> _gestao(Grupo grupo) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => GestaoGrupoPage(grupo: grupo)),
    );
    if (!mounted) return;
    if (resultado == 'saiu') Navigator.pop(context, 'saiu');
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final nome = user?.displayName ?? '';
    final email = user?.email ?? '';
    final grupo = widget.grupo;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  // Avatar, nome e email
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: cores.surfaceContainerHighest,
                      foregroundColor: cores.onSurfaceVariant,
                      child: Text(
                        _iniciais(nome),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: cores.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Só quando o perfil foi aberto dentro de um grupo
                  if (grupo != null) ...[
                    // Cartão "Grupo ativo"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cores.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              grupo.tipo == 'stock'
                                  ? Icons.storefront_outlined
                                  : Icons.meeting_room_outlined,
                              color: cores.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Grupo ativo',
                                    style: TextStyle(
                                        fontSize: 11, color: cores.onSurfaceVariant),
                                  ),
                                  Text(
                                    '${grupo.nome} · ${grupo.papel}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    
                    // Só o staff gere o grupo
                    if (grupo.isStaff)
                      ListTile(
                        leading: const Icon(Icons.manage_accounts_outlined),
                        title: const Text('Gestão do grupo'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _gestao(grupo),
                      ),
                  ],

                  ListTile(
                      leading: const Icon(Icons.group_outlined),
                      title: const Text('Os meus grupos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _osMeusGrupos,
                      
                  ),

                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // Terminar sessão
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Terminar sessão'),
                    enabled: !_aSair,
                    trailing: _aSair
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _terminarSessao,
                  ),
                ],
              ),
            ),

            // Versão no fundo
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Dja Konta? · v1.0',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: cores.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
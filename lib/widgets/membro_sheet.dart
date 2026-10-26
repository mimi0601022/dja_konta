import 'package:flutter/material.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/membro.dart';
import 'package:dja_konta/services/membro_service.dart';

// Folha de um membro: informação, papel e remover
// Devolve 'remover' no pop (quem abriu trata da confirmação)
class MembroSheet extends StatefulWidget {
  final Grupo grupo;
  final Membro membro;

  const MembroSheet({
    super.key,
    required this.grupo,
    required this.membro,
  });

  @override
  MembroSheetState createState() => MembroSheetState();
}

class MembroSheetState extends State<MembroSheet> {
  late String _papel; // papel escolhido (muda logo ao tocar)
  String? _erro;

  @override
  void initState() {
    super.initState();
    _papel = widget.membro.papel;
  }

  // Muda já no ecrã; se o Firebase recusar, volta atrás
  Future<void> _mudarPapel(String? novo) async {
    if (novo == null || novo == _papel) return;

    final anterior = _papel;
    setState(() {
      _papel = novo;
      _erro = null;
    });

    final erro = await MembroService.alterarPapel(
      grupoId: widget.grupo.id,
      uid: widget.membro.uid,
      papel: novo,
    );
    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _papel = anterior;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final membro = widget.membro;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo: avatar, nome e email
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cores.surfaceContainerHighest,
                    foregroundColor: cores.onSurfaceVariant,
                    child: Text(
                      membro.iniciais,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membro.nome,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          membro.email,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: cores.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Papel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'PAPEL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: cores.onSurfaceVariant,
                ),
              ),
            ),
            
            RadioGroup<String>(
              groupValue: _papel,
              onChanged: _mudarPapel,
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'staff',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    title: Text('Staff'),
                    subtitle: Text('Edita produtos, stock e membros'),
                  ),
                  RadioListTile<String>(
                    value: 'viewer',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    title: Text('Viewer'),
                    subtitle: Text('Só consulta'),
                  ),
                ],
              ),
            ),

            // Erro ao mudar o papel
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Text(_erro!, style: TextStyle(color: cores.error)),
              ),

            const Divider(height: 24),

            // Remover (a confirmação é feita no ecrã de trás)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.person_remove_outlined, color: cores.error),
              title: Text('Remover do grupo', style: TextStyle(color: cores.error)),
              onTap: () => Navigator.pop(context, 'remover'),
            ),
          ],
        ),
      ),
    );
  }
}